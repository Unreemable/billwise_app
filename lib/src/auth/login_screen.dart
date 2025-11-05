import 'package:flutter/material.dart';
import 'auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  static const route = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

// ===== Palette & Style =====
const Color _kBg      = Color(0xFF0E0B1F);   // خلفية عامة
const Color _kCard    = Color(0xFF17122B);   // كرت أغمق قليلاً لراحة العين
const Color _kField   = Color(0xFF221B3A);   // حقول
const Color _kStroke  = Color(0x1AFFFFFF);   // حدود خفيفة جدًا
const Color _kText    = Colors.white;
const Color _kTextSub = Color(0x99FFFFFF);
const Color _kAccent  = Color(0xFF6A73FF);   // زر
const Color _kAmber   = Color(0xFFFFD993);   // أصفر ناعم للعبارة

const double _kRadius = 20;

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await AuthService.instance.signIn(_email.text.trim(), _password.text);
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (_) {
      setState(() => _error = 'Login failed. Check your email and password.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _input(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _kTextSub),
      prefixIcon: icon == null ? null : Icon(icon, color: _kTextSub),
      filled: true,
      fillColor: _kField,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _kStroke),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _kAccent, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _kBg,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ===== Logo (بدون حواف، مع وهج بسيط) =====
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(_kRadius),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6C3EFF).withOpacity(0.25),
                              blurRadius: 28,
                              spreadRadius: -6,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/BillWise_logo.png',
                          width: 120,
                          height: 120,
                          fit: BoxFit.contain,
                          semanticLabel: 'BillWise Logo',
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ===== عبارة وسطية (أصفر ناعم / وسط / بدون نقطة) =====
                      const Text(
                        'كل فواتيرك وضماناتك في مكان واحد',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _kAmber,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                          letterSpacing: .2,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ===== Form Card =====
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: _kCard,
                          borderRadius: BorderRadius.circular(_kRadius),
                          border: const Border.fromBorderSide(
                            BorderSide(color: _kStroke),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 24,
                              spreadRadius: -20,
                              offset: const Offset(0, 18),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              // عنوان صغير داخل الكرت يوحّد التناسق
                              const Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'تسجيل الدخول',
                                  style: TextStyle(
                                    color: _kTextSub,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              SizedBox(
                                height: 54,
                                child: TextFormField(
                                  controller: _email,
                                  style: const TextStyle(color: _kText),
                                  decoration: _input('Email', icon: Icons.email_outlined),
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (v) =>
                                  (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                                ),
                              ),
                              const SizedBox(height: 12),

                              SizedBox(
                                height: 54,
                                child: TextFormField(
                                  controller: _password,
                                  style: const TextStyle(color: _kText),
                                  decoration: _input('Password', icon: Icons.lock_outline).copyWith(
                                    suffixIcon: IconButton(
                                      onPressed: () => setState(() => _obscure = !_obscure),
                                      icon: Icon(
                                        _obscure ? Icons.visibility : Icons.visibility_off,
                                        color: _kTextSub,
                                      ),
                                    ),
                                  ),
                                  obscureText: _obscure,
                                  validator: (v) =>
                                  (v == null || v.length < 6) ? 'At least 6 characters' : null,
                                ),
                              ),

                              const SizedBox(height: 10),

                              if (_error != null)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(.10),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.redAccent),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline,
                                          color: Colors.redAccent, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _error!,
                                          style: const TextStyle(color: _kText, fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              const SizedBox(height: 14),

                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: FilledButton(
                                  onPressed: _loading ? null : _submit,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _kAccent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: _loading
                                      ? const SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                      : const Text('Log in', style: TextStyle(fontSize: 16)),
                                ),
                              ),

                              const SizedBox(height: 8),

                              TextButton(
                                onPressed: _loading ? null : () => Navigator.pushNamed(context, '/register'),
                                child: const Text(
                                  'Create an account',
                                  style: TextStyle(color: _kTextSub, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
