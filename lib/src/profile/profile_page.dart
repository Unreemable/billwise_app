import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'edit_profile_page.dart';

import '../../main.dart'; // للوصول لحالة الثيم

// ========= الألوان =========
const LinearGradient kHeaderGradient = LinearGradient(
  colors: [Color(0xFF5F33E1), Color(0xFF0B0A1C)],
  begin: Alignment.topRight,
  end: Alignment.bottomLeft,
);

const Color kBg      = Color(0xFF0E0B1F);
const Color kCard    = Color(0xFF1A1530);
const Color kStroke  = Color(0x22FFFFFF);
const Color kText    = Color(0xFFFFFFFF);
const Color kTextSub = Color(0x99FFFFFF);
const Color kAccent  = Color(0xFF6A73FF);
const Color kDanger  = Color(0xFFFF5252);

// ====== نفس Presets المستخدمة في صفحة التعديل ======
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
  _AvatarPreset('deer_gold',      '🦌', [Color(0xFFFB923C), Color(0xFFFFEDD5)]),
  _AvatarPreset('koala_green',    '🐨', [Color(0xFF34D399), Color(0xFFD1FAE5)]),
  _AvatarPreset('penguin_sky',    '🐧', [Color(0xFF60A5FA), Color(0xFFE0E7FF)]),
  _AvatarPreset('bear_violet',    '🐻', [Color(0xFFA78BFA), Color(0xFFEDE9FE)]),
  _AvatarPreset('bunny_mint',     '🐰', [Color(0xFF4ADE80), Color(0xFFD1FAE5)]),
  _AvatarPreset('tiger_sunset',   '🐯', [Color(0xFFF59E0B), Color(0xFFFFF7ED)]),
  _AvatarPreset('owl_night',      '🦉', [Color(0xFF64748B), Color(0xFFE2E8F0)]),
  _AvatarPreset('alien_candy',    '👽', [Color(0xFF22D3EE), Color(0xFFCCFBF1)]),
  _AvatarPreset('robot_lavender', '🤖', [Color(0xFF93C5FD), Color(0xFFE0E7FF)]),
];

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  static const route = '/profile';

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _busy = false;

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
    if (mounted && res == true) setState(() {});
  }

  void _backupComingSoon() => _toast('Backup قادم قريبًا ✨');

  Future<void> _confirmResetData() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kCard,
        surfaceTintColor: Colors.transparent,
        title: const Text('Reset Data?', style: TextStyle(color: kText)),
        content: const Text(
          'سيتم حذف جميع الفواتير والضمانات الخاصة بك. لا يمكن التراجع.',
          style: TextStyle(color: kTextSub),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: kDanger.withOpacity(.12),
              foregroundColor: kDanger,
            ),
            child: const Text('Delete'),
          ),
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
      backgroundColor: kCard,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            ListTile(
              leading: Icon(Icons.email_outlined, color: kText),
              title: Text('Email', style: TextStyle(color: kText)),
              subtitle: Text('support@billwise.app', style: TextStyle(color: kTextSub)),
            ),
            ListTile(
              leading: Icon(Icons.chat_bubble_outline, color: kText),
              title: Text('Feedback', style: TextStyle(color: kText)),
              subtitle: Text('Tell us what to improve', style: TextStyle(color: kTextSub)),
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
        backgroundColor: kCard,
        surfaceTintColor: Colors.transparent,
        title: const Text('Help & FAQ', style: TextStyle(color: kText)),
        content: const Text(
          '• أضف فواتيرك وضماناتك لتتبع المواعيد.\n'
              '• استخدم OCR لقراءة البيانات من الفاتورة.\n'
              '• فعّل الإشعارات للتذكير بالاسترجاع أو الضمان.\n'
              '• قريبًا: النسخ الاحتياطي والتصدير.',
          style: TextStyle(color: kTextSub),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _debugDiagnostics() {
    if (kReleaseMode) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        const Text('Diagnostics',
            style: TextStyle(color: kText, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _SettingTile(
          icon: Icons.bug_report_outlined,
          title: 'Test Crash (Crashlytics)',
          subtitle: 'Generate a test crash to verify Crashlytics',
          onTap: () async {
            _toast('Triggering test crash…');
            await Future.delayed(const Duration(milliseconds: 400));
            FirebaseCrashlytics.instance.crash();
          },
          danger: true,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    // 🔥 السويتش حق الثيم
    final appState = App.of(context);
    final bool isDark = appState.themeMode == ThemeMode.dark;

    return AbsorbPointer(
      absorbing: _busy,
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: kBg,
            appBar: AppBar(
              foregroundColor: Colors.white,
              elevation: 0,
              backgroundColor: Colors.transparent,
              title: const Text('Profile'),
              flexibleSpace: Container(decoration: const BoxDecoration(gradient: kHeaderGradient)),
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                // Header
                if (uid == null)
                  _ProfileHeader(
                    displayName: _displayName,
                    email: _email,
                    accountType: _accountType,
                    onEdit: _openEdit,
                    avatarId: null,
                  )
                else
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
                    builder: (context, snap) {
                      final avatarId = snap.data?.data()?['avatar_id'] as String?;
                      return _ProfileHeader(
                        displayName: _displayName,
                        email: _email,
                        accountType: _accountType,
                        onEdit: _openEdit,
                        avatarId: avatarId,
                      );
                    },
                  ),

                const SizedBox(height: 18),
                const Text('Tools',
                    style: TextStyle(color: kText, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),

                // ===== زر تغيير الثيم =====
                _ThemeSwitchTile(
                  value: isDark,
                  onChanged: (val) {
                    appState.setThemeMode(
                      val ? ThemeMode.dark : ThemeMode.light,
                    );
                    setState(() {});
                  },
                ),

                _SettingTile(
                  icon: Icons.cloud_upload_outlined,
                  title: 'Backup',
                  subtitle: 'Save a copy of your data',
                  onTap: _backupComingSoon,
                ),
                _SettingTile(
                  icon: Icons.delete_sweep_outlined,
                  title: 'Reset Data',
                  subtitle: 'Delete all bills & warranties',
                  onTap: _confirmResetData,
                  danger: true,
                ),
                _SettingTile(
                  icon: Icons.chat_bubble_outline,
                  title: 'Contact Us',
                  subtitle: 'Support & feedback',
                  onTap: _contactUs,
                ),
                _SettingTile(
                  icon: Icons.help_outline,
                  title: 'Help / FAQ',
                  subtitle: 'How BillWise works',
                  onTap: _showHelp,
                ),

                // Debug
                _debugDiagnostics(),

                const SizedBox(height: 24),
                const Center(
                  child: Text('BillWise • v1.0.0',
                      style: TextStyle(color: kTextSub, fontSize: 12)),
                ),
              ],
            ),
          ),

          if (_busy)
            Container(
              color: Colors.black26,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(color: kAccent),
            ),
        ],
      ),
    );
  }
}

