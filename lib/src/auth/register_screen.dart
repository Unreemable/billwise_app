import 'package:flutter/material.dart';
import 'auth_service.dart';
import '../../welcome/welcome_screen.dart';

// تم حذف جميع ثوابت الألوان المخصصة (مثل _kBg, _kCard, _kAccent)
// وسنعتمد على Theme.of(context) والألوان الخاصة بالثيم الحالي.

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  static const route = '/register';

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email    = TextEditingController();
  final _password = TextEditingController();
  final _confirm  = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  bool _obscure2 = true;
  String? _error;

  // ثابت محلي للاستخدام داخل هذا الكلاس فقط
  static const double _kRadius = 20;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      // نفترض وجود AuthService
      await AuthService.instance.register(_email.text.trim(), _password.text);
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      setState(() => _error = 'Registration failed. This email may already be in use.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _input(BuildContext context, String label, {IconData? icon}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // ألوان ديناميكية للمدخلات
    final accentColor = theme.primaryColor;
    final subtleColor = isDark ? Colors.white70 : Colors.black54;

    // خلفية حقل الإدخال: لون داكن ثابت في Dark Mode، لون فاتح/رمادي خفيف في Light Mode
    // استخدام لون الـ field الداكن (#241C3E) لـ Dark Mode
    final fieldFillColor = isDark ? const Color(0xFF241C3E) : Colors.grey.shade100;

    // حدود الحقل: شفافة في Dark Mode، رمادية خفيفة في Light Mode
    final strokeColor = isDark ? Colors.white.withOpacity(0.13) : Colors.black.withOpacity(0.1);

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
        borderSide: BorderSide(color: accentColor, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = theme.primaryColor;
    final textColor = theme.textTheme.bodyMedium!.color!;
    final cardBg = theme.cardColor;
    final subtleColor = theme.hintColor;
    final isDark = theme.brightness == Brightness.dark;

    // لون الحدود الخارجية للكارد (للتطبيق الصارم)
    final cardStrokeColor = isDark ? Colors.white.withOpacity(0.13) : Colors.black.withOpacity(0.1);

    return Directionality(
      textDirection: TextDirection.ltr, // English layout
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Back',
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          title: Text('Create account',
              style: TextStyle(color: textColor, fontWeight: FontWeight.w700)),
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
                          color: cardBg,
                          borderRadius: BorderRadius.circular(_kRadius),
                          border: Border.fromBorderSide(BorderSide(color: cardStrokeColor)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.25 : 0.10),
                              blurRadius: 18,
                              spreadRadius: isDark ? -10 : 0,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Let’s get you started',
                                  style: TextStyle(
                                    color: subtleColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              TextFormField(
                                controller: _email,
                                style: TextStyle(color: textColor),
                                decoration: _input(context, 'Email address', icon: Icons.email_outlined),
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) =>
                                (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                              ),
                              const SizedBox(height: 12),

                              TextFormField(
                                controller: _password,
                                style: TextStyle(color: textColor),
                                decoration: _input(context, 'Password', icon: Icons.lock_outline).copyWith(
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(() => _obscure = !_obscure),
                                    icon: Icon(
                                      _obscure ? Icons.visibility : Icons.visibility_off,
                                      color: subtleColor,
                                    ),
                                  ),
                                ),
                                obscureText: _obscure,
                                validator: (v) =>
                                (v == null || v.length < 6) ? 'At least 6 characters' : null,
                              ),
                              const SizedBox(height: 12),

                              TextFormField(
                                controller: _confirm,
                                style: TextStyle(color: textColor),
                                decoration: _input(context, 'Confirm password', icon: Icons.lock_person_outlined).copyWith(
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(() => _obscure2 = !_obscure2),
                                    icon: Icon(
                                      _obscure2 ? Icons.visibility : Icons.visibility_off,
                                      color: subtleColor,
                                    ),
                                  ),
                                ),
                                obscureText: _obscure2,
                                validator: (v) =>
                                (v != _password.text) ? 'Passwords do not match' : null,
                              ),

                              const SizedBox(height: 14),

                              if (_error != null)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(isDark ? .10 : .05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.redAccent),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline,
                                          color: Colors.redAccent, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(_error!,
                                            style: TextStyle(color: textColor, fontSize: 13)),
                                      ),
                                    ],
                                  ),
                                ),

                              const SizedBox(height: 14),

                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: FilledButton(
                                  onPressed: _loading ? null : _submit,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: accentColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: _loading
                                      ? const SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                      : const Text('Create account',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                ),
                              ),
                              const SizedBox(height: 8),

                              TextButton(
                                onPressed: _loading
                                    ? null
                                    : () => Navigator.pushReplacementNamed(context, '/login'),
                                child: Text(
                                  'Already have an account? Log in',
                                  style: TextStyle(color: subtleColor, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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