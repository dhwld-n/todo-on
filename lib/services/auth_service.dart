import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../models/category.dart';
import 'firestore_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Stream<User?> get userChanges => _auth.userChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signUp(
    String email,
    String password, {
    required String nickname,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user?.updateDisplayName(nickname);
    await credential.user?.reload();
    final uid = credential.user?.uid;
    if (uid != null) {
      final service = FirestoreService(uid);
      await service.saveProfile(nickname: nickname);
      const uuid = Uuid();
      await service.addCategory(
        TodoCategory(
          id: uuid.v4(),
          name: '카테고리1',
          colorValue: 0xFFEF5350,
          order: 0,
        ),
      );
      await service.addCategory(
        TodoCategory(
          id: uuid.v4(),
          name: '카테고리2',
          colorValue: 0xFFFF7043,
          order: 1,
        ),
      );
    }
    return credential;
  }

  Future<void> signOut() {
    return _auth.signOut();
  }

  Future<void> updateDisplayName(String nickname) async {
    await _auth.currentUser?.updateDisplayName(nickname);
    await _auth.currentUser?.reload();
  }

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  String messageForError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return '이메일 형식이 올바르지 않아요.';
      case 'user-disabled':
        return '비활성화된 계정이에요.';
      case 'user-not-found':
        return '가입되지 않은 이메일이에요.';
      case 'wrong-password':
      case 'invalid-credential':
        return '이메일 또는 비밀번호가 올바르지 않아요.';
      case 'email-already-in-use':
        return '이미 가입된 이메일이에요.';
      case 'weak-password':
        return '비밀번호는 6자 이상이어야 해요.';
      default:
        return e.message ?? '알 수 없는 오류가 발생했어요.';
    }
  }
}
