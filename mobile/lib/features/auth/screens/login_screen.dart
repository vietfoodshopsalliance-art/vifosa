// mobile/lib/features/auth/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

const _storage = FlutterSecureStorage();
const _kSavedIdentifier = 'saved_identifier';
const _kSavedPassword = 'saved_password';
const _kRememberMe = 'remember_me';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final remember = await _storage.read(key: _kRememberMe);
    if (remember != 'true') return;
    final identifier = await _storage.read(key: _kSavedIdentifier);
    final password = await _storage.read(key: _kSavedPassword);
    if (identifier != null && password != null) {
      setState(() {
        _identifierCtrl.text = identifier;
        _passwordCtrl.text = password;
        _rememberMe = true;
      });
    }
  }

  Future<void> _persistOrClear() async {
    if (_rememberMe) {
      await _storage.write(key: _kRememberMe, value: 'true');
      await _storage.write(key: _kSavedIdentifier, value: _identifierCtrl.text.trim());
      await _storage.write(key: _kSavedPassword, value: _passwordCtrl.text);
    } else {
      await _storage.delete(key: _kRememberMe);
      await _storage.delete(key: _kSavedIdentifier);
      await _storage.delete(key: _kSavedPassword);
    }
  }

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await _persistOrClear();
    await ref.read(authProvider.notifier).login(
          identifier: _identifierCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
    // Navigation do router redirect guard xử lý tự động
  }

  void _showForgotDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Quên mật khẩu'),
        content: const Text('Vui lòng liên hệ admin để được reset mật khẩu tạm thời.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.status == AuthStatus.loading;
    final error = authState.error;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                // Logo
                Center(
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 90,
                    height: 90,
                    errorBuilder: (_, __, ___) => Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.restaurant, size: 48, color: Color(0xFFE53935)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'Vifosa',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE53935),
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Identifier
                TextFormField(
                  controller: _identifierCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tên đăng nhập / Email / SĐT',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Không được để trống' : null,
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Không được để trống' : null,
                ),
                const SizedBox(height: 4),

                // Ghi nhớ tài khoản
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      activeColor: const Color(0xFFE53935),
                      onChanged: (v) => setState(() => _rememberMe = v ?? false),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _rememberMe = !_rememberMe),
                      child: const Text('Ghi nhớ tài khoản'),
                    ),
                  ],
                ),

                // Lỗi từ server
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(error,
                        style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ),

                const SizedBox(height: 12),

                // Nút đăng nhập
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Đăng nhập',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 20),

                // Đăng ký
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Chưa có tài khoản? '),
                    GestureDetector(
                      onTap: () => context.go('/register'),
                      child: const Text('Đăng ký',
                          style: TextStyle(
                              color: Color(0xFFE53935),
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Quên mật khẩu
                Center(
                  child: GestureDetector(
                    onTap: _showForgotDialog,
                    child: const Text('Quên mật khẩu?',
                        style: TextStyle(
                            color: Color(0xFF757575),
                            decoration: TextDecoration.underline)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}