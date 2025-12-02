import 'package:flutter/material.dart';
import 'auth_service.dart';
import '../../welcome/welcome_screen.dart';

// تم حذف جميع ثوابت الألوان المخصصة (مثل _kBg, _kCard, _kAccent)
// وسنعتمد على Theme.of(context) والألوان الخاصة بالثيم الحالي.

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  static const route = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

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
      // نفترض وجود AuthService
      await AuthService.instance.signIn(_email.text.trim(), _password.text);
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (_) {
      setState(() => _error = 'Login failed. Check your email and password.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _input(BuildContext context, String label, {IconData? icon}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // ألوان ديناميكية للمدخلات
    final accentColor = theme.primaryColor;
    final textColor = theme.textTheme.bodyMedium!.color!;
    final subtleColor = isDark ? Colors.white70 : Colors.black54;

    // خلفية حقل الإدخال: لون داكن ثابت في Dark Mode، لون فاتح/رمادي خفيف في Light Mode
    final fieldFillColor = isDark ? const Color(0xFF221B3A) : Colors.grey.shade100;

    // حدود الحقل: شفافة في Dark Mode، رمادية خفيفة في Light Mode
    final strokeColor = isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1);

    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: subtleColor),
      prefixIcon: icon == null ? null : Icon(icon, color: subtleColor),
      filled: true,
      fillColor: fieldFillColor,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: strokeColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: accentColor, width: 1.2),
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
    final theme = Theme.of(context);
    final accentColor = theme.primaryColor;
    final textColor = theme.textTheme.bodyMedium!.color!;
    final cardBg = theme.cardColor;
    final subtleColor = theme.hintColor; // استخدام hintColor للنصوص الثانوية

    return Directionality(
      textDirection: TextDirection.ltr, // English layout
      child: Scaffold(
        // استخدام لون خلفية الثيم
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          // AppBarTheme سيحدد الألوان
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Back',
            // استخدام لون نص الثيم للأيقونة
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          title: Text('Log in', style: TextStyle(color: textColor, fontWeight: FontWeight.w700)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ===== Form Card (Theme Aware) =====
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: cardBg, // لون البطاقة من الثيم
                          borderRadius: BorderRadius.circular(_kRadius),
                          border: Border.fromBorderSide(
                            BorderSide(color: theme.dividerColor), // لون الحدود من الثيم
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.10),
                              blurRadius: 10,
                              spreadRadius: 1,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Welcome back',
                                  style: TextStyle(
                                    color: subtleColor, // لون ثانوي
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
                                  style: TextStyle(color: textColor), // لون النص المدخل
                                  decoration: _input(context, 'Email', icon: Icons.email_outlined),
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
                                  style: TextStyle(color: textColor), // لون النص المدخل
                                  decoration: _input(context, 'Password', icon: Icons.lock_outline).copyWith(
                                    suffixIcon: IconButton(
                                      onPressed: () => setState(() => _obscure = !_obscure),
                                      icon: Icon(
                                        _obscure ? Icons.visibility : Icons.visibility_off,
                                        color: subtleColor, // لون ثانوي
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
                                    color: Colors.red.withOpacity(theme.brightness == Brightness.dark ? .10 : .05),
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
                                          style: TextStyle(color: textColor, fontSize: 13),
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
                                    backgroundColor: accentColor, // لون الزر الأساسي
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
                                      : const Text('Log in', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                ),
                              ),
                              const SizedBox(height: 8),

                              TextButton(
                                onPressed: _loading ? null : () => Navigator.pushNamed(context, '/register'),
                                child: Text(
                                  'Create an account',
                                  style: TextStyle(color: subtleColor, fontWeight: FontWeight.w600), // لون ثانوي
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

const double _kRadius = 20;