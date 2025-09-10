import 'package:flutter/material.dart';
import 'auth_service.dart';
import '../home/home_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  static const route = '/register';
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService().register(_email.text.trim(), _pass.text);
      if (mounted) Navigator.pushReplacementNamed(context, HomeScreen.route);
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('إنشاء حساب')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'البريد الإلكتروني',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'أدخلي البريد';
                        final ok = RegExp(r'^\S+@\S+\.\S+$').hasMatch(v.trim());
                        return ok ? null : 'صيغة البريد غير صحيحة';
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _pass,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'كلمة المرور',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'أدخلي كلمة المرور';
                        if (v.length < 8) return 'على الأقل 8 أحرف';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirm,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'تأكيد كلمة المرور',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v != _pass.text) ? 'الكلمتان غير متطابقتين' : null,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('إنشاء الحساب'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.pushReplacementNamed(context, LoginScreen.route),
                      child: const Text('لديك حساب؟ تسجيل الدخول'),
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
