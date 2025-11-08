// lib/welcome/welcome_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../src/auth/login_screen.dart';
import '../src/auth/register_screen.dart';

const Color kBgDark  = Color(0xFF0E0B1F);
const Color kAccent  = Color(0xFF6A73FF);
const Color kText    = Colors.white;

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  static const route = '/welcome';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr, // English layout
      child: Scaffold(
        backgroundColor: kBgDark,
        body: SafeArea(
          child: Stack(
            children: [
              const _BottomWave(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),

                  // ===== كتلة (لوجو + سطر توضيحي) متموضعة أعلى قليلًا من المنتصف =====
                  Expanded(
                    child: Align(
                      alignment: const Alignment(0, -0.18), // ارفع/نزّل بتغيير القيمة (من -1 إلى 1)
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            _TitleLogoBig(),
                            SizedBox(height: 12),
                            Text(
                              'All your bills and warranties in one place',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70, height: 1.4, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ===== الأزرار أسفل الصفحة =====
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kAccent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () => Navigator.pushNamed(context, LoginScreen.route),
                            child: const Text('Log in',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 52,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: kAccent, width: 1.2),
                              foregroundColor: kAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () => Navigator.pushNamed(context, RegisterScreen.route),
                            child: const Text('Sign up',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TitleLogoBig extends StatelessWidget {
  const _TitleLogoBig();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final side = math.min(c.maxWidth, MediaQuery.of(context).size.height) * 0.38;
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: kAccent.withOpacity(0.25),
                blurRadius: 28,
                spreadRadius: -6,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Image.asset(
            'assets/BillWise_logo.png',
            height: side.clamp(120, 260),
            fit: BoxFit.contain,
            semanticLabel: 'BillWise Logo',
            errorBuilder: (_, __, ___) => const Text(
              'BillWise',
              style: TextStyle(
                color: kText, fontSize: 42, fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BottomWave extends StatelessWidget {
  const _BottomWave();
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: ClipPath(
        clipper: _WaveClipper(),
        child: Container(
          height: 210,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF141028), Color(0xFF0E0B1F)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
    );
  }
}

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()..lineTo(0, size.height * 0.40);
    final cp1 = Offset(size.width * 0.25, size.height * 0.10);
    final ep1 = Offset(size.width * 0.5, size.height * 0.24);
    final cp2 = Offset(size.width * 0.75, size.height * 0.36);
    final ep2 = Offset(size.width, size.height * 0.18);
    path
      ..quadraticBezierTo(cp1.dx, cp1.dy, ep1.dx, ep1.dy)
      ..quadraticBezierTo(cp2.dx, cp2.dy, ep2.dx, ep2.dy)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    return path;
  }
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
