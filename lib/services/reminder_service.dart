import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/todo_item.dart';

/// One notification to have scheduled on this phone.
@immutable
class Reminder {
  final int id;
  final DateTime at;
  final String title;

  const Reminder({required this.id, required this.at, required this.title});
}

/// The reminders [todos] call for after [now], soonest first. [todos] is
/// the list as the app shows it, so a repeat is already one todo per day
/// and a day already checked off has no reminder left.
// ponytail: only the next [days] are scheduled, refreshed whenever the todo
// list changes; a phone that never opens the app for longer than that
// stops getting them. Android also caps an app's alarms near 500.
List<Reminder> upcomingReminders(
  List<TodoItem> todos,
  DateTime now, {
  int days = 14,
  int max = 100,
}) {
  final until = now.add(Duration(days: days));
  final out =
      [
          for (final t in todos)
            if (t.remindMinutes != null && t.dueDate != null && !t.isDone)
              (
                t,
                DateTime(
                  t.dueDate!.year,
                  t.dueDate!.month,
                  t.dueDate!.day,
                  0,
                  t.remindMinutes!,
                ),
              ),
        ].where((e) => e.$2.isAfter(now) && e.$2.isBefore(until)).toList()
        ..sort((a, b) => a.$2.compareTo(b.$2));
  return [
    for (final (t, at) in out.take(max))
      Reminder(
        // Unique within one scheduling pass, which is all it needs: every
        // pass replaces the whole set.
        id: Object.hash(t.id, at) & 0x7fffffff,
        at: at,
        title: t.title,
      ),
  ];
}

final _plugin = FlutterLocalNotificationsPlugin();
AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
    .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin
    >();
Future<bool?>? _ready;
var _askedThisRun = false;

// Default importance with no sound: it still counts as an alerting
// notification, so it shows on the lock screen and in the shade, unlike a
// "silent" low-importance one that the lock screen may hide.
const _details = NotificationDetails(
  android: AndroidNotificationDetails(
    'todo_reminders',
    '할 일 알림',
    channelDescription: '할 일에 정한 시간에 소리 없이 떠요',
    playSound: false,
    enableVibration: false,
    visibility: NotificationVisibility.public,
    category: AndroidNotificationCategory.reminder,
  ),
);

Future<bool?> _init() => _ready ??= _plugin.initialize(
  settings: const InitializationSettings(
    android: AndroidInitializationSettings('ic_stat_todo'),
  ),
);

/// Asks for what reminders need on Android: the notification permission
/// (13+, a no-op once answered), then, once per run, "알람 및 리마인더" so they
/// come on the minute. Without that one Android may hold a reminder back
/// by up to an hour.
Future<void> askReminderPermission([BuildContext? context]) async {
  if (kIsWeb || !Platform.isAndroid) return;
  await _init();
  final firstAsk = !_askedThisRun;
  _askedThisRun = true;
  await _android?.requestNotificationsPermission();
  if (!firstAsk || context == null || !context.mounted) return;
  if (await _android?.canScheduleExactNotifications() ?? true) return;
  if (!context.mounted) return;
  final go = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('알림을 제시간에 받으려면'),
      content: const Text(
        '설정에서 "알람 및 리마인더"를 허용해주세요. '
        '허용하지 않으면 알림이 최대 1시간까지 늦게 뜰 수 있어요.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('나중에'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('허용하러 가기'),
        ),
      ],
    ),
  );
  if (go == true) await _android?.requestExactAlarmsPermission();
}

var _queue = Future<void>.value();
var _latest = const <TodoItem>[];
AppLifecycleListener? _onResume;

/// Replaces this phone's scheduled reminders with the ones [todos] call for.
/// Passes run one after another, so quick list updates can't interleave.
Future<void> rescheduleReminders(List<TodoItem> todos) {
  if (kIsWeb || !Platform.isAndroid) return Future.value();
  _latest = todos;
  // Coming back to the app re-arms them too: after "알람 및 리마인더" is
  // allowed, and in case Android dropped any meanwhile (it takes back a
  // fresh install's exact alarms, for one).
  _onResume ??= AppLifecycleListener(
    onResume: () => rescheduleReminders(_latest),
  );
  return _queue = _queue
      .then((_) => _reschedule(todos))
      .catchError((Object e) => debugPrint('reminders: $e'));
}

Future<void> _reschedule(List<TodoItem> todos) async {
  await _init();
  final reminders = upcomingReminders(todos, DateTime.now());
  // Pending ones only: a reminder already sitting in the shade stays.
  await _plugin.cancelAllPendingNotifications();
  if (reminders.isEmpty) return;
  // A reminder set on the PC needs the phone's permission too.
  if (!_askedThisRun) await askReminderPermission();
  var exact = await _android?.canScheduleExactNotifications() ?? false;
  for (final r in reminders) {
    Future<void> schedule(AndroidScheduleMode mode) => _plugin.zonedSchedule(
      id: r.id,
      title: r.title,
      body: '할 일 시간이에요',
      scheduledDate: tz.TZDateTime.from(r.at, tz.UTC),
      notificationDetails: _details,
      androidScheduleMode: mode,
    );
    try {
      await schedule(
        exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } on PlatformException {
      if (!exact) rethrow;
      // Permission taken back mid-pass: the rest go inexact.
      exact = false;
      await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }
}
