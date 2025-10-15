import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});
  static const route = '/edit-profile';

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

// ====== Avatar presets (بدون أصول صور؛ نعتمد إيموجي + تدرج) ======
class _AvatarPreset {
  final String id;
  final String emoji;
  final List<Color> gradient;
  const _AvatarPreset(this.id, this.emoji, this.gradient);
}

const List<_AvatarPreset> _presets = [
  _AvatarPreset('fox_purple',     '🦊', [Color(0xFF6A73FF), Color(0xFFE6E9FF)]),
  _AvatarPreset('panda_blue',     '🐼', [Color(0xFF38BDF8), Color(0xFFD1FAFF)]),
  _AvatarPreset('cat_pink',       '🐱', [Color(0xFFF472B6), Color(0xFFFCE7F3)]),
  _AvatarPreset('dog_orange',     '🐶', [Color(0xFFFB923C), Color(0xFFFFEDD5)]),
  _AvatarPreset('koala_green',    '🐨', [Color(0xFF34D399), Color(0xFFD1FAE5)]),
  _AvatarPreset('penguin_sky',    '🐧', [Color(0xFF60A5FA), Color(0xFFE0E7FF)]),
  _AvatarPreset('bear_violet',    '🐻', [Color(0xFFA78BFA), Color(0xFFEDE9FE)]),
  _AvatarPreset('bunny_mint',     '🐰', [Color(0xFF4ADE80), Color(0xFFD1FAE5)]),
  _AvatarPreset('tiger_sunset',   '🐯', [Color(0xFFF59E0B), Color(0xFFFFF7ED)]),
  _AvatarPreset('owl_night',      '🦉', [Color(0xFF64748B), Color(0xFFE2E8F0)]),
  _AvatarPreset('alien_candy',    '👽', [Color(0xFF22D3EE), Color(0xFFCCFBF1)]),
  _AvatarPreset('robot_lavender', '🤖', [Color(0xFF93C5FD), Color(0xFFE0E7FF)]),
];

class _EditProfilePageState extends State<EditProfilePage> {
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _selectedAvatarId;
  bool _saving = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    final u = _user;
    _nameCtrl.text  = (u?.displayName ?? '').trim();
    _emailCtrl.text = (u?.email ?? '').trim();

    // حمّل بيانات المستخدم من Firestore لو موجودة (avatar/phone)
    final uid = u?.uid;
    if (uid != null) {
      FirebaseFirestore.instance.collection('users').doc(uid).get().then((doc) {
        if (!mounted || !doc.exists) return;
        final m = doc.data()!;
        setState(() {
          _phoneCtrl.text = (m['phone'] ?? '').toString();
          _selectedAvatarId = (m['avatar_id'] ?? '') as String?;
        });
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  _AvatarPreset? _findPreset(String? id) {
    if (id == null) return null;
    for (final p in _presets) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> _pickAvatar() async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: GridView.builder(
            shrinkWrap: true,
            itemCount: _presets.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1,
            ),
            itemBuilder: (_, i) {
              final p = _presets[i];
              final selected = p.id == _selectedAvatarId;
              return InkWell(
                onTap: () {
                  setState(() => _selectedAvatarId = p.id);
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: p.gradient, begin: Alignment.topRight, end: Alignment.bottomLeft),
                    border: Border.all(color: selected ? Colors.black87 : Colors.black12, width: selected ? 2 : 1),
                  ),
                  alignment: Alignment.center,
                  child: Text(p.emoji, style: const TextStyle(fontSize: 26)),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    final u = _user;
    if (u == null) {
      _snack('Please sign in first.');
      return;
    }

    final newName  = _nameCtrl.text.trim();
    final newEmail = _emailCtrl.text.trim();
    final newPhone = _phoneCtrl.text.trim();

    setState(() => _saving = true);
    try {
      // 1) Firebase Auth: الاسم
      if (newName.isNotEmpty && newName != (u.displayName ?? '')) {
        await u.updateDisplayName(newName);
      }

      // 2) Firebase Auth: الإيميل (قد يتطلب re-auth)
      if (newEmail.isNotEmpty && newEmail != (u.email ?? '')) {
        try {
          await u.verifyBeforeUpdateEmail(newEmail); // يرسل إيميل تأكيد
          _snack('Verification email sent to $newEmail');
        } on FirebaseAuthException catch (e) {
          if (e.code == 'requires-recent-login') {
            _snack('Please re-login to change email.');
          } else {
            _snack('Email update failed: ${e.code}');
          }
        }
      }

      // 3) Firestore: phone + avatar_id + display_name/email (نسجّلها للواجهة)
      await FirebaseFirestore.instance.collection('users').doc(u.uid).set({
        'phone': newPhone,
        'avatar_id': _selectedAvatarId ?? '',
        'display_name': newName,
        'email': newEmail,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _snack('Saved.');
      if (mounted) Navigator.pop(context, true); // ارجعي للبروفايل وقولي له تحدّث
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final preset = _findPreset(_selectedAvatarId);

    return AbsorbPointer(
      absorbing: _saving,
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              title: const Text('Edit Profile'),
              actions: [
                TextButton(
                  onPressed: _save,
                  child: const Text('Save'),
                )
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                // Avatar preview
                Center(
                  child: InkWell(
                    onTap: _pickAvatar,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 88, height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: preset?.gradient ?? const [Color(0xFF6A73FF), Color(0xFFE6E9FF)],
                          begin: Alignment.topRight, end: Alignment.bottomLeft,
                        ),
                        border: Border.all(color: Colors.black12),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 2))],
                      ),
                      alignment: Alignment.center,
                      child: Text(preset?.emoji ?? '🙂', style: const TextStyle(fontSize: 36)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: _pickAvatar,
                    icon: const Icon(Icons.brush_outlined),
                    label: const Text('Choose Avatar'),
                  ),
                ),
                const SizedBox(height: 8),

                // Name
                TextField(
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),

                // Email
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.alternate_email),
                    helperText: 'Changing email may require re-login to verify.',
                  ),
                ),
                const SizedBox(height: 12),

                // Phone
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone (optional)',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 24),

                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Changes'),
                ),
              ],
            ),
          ),

          if (_saving)
            Container(color: Colors.black26, alignment: Alignment.center, child: const CircularProgressIndicator()),
        ],
      ),
    );
  }
}