class _ThemeSwitchTile extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ThemeSwitchTile({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kStroke),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 24, spreadRadius: -18),
        ],
      ),
      child: SwitchListTile(
        title: const Text('Dark Mode',
            style: TextStyle(color: kText, fontWeight: FontWeight.w700)),
        subtitle: Text(
          value ? 'Using dark theme' : 'Using light theme',
          style: const TextStyle(color: kTextSub),
        ),
        activeColor: kAccent,
        inactiveThumbColor: Colors.white,
        inactiveTrackColor: Colors.white30,
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String displayName;
  final String email;
  final String accountType;
  final VoidCallback onEdit;
  final String? avatarId;

  const _ProfileHeader({
    required this.displayName,
    required this.email,
    required this.accountType,
    required this.onEdit,
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
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kStroke),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 24, spreadRadius: -18),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _Avatar(name: displayName, preset: preset),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName,
                    style:
                    const TextStyle(color: kText, fontSize: 18, fontWeight: FontWeight.w700)),
                Text(email, style: const TextStyle(color: kTextSub, fontSize: 13)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: kStroke),
                    gradient: const LinearGradient(
                      colors: [Color(0x1A6A73FF), Color(0x1A000000)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                  ),
                  child: const Text('Basic Account',
                      style: TextStyle(color: kText, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18, color: kText),
            label: const Text('Edit', style: TextStyle(color: kText)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: kStroke),
              backgroundColor: Colors.white.withOpacity(0.02),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final _AvatarPreset? preset;

  const _Avatar({required this.name, this.preset});

  @override
  Widget build(BuildContext context) {
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
          border: Border.all(color: kStroke),
        ),
        alignment: Alignment.center,
        child: Text(preset!.emoji, style: const TextStyle(fontSize: 24)),
      );
    }

    final initials = name.isNotEmpty ? name.characters.first.toUpperCase() : 'U';
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0x22FFFFFF),
        border: Border.all(color: kStroke),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(color: kText, fontSize: 20, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color tint = danger ? kDanger : kAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kStroke),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 24, spreadRadius: -18),
        ],
      ),
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [tint.withOpacity(.18), kBg.withOpacity(.18)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            border: Border.all(color: tint, width: 1.2),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 22, color: tint),
        ),
        title: Text(title, style: const TextStyle(color: kText, fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: const TextStyle(color: kTextSub)),
        trailing: const Icon(Icons.chevron_right, color: kTextSub),
        onTap: onTap,
      ),
    );
  }
}
