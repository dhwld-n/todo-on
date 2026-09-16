import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../widgets/blinking_dot.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _isSignUp = false;
  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    final auth = ref.read(authServiceProvider);
    try {
      if (_isSignUp) {
        await auth.signUp(
          _emailController.text.trim(),
          _passwordController.text,
          nickname: _nicknameController.text.trim(),
        );
      } else {
        await auth.signIn(
          _emailController.text.trim(),
          _passwordController.text,
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _errorText = auth.messageForError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'TODO on',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontFamily: 'GriunGyuwon',
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(width: 6),
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: BlinkingDot(size: 10),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (_isSignUp) ...[
                      TextFormField(
                        controller: _nicknameController,
                        decoration: const InputDecoration(labelText: '닉네임'),
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => FocusScope.of(
                          context,
                        ).requestFocus(_emailFocusNode),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? '닉네임을 입력하세요'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '주로 쓰는 이메일을 입력해 주세요!',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).disabledColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    TextFormField(
                      controller: _emailController,
                      focusNode: _emailFocusNode,
                      decoration: const InputDecoration(labelText: '이메일'),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => FocusScope.of(
                        context,
                      ).requestFocus(_passwordFocusNode),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? '올바른 이메일을 입력하세요'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    if (_isSignUp) ...[
                      Text(
                        '위에서 적으신 이메일의 비밀번호가 아니여도 괜찮아요~',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).disabledColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    TextFormField(
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      decoration: const InputDecoration(labelText: '비밀번호'),
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _isLoading ? null : _submit(),
                      validator: (v) =>
                          (v == null || v.length < 6) ? '6자 이상 입력하세요' : null,
                    ),
                    if (_errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorText!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isSignUp ? '회원가입' : '로그인'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => setState(() => _isSignUp = !_isSignUp),
                      child: Text(_isSignUp ? '이미 계정이 있어요' : '계정이 없어요, 회원가입'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
