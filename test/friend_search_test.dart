import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_on/providers/providers.dart';
import 'package:todo_on/services/firestore_service.dart';
import 'package:todo_on/widgets/friends_pane.dart';

class _Me extends Fake implements User {
  @override
  String get uid => 'me';
}

/// IDs held by everyone, like the `handles` collection.
class _FakePeople extends Fake implements FirestoreService {
  final handles = <String, FoundPerson>{
    'garam': const FoundPerson(uid: 'u_garam', handle: 'garam', nickname: '가람'),
    'garam.k': const FoundPerson(
      uid: 'u_garamk',
      handle: 'garam.k',
      nickname: '김가람',
    ),
    'sora': const FoundPerson(uid: 'u_sora', handle: 'sora', nickname: '소라'),
  };
  final profile = StreamController<Map<String, dynamic>?>.broadcast();
  final followed = <String>[];

  @override
  Future<bool> claimHandle(
    String handle, {
    String? oldHandle,
    required String nickname,
  }) async {
    final holder = handles[handle];
    if (holder != null && holder.uid != 'me') return false;
    handles.remove(oldHandle);
    handles[handle] = FoundPerson(
      uid: 'me',
      handle: handle,
      nickname: nickname,
    );
    profile.add({'nickname': nickname, 'handle': handle});
    return true;
  }

  @override
  Future<List<FoundPerson>> searchPeople(String query) async => [
    for (final p in handles.values)
      if (p.uid != 'me' &&
          (p.handle.startsWith(query.toLowerCase()) || p.nickname == query))
        p,
  ];

  @override
  Future<void> followUser(String targetUid) async => followed.add(targetUid);
}

Future<_FakePeople> _pump(WidgetTester tester, {String? myHandle}) async {
  tester.view.physicalSize = const Size(500, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final service = _FakePeople();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(_Me())),
        firestoreServiceProvider.overrideWithValue(service),
        profileDocProvider.overrideWith((ref) async* {
          yield {'nickname': '지우', if (myHandle != null) 'handle': myHandle};
          yield* service.profile.stream;
        }),
        followingProvider.overrideWith((ref) => Stream.value(['u_sora'])),
        friendProfileProvider.overrideWith(
          (ref, uid) => Stream.value({'nickname': '소라'}),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: FriendsPane())),
    ),
  );
  await tester.pumpAndSettle();
  return service;
}

void main() {
  test('IDs are lower case, 3-20 of a-z 0-9 . _', () {
    expect(normalizeHandle(' @Jiwoo_01 '), 'jiwoo_01');
    expect(normalizeHandle('ab'), isNull);
    expect(normalizeHandle('지우'), isNull);
    expect(normalizeHandle('a' * 21), isNull);
    expect(normalizeHandle('ji woo'), isNull);
  });

  testWidgets('search by ID finds people and adds one as a friend', (
    tester,
  ) async {
    final service = await _pump(tester);
    await tester.enterText(find.byType(TextField), 'gar');
    await tester.tap(find.widgetWithText(FilledButton, '검색'));
    await tester.pumpAndSettle();

    expect(find.text('@garam'), findsOneWidget);
    expect(find.text('@garam.k'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '추가').first);
    await tester.pumpAndSettle();
    expect(service.followed, ['u_garam']);
  });

  testWidgets('search by exact nickname; a friend already shows as 친구', (
    tester,
  ) async {
    await _pump(tester);
    await tester.enterText(find.byType(TextField), '소라');
    await tester.tap(find.widgetWithText(FilledButton, '검색'));
    await tester.pumpAndSettle();
    expect(find.text('@sora'), findsOneWidget);
    expect(find.text('친구'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '추가'), findsNothing);
  });

  testWidgets('nobody found says so', (tester) async {
    await _pump(tester);
    await tester.enterText(find.byType(TextField), 'nobody');
    await tester.tap(find.widgetWithText(FilledButton, '검색'));
    await tester.pumpAndSettle();
    expect(find.textContaining('찾는 사람이 없어요'), findsOneWidget);
  });

  testWidgets('the friend-code way is still there', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('친구 코드'));
    await tester.pumpAndSettle();
    expect(find.text('내 친구 코드'), findsOneWidget);
    expect(find.text('me'), findsOneWidget);
    expect(find.text('코드로 친구 추가'), findsOneWidget);
    expect(find.text('친구 찾기'), findsNothing);
  });

  testWidgets('an ID someone else has is refused; a free one is mine', (
    tester,
  ) async {
    final service = await _pump(tester);
    await tester.tap(find.text('만들기'));
    await tester.pumpAndSettle();
    final field = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );

    await tester.enterText(field, 'Garam');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('이미 누가 쓰고 있는 아이디예요'), findsOneWidget);
    expect(service.handles['garam']!.uid, 'u_garam');

    await tester.enterText(field, 'x');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.textContaining('3~20자'), findsOneWidget);

    await tester.enterText(field, 'Jiwoo');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(service.handles['jiwoo']!.uid, 'me');
    expect(find.text('@jiwoo'), findsOneWidget);
    expect(find.text('바꾸기'), findsOneWidget);
  });
}
