import 'package:flutter/material.dart';
import 'auth_service.dart';
import '../../welcome/welcome_screen.dart'; // اختياري لو حابة ترجعي للترحيب دائمًا

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  static const route = '/register';

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

// ===== Shared Palette & Style =====
const Color _kBg      = Color(0xFF0E0B1F);
const Color _kCard    = Color(0xFF1A1530);
const Color _kField   = Color(0xFF241C3E);
const Color _kStroke  = Color(0x22FFFFFF);
const Color _kText    = Color(0xFFFFFFFF);
const Color _kTextSub = Color(0x99FFFFFF);
const Color _kAccent  = Color(0xFF6A73FF);
const double _kRadius = 20;

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email    = TextEditingController();
  final _password = TextEditingController();
  final _confirm  = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  bool _obscure2 = true;
  String? _error;

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
      await AuthService.instance.register(_email.text.trim(), _password.text);
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      setState(() => _error = 'Registration failed. This email may already be in use.');
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
        borderSide: const BorderSide(color: _kAccent, width: 1.4),
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
    return Directionality(
      textDirection: TextDirection.ltr, // English layout
      child: Scaffold(
        backgroundColor: _kBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () {
              // يكفي pop للرجوع للترحيب بما أننا جئنا من هناك
              Navigator.pop(context);
              // أو لفرض الرجوع دائمًا للترحيب:
              // Navigator.pushReplacementNamed(context, WelcomeScreen.route);
            },
          ),
          title: const Text('Create account',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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
                      // ===== Form Card =====
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: _kCard,
                          borderRadius: BorderRadius.circular(18),
                          border: const Border.fromBorderSide(BorderSide(color: _kStroke)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 24,
                              spreadRadius: -18,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Let’s get you started',
                                  style: TextStyle(
                                    color: _kTextSub,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              TextFormField(
                                controller: _email,
                                style: const TextStyle(color: _kText),
                                decoration: _input('Email address', icon: Icons.email_outlined),
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) =>
                                (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                              ),
                              const SizedBox(height: 12),

                              TextFormField(
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
                              const SizedBox(height: 12),

                              TextFormField(
                                controller: _confirm,
                                style: const TextStyle(color: _kText),
                                decoration: _input('Confirm password', icon: Icons.lock_person_outlined).copyWith(
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(() => _obscure2 = !_obscure2),
                                    icon: Icon(
                                      _obscure2 ? Icons.visibility : Icons.visibility_off,
                                      color: _kTextSub,
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
                                        child: Text(_error!,
                                            style: const TextStyle(color: _kText, fontSize: 13)),
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
                                    backgroundColor: _kAccent,
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
                                child: const Text(
                                  'Already have an account? Log in',
                                  style: TextStyle(color: _kTextSub, fontWeight: FontWeight.w600),
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
