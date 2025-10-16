import 'package:flutter/material.dart';

/// خلفية باستيل ناعمة (لافندر فاتح إلى وردي فاتح)
class SoftPastelBackground extends StatelessWidget {
  final Widget child;
  const SoftPastelBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFF5EEFF), // Lavender light
            Color(0xFFF8E7FF), // Pink soft
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: child,
    );
  }
}
