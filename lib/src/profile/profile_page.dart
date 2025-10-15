import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_profile_page.dart'; // <-- مهم

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  static const route = '/profile';

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

// ====== نفس Presets المستخدمة في صفحة التعديل (للعرض فقط) ======
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

class _ProfilePageState extends State<ProfilePage> {
  bool _busy = false;

  // ألوان وتدرج موحد مثل الهوم
  static const LinearGradient _kAppGradient = LinearGradient(
    colors: [Color(0xFF6A73FF), Color(0xFFE6E9FF)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  final Color _bg = const Color(0xFFF6F8FF);
  final Color _card = Colors.white;
  final Color _divider = const Color(0x1A000000);
  final Color _title = const Color(0xFF0F172A);
  final Color _sub = const Color(0x990F172A);

  User? get _user => FirebaseAuth.instance.currentUser;

  String get _displayName {
    final u = _user;
    final dn = u?.displayName?.trim();
    if (dn != null && dn.isNotEmpty) return dn;
    final email = u?.email ?? '';
    if (email.contains('@')) return email.split('@').first;
    return 'User';
  }

  String get _email => _user?.email ?? '—';
  String get _accountType => 'Basic Account';

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openEdit() async {
    final res = await Navigator.of(context).pushNamed(EditProfilePage.route);
    // لو تم الحفظ في صفحة التعديل، ننعش العرض
    if (mounted && res == true) setState(() {});
  }

  void _backupComingSoon() => _toast('Backup قادم قريبًا ✨');

  Future<void> _confirmResetData() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset Data?'),
        content: const Text('سيتم حذف جميع الفواتير والضمانات الخاصة بك. لا يمكن التراجع.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await _resetData();
  }

  Future<void> _resetData() async {
    if (_user == null) return _toast('يرجى تسجيل الدخول أولاً.');
    try {
      setState(() => _busy = true);
      final uid = _user!.uid;
      final fs = FirebaseFirestore.instance;

      Future<void> deleteCollection(Query<Map<String, dynamic>> q) async {
        const page = 200;
        while (true) {
          final snap = await q.limit(page).get();
          if (snap.docs.isEmpty) break;
          final batch = fs.batch();
          for (final d in snap.docs) {
            batch.delete(d.reference);
          }
          await batch.commit();
          if (snap.docs.length < page) break;
        }
      }

      await deleteCollection(fs.collection('Bills').where('user_id', isEqualTo: uid));
      await deleteCollection(fs.collection('Warranties').where('user_id', isEqualTo: uid));

      _toast('تم حذف بياناتك بنجاح.');
    } catch (e) {
      _toast('حدث خطأ أثناء الحذف: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _contactUs() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            ListTile(
              leading: Icon(Icons.email_outlined),
              title: Text('Email'),
              subtitle: Text('support@billwise.app'),
            ),
            ListTile(
              leading: Icon(Icons.chat_bubble_outline),
              title: Text('Feedback'),
              subtitle: Text('Tell us what to improve'),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Help & FAQ'),
        content: const Text(
          '• أضف فواتيرك وضماناتك لتتبع المواعيد.\n'
              '• استخدم OCR لقراءة البيانات من الفاتورة.\n'
              '• فعّل الإشعارات للتذكير بالاسترجاع أو الضمان.\n'
              '• قريبًا: النسخ الاحتياطي والتصدير.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return AbsorbPointer(
      absorbing: _busy,
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: _bg,
            appBar: AppBar(
              elevation: 0,
              backgroundColor: _bg,
              title: const Text('Profile'),
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                // Header مع متابعة avatar_id من Firestore
                if (uid == null)
                  _ProfileHeader(
                    displayName: _displayName,
                    email: _email,
                    accountType: _accountType,
                    onEdit: _openEdit,
                    card: _card,
                    divider: _divider,
                    title: _title,
                    sub: _sub,
                    avatarId: null,
                  )
                else
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
                    builder: (context, snap) {
                      final avatarId = snap.data?.data()?['avatar_id'] as String?;
                      final phone = snap.data?.data()?['phone'] as String?;
                      // ممكن نستخدم phone لاحقًا إذا تبغين عرضه.
                      return _ProfileHeader(
                        displayName: _displayName,
                        email: _email,
                        accountType: _accountType,
                        onEdit: _openEdit,
                        card: _card,
                        divider: _divider,
                        title: _title,
                        sub: _sub,
                        avatarId: avatarId,
                      );
                    },
                  ),

                const SizedBox(height: 18),
                Text(
                  'Tools',
                  style: TextStyle(color: _title, fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),

                _SettingTile(
                  gradient: _kAppGradient,
                  icon: Icons.cloud_upload_outlined,
                  title: 'Backup',
                  subtitle: 'Save a copy of your data',
                  onTap: _backupComingSoon,
                  titleColor: _title,
                  subColor: _sub,
                  divider: _divider,
                ),
                _SettingTile(
                  gradient: _kAppGradient,
                  icon: Icons.delete_sweep_outlined,
                  title: 'Reset Data',
                  subtitle: 'Delete all bills & warranties',
                  danger: true,
                  onTap: _confirmResetData,
                  titleColor: _title,
                  subColor: _sub,
                  divider: _divider,
                ),
                _SettingTile(
                  gradient: _kAppGradient,
                  icon: Icons.chat_bubble_outline,
                  title: 'Contact Us',
                  subtitle: 'Support & feedback',
                  onTap: _contactUs,
                  titleColor: _title,
                  subColor: _sub,
                  divider: _divider,
                ),
                _SettingTile(
                  gradient: _kAppGradient,
                  icon: Icons.help_outline,
                  title: 'Help / FAQ',
                  subtitle: 'How BillWise works',
                  onTap: _showHelp,
                  titleColor: _title,
                  subColor: _sub,
                  divider: _divider,
                ),

                const SizedBox(height: 24),
                Center(
                  child: Text('BillWise • v1.0.0', style: TextStyle(color: _sub, fontSize: 12)),
                ),
              ],
            ),
          ),

          if (_busy)
            Container(
              color: Colors.black26,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String displayName;
  final String email;
  final String accountType;
  final VoidCallback onEdit;
  final Color card, divider, title, sub;
  final String? avatarId; // جديد

  const _ProfileHeader({
    required this.displayName,
    required this.email,
    required this.accountType,
    required this.onEdit,
    required this.card,
    required this.divider,
    required this.title,
    required this.sub,
    this.avatarId,
  });

  _AvatarPreset? _findPreset(String? id) {
    if (id == null) return null;
    for (final p in _presets) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final preset = _findPreset(avatarId);

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: divider),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _Avatar(
            name: displayName,
            title: title,
            preset: preset, // لو موجود نعرضه
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName, style: TextStyle(color: title, fontSize: 18, fontWeight: FontWeight.w700)),
                Text(email, style: TextStyle(color: sub, fontSize: 13)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: divider),
                    gradient: const LinearGradient(
                      colors: [Color(0x1A6A73FF), Color(0x1AE6E9FF)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                  ),
                  child: Text(accountType, style: TextStyle(color: title, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit'),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final Color title;
  final _AvatarPreset? preset; // جديد

  const _Avatar({required this.name, required this.title, this.preset});

  @override
  Widget build(BuildContext context) {
    // لو فيه preset نعرض الإيموجي + التدرج
    if (preset != null) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: preset!.gradient,
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          border: Border.all(color: const Color(0x1A000000)),
        ),
        alignment: Alignment.center,
        child: Text(preset!.emoji, style: const TextStyle(fontSize: 24)),
      );
    }

    // خلاف ذلك: الأحرف الأولى
    String initials = name.isNotEmpty ? name.characters.first.toUpperCase() : 'U';
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: const Color(0x1A000000)),
      ),
      alignment: Alignment.center,
      child: Text(initials, style: TextStyle(color: title, fontSize: 20, fontWeight: FontWeight.w800)),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final LinearGradient gradient;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;
  final Color titleColor, subColor, divider;

  const _SettingTile({
    required this.gradient,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.titleColor,
    required this.subColor,
    required this.divider,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: divider),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: danger
                  ? [const Color(0xFFFF8A80).withOpacity(0.20), const Color(0xFFFF5252).withOpacity(0.20)]
                  : [gradient.colors.first.withOpacity(0.20), gradient.colors.last.withOpacity(0.20)],
              begin: gradient.begin,
              end: gradient.end,
            ),
            border: Border.all(
              color: danger ? const Color(0xFFFF5252) : gradient.colors.first,
              width: 1.2,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 22, color: danger ? const Color(0xFFFF5252) : gradient.colors.first),
        ),
        title: Text(title, style: TextStyle(color: titleColor, fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: TextStyle(color: subColor)),
        trailing: Icon(Icons.chevron_right, color: Colors.black.withOpacity(0.45)),
        onTap: onTap,
      ),
    );
  }
}
