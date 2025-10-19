import 'package:flutter/material.dart';

class AvatarView extends StatelessWidget {
  const AvatarView({super.key, required this.avatarId, this.size = 36});

  final String? avatarId;
  final double size;

  static const _presets = {
    'fox_purple':     ('🦊', [Color(0xFF6A73FF), Color(0xFFE6E9FF)]),
    'panda_blue':     ('🐼', [Color(0xFF38BDF8), Color(0xFFD1FAFF)]),
    'cat_pink':       ('🐱', [Color(0xFFF472B6), Color(0xFFFCE7F3)]),
    'dog_orange':     ('🐶', [Color(0xFFFB923C), Color(0xFFFFEDD5)]),
    'koala_green':    ('🐨', [Color(0xFF34D399), Color(0xFFD1FAE5)]),
    'penguin_sky':    ('🐧', [Color(0xFF60A5FA), Color(0xFFE0E7FF)]),
    'bear_violet':    ('🐻', [Color(0xFFA78BFA), Color(0xFFEDE9FE)]),
    'bunny_mint':     ('🐰', [Color(0xFF4ADE80), Color(0xFFD1FAE5)]),
    'tiger_sunset':   ('🐯', [Color(0xFFF59E0B), Color(0xFFFFF7ED)]),
    'owl_night':      ('🦉', [Color(0xFF64748B), Color(0xFFE2E8F0)]),
    'alien_candy':    ('👽', [Color(0xFF22D3EE), Color(0xFFCCFBF1)]),
    'robot_lavender': ('🤖', [Color(0xFF93C5FD), Color(0xFFE0E7FF)]),
  };

  @override
  Widget build(BuildContext context) {
    final preset = _presets[avatarId];
    if (preset == null) {
      // fallback لو ما فيه أفاتار محدد
      return CircleAvatar(radius: size/2, child: const Text('🙂', style: TextStyle(fontSize: 18)));
    }
    final emoji = preset.$1;
    final colors = preset.$2 as List<Color>;
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: colors, begin: Alignment.topRight, end: Alignment.bottomLeft),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0,2))],
      ),
      alignment: Alignment.center,
      child: Text(emoji, style: TextStyle(fontSize: size * 0.55)),
    );
  }
}
