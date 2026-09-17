import 'dart:io';

import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/todo_item.dart';

/// Only Android has a "device calendar" concept the plugin can talk to.
bool get isDeviceCalendarSupported => !kIsWeb && Platform.isAndroid;

enum CalendarExportResult { success, permissionDenied, noCalendar, error }

bool _tzReady = false;

Future<CalendarExportResult> addTodoToDeviceCalendar(TodoItem todo) async {
  if (!isDeviceCalendarSupported) return CalendarExportResult.error;
  final dueDate = todo.dueDate;
  if (dueDate == null) return CalendarExportResult.error;

  if (!_tzReady) {
    tzdata.initializeTimeZones();
    _tzReady = true;
  }

  final plugin = DeviceCalendarPlugin();
  try {
    var permissions = await plugin.hasPermissions();
    if (permissions.data != true) {
      permissions = await plugin.requestPermissions();
    }
    if (permissions.data != true) return CalendarExportResult.permissionDenied;

    final calendarsResult = await plugin.retrieveCalendars();
    final calendars = calendarsResult.data ?? [];
    final target = calendars.firstWhere(
      (c) => c.isReadOnly != true,
      orElse: () => Calendar(),
    );
    if (target.id == null) return CalendarExportResult.noCalendar;

    // All-day events don't need a real local timezone, so UTC keeps this
    // simple and avoids depending on the device's timezone database lookup.
    final start = tz.TZDateTime(tz.UTC, dueDate.year, dueDate.month, dueDate.day);
    final end = start.add(const Duration(days: 1));
    final event = Event(
      target.id,
      title: todo.title,
      description: todo.note,
      start: start,
      end: end,
      allDay: true,
    );
    final createResult = await plugin.createOrUpdateEvent(event);
    if (createResult?.isSuccess == true) return CalendarExportResult.success;
    return CalendarExportResult.error;
  } catch (_) {
    return CalendarExportResult.error;
  }
}
