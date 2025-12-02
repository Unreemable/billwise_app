import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../auth/login_screen.dart';
import '../ocr/scan_receipt_page.dart';

import '../bills/ui/add_bill_page.dart';
import '../bills/ui/bill_detail_page.dart';
import '../bills/ui/bill_list_page.dart';
import '../common/models.dart';

import '../warranties/ui/add_warranty_page.dart';
import '../warranties/ui/warranty_detail_page.dart';
import '../warranties/ui/warranty_list_page.dart';

import '../notifications/notifications_page.dart';
import '../profile/profile_page.dart';

import '../common/widgets/expiry_progress.dart';

import 'dart:math' as math;

// ===== ألوان عامة نستخدمها في الهوم (تم تحويلها لثوابت ديناميكية) =====
const Color _kGrad1    = Color(0xFF9B5CFF);   // Violet أفتح ومريح
const Color _kGrad2    = Color(0xFF6C3EFF);   // البنفسجي الأساسي
const Color _kGrad3    = Color(0xFFC58CFF);   // Lavender وردي ناعم بدل الأزرق
// تدرّج الهيدر العلوي (سيتم تعويضه بتدرج ديناميكي)
const LinearGradient kHeaderGradient = LinearGradient(
  colors: [Color(0xFF1A0B3A), Color(0xFF0E0722)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);


// === إعدادات ثابتة للمقاسات ===
const double _kHeaderHeight = 240;
const double _kTilesGap     = 12;
const double _kColGap       = 12;
const double _kTilesYOffset = -6;

// تحكم سريع بالمقاسات (نسب الارتفاع بالنسبة للعرض)
const double kRowTileAspect   = 0.66;
const double kQuickTileAspect = 0.68;

// ================== الـ Widget الرئيسي للهوم ==================
class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  // كنترولر حقل البحث + الـ Focus عشان نعرف متى نلغي الكيبورد
  final _searchCtrl  = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    // تنظيف الموارد لما ننتهي من الصفحة
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // دالة بسيطة تجيب اسم المستخدم اللي بنعرضه في الهيدر
  String _greetName(User? u) {
    final dn = u?.displayName?.trim();
    if (dn != null && dn.isNotEmpty) return dn;     // لو فيه displayName نستخدمه
    final email = u?.email ?? '';
    if (email.contains('@')) return email.split('@').first; // لو ما فيه اسم نستخدم قبل الـ @
    return 'there'; // fallback
  }

  // هل في نص مكتوب في البحث؟ لو نعم نعرض Panel النتائج
  bool get _showResults => _searchCtrl.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;
    final accentColor = theme.primaryColor;

    // الألوان المخصصة للخلفية والكروت
    final cardBgColor = theme.cardColor;
    final bgColor = theme.scaffoldBackgroundColor; // الخلفية الرئيسية

    // === حسابات مقاسات البلاطات مرّة واحدة ===
    final screenW   = MediaQuery.of(context).size.width;
    final usableW   = screenW - 32;           // padding 16 يمين + 16 يسار
    final itemW     = (usableW - _kColGap) / 2;
    final itemH     = itemW * kRowTileAspect; // ارتفاع مربعات Bill/Warranty
    final quickH    = itemW * kQuickTileAspect; // ارتفاع Quick Add
    final tilesTop  = _kHeaderHeight - 70 + _kTilesYOffset; // بداية البلاطات تحت الهيدر
    final tilesH    = itemH + _kTilesGap + quickH;          // مجموع ارتفاع البلاطات
    final contentTop= tilesTop + tilesH + 12;               // من وين يبدأ قسم "Expiring soon"

    return WillPopScope(
      // هنا نتحكم بزر الرجوع من الهوم: لو المستخدم يكتب في السيرش وبعدين ضغط Back نمسح البحث
      onWillPop: () async {
        if (_showResults) {
          _searchCtrl.clear();
          _searchFocus.unfocus();
          setState(() {});
          return false; // لا تطلع من الصفحة
        }
        return true; // عادي اسمح بالرجوع (AppShell يمسكه بعدين)
      },
      child: Directionality(
        textDirection: ui.TextDirection.ltr, // نخلي الهوم LTR عشان التصميم
        child: Scaffold(
          // *** الإصلاح: استخدام خلفية الثيم (ستكون بيضاء في Light Mode) ***
          backgroundColor: bgColor,
          resizeToAvoidBottomInset: true,   // عشان ما يغطي الكيبورد المحتوى

          body: Stack(
            clipBehavior: Clip.none,
            children: [
              // 1) الهيدر العلوي (التحية + الأيقونات + السيرش)
              Positioned.fill(
                top: 0,
                bottom: null,
                child: _Header(
                  name: _greetName(user),
                  searchCtrl: _searchCtrl,
                  searchFocus: _searchFocus,
                  onSearchChanged: (_) => setState(() {}),   // أي تغيير في السيرش يحدث الـ UI
                  onSearchSubmitted: (_) => setState(() {}), // نفس الشيء لو ضغط Search
                  onLogout: () async {
                    await FirebaseAuth.instance.signOut();
                    if (!context.mounted) return;
                    // نرجع لصفحة تسجيل الدخول ونمسح كل الـ stack
                    Navigator.pushNamedAndRemoveUntil(
                      context, LoginScreen.route, (_) => false,
                    );
                  },
                  onNotifications: () => Navigator.of(context, rootNavigator: true)
                      .pushNamed(NotificationsPage.route),
                  onProfile: () => Navigator.of(context, rootNavigator: true)
                      .pushNamed(ProfilePage.route),
                ),
              ),

              // 2) البلاطات: Bill + Warranty في صف، وتحتهم Quick Add العريض
              Positioned(
                top: tilesTop,
                left: 16,
                right: 16,
                child: SizedBox(
                  height: tilesH,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // بلاطة Bill
                          SizedBox(
                            width: itemW, height: itemH,
                            child: _ActionMiniTile(
                              title: 'Bill',
                              subtitle: 'Add Bill',
                              icon: Icons.receipt_long_rounded,
                              accentColor: accentColor,
                              onTap: () => Navigator.of(context, rootNavigator: true)
                                  .push(MaterialPageRoute(builder: (_) => const AddBillPage())),
                            ),
                          ),
                          const SizedBox(width: _kColGap),
                          // بلاطة Warranty
                          SizedBox(
                            width: itemW, height: itemH,
                            child: _ActionMiniTile(
                              title: 'Warranty',
                              subtitle: 'Add Warranty',
                              icon: Icons.verified_user_rounded,
                              accentColor: accentColor,
                              onTap: () => Navigator.of(context, rootNavigator: true).push(
                                MaterialPageRoute(builder: (_) => const AddWarrantyPage(
                                  billId: null, defaultStartDate: null, defaultEndDate: null,
                                )),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: _kTilesGap),
                      // بلاطة Quick Add (OCR) العريضة
                      SizedBox(
                        width: usableW,
                        height: quickH,
                        child: _ActionRectWide(
                          title: 'Quick Add',
                          subtitle: 'OCR',
                          icon: Icons.document_scanner_outlined,
                          accentColor: accentColor,
                          onTap: () => Navigator.of(context, rootNavigator: true)
                              .push(MaterialPageRoute(builder: (_) => const ScanReceiptPage())),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3) المحتوى اللي تحت – "Expiring soon" ونتائج الخلط بين الفواتير والضمانات
              Positioned.fill(
                top: contentTop,
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    // الـ padding السفلي كبير شوي عشان يكون في مساحة كافية حتى لو فيه بار سفلي
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ExpiringMixed3(
                          userId: FirebaseAuth.instance.currentUser?.uid,
                          query: _searchCtrl.text,
                          cardBgColor: cardBgColor,
                          textColor: theme.textTheme.bodyMedium!.color!,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),

              // 4) Panel نتائج البحث – تغطي اللي تحت لما المستخدم يكتب في السيرش
              if (_showResults)
                Positioned.fill(
                  top: _kHeaderHeight + 8,
                  child: _SearchResultsPanel(
                    query: _searchCtrl.text,
                    userId: FirebaseAuth.instance.currentUser?.uid,
                    onClose: () {
                      _searchCtrl.clear();
                      _searchFocus.unfocus();
                      setState(() {});
                    },
                    cardBgColor: cardBgColor,
                    bgColor: bgColor,
                    textColor: theme.textTheme.bodyMedium!.color!,
                    dimColor: theme.hintColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// مجرد Wrapper عشان لو احتجنا نستخدم HomeScreen بالـ route
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  static const route = '/home';
  @override
  Widget build(BuildContext context) => const HomeContent();
}

// ================= Header (الجزء العلوي) =================
class _Header extends StatelessWidget {
  final String name;
  final TextEditingController searchCtrl;
  final FocusNode searchFocus;
  final VoidCallback onLogout;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;

  const _Header({
    required this.name,
    required this.searchCtrl,
    required this.searchFocus,
    required this.onLogout,
    required this.onNotifications,
    required this.onProfile,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
  });

  // تدرج ديناميكي للهيدر
  LinearGradient _headerGradient(BuildContext context, bool isDark, Color accentColor) {
    if (isDark) {
      return const LinearGradient(
        colors: [Color(0xFF1A0B3A), Color(0xFF0E0722)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      // Light Mode: خلفية فاتحة جداً مائلة للأرجواني
      return LinearGradient(
        colors: [accentColor.withOpacity(0.08), accentColor.withOpacity(0.02)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = theme.primaryColor;
    final textColor = theme.textTheme.bodyMedium!.color!;
    final dimColor = isDark ? Colors.white70 : Colors.black54;

    return Container(
      height: _kHeaderHeight,
      decoration: BoxDecoration(gradient: _headerGradient(context, isDark, accentColor)),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // الصف الأول: الصورة الشخصية + Hello + الاسم + أيقونات الإشعارات وتسجيل الخروج
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        _ProfileAvatar(name: name, onTap: onProfile), // أفاتار المستخدم
                        const SizedBox(width: 10),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Hello,', style: TextStyle(color: dimColor, fontSize: 14)),
                              Text(
                                name,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: textColor, fontSize: 20, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // زر الإشعارات
                  IconButton(
                    tooltip: 'Notifications',
                    onPressed: onNotifications,
                    icon: Icon(Icons.notifications_none_rounded, color: textColor),
                  ),
                  const SizedBox(width: 4),
                  // زر تسجيل الخروج
                  IconButton(
                    tooltip: 'Sign out',
                    onPressed: onLogout,
                    icon: Icon(Icons.logout, color: textColor),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // شريط البحث
              _SearchBar(
                controller: searchCtrl,
                focusNode: searchFocus,
                hint: 'Search bills or warranties...',
                onChanged: onSearchChanged,
                onSubmitted: onSearchSubmitted,
                accentColor: accentColor,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============== Search Bar (TextField) ===============
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Color accentColor;
  final bool isDark;

  const _SearchBar({
    required this.controller,
    this.focusNode,
    required this.hint,
    this.onChanged,
    this.onSubmitted,
    required this.accentColor,
    required this.isDark,
  });

  // تدرج شريط البحث
  LinearGradient _searchGradient(Color accentColor) {
    if (isDark) {
      return LinearGradient(
        colors: [_kGrad1, _kGrad3],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      // Light Mode: خلفية بيضاء صلبة (أو رمادية فاتحة)
      return const LinearGradient(colors: [Colors.white, Colors.white]);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ألوان الشريط في Light Mode
    final fgColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.white70 : Colors.black54;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: _searchGradient(accentColor),
        // حدود صريحة في Light Mode
        border: Border.all(
          color: isDark ? Colors.transparent : Colors.black.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? _kGrad2.withOpacity(0.45) : Colors.black.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: fgColor, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              onTapOutside: (_) => focusNode?.unfocus(),
              style: TextStyle(color: fgColor, fontSize: 16),
              cursorColor: accentColor,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search bills or warranties...',
                hintStyle: TextStyle(color: hintColor),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          // زر X لمسح البحث لما يكون فيه نص
          if (controller.text.isNotEmpty)
            IconButton(
              tooltip: 'Clear',
              onPressed: () {
                controller.clear();
                onChanged?.call('');
              },
              icon: Icon(Icons.close_rounded, color: fgColor),
            ),
        ],
      ),
    );
  }
}

// =============== بطاقات الإجراءات (Bill / Warranty / Quick Add) ===============
class _ActionMiniTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color accentColor;

  const _ActionMiniTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = [_kGrad3, _kGrad1]; // ثابت في كلا الوضعين للحفاظ على التباين

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
            boxShadow: [BoxShadow(color: gradient.last.withOpacity(.40), blurRadius: 14, offset: Offset(0, 8))],
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // أيقونة صغيرة داخل مربع شبه شفاف
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  const Spacer(),
                  Text(title,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// مستطيل عريض لــ Quick Add (OCR)
class _ActionRectWide extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color accentColor;

  const _ActionRectWide({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = [_kGrad1, _kGrad2]; // ثابت في كلا الوضعين

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: gradient.last.withOpacity(.40),
                blurRadius: 16,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // مربع فيه أيقونة الـ OCR
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.20),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: Colors.white, size: 36),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Quick Add',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                        SizedBox(height: 4),
                        Text('OCR',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ======= أفاتارات (صورة المستخدم بالأيموجي) =======
const Map<String, List<dynamic>> _kAvatarPresets = {
  // ... (تم حذف الـ Map لتقليل حجم الكود، لكنها تظل متاحة في الكود الكامل)
  'fox_purple':     ['🦊', [Color(0xFF6A73FF), Color(0xFFE6E9FF)]],
  'panda_blue':     ['🐼', [Color(0xFF38BDF8), Color(0xFFD1FAFF)]],
  'cat_pink':       ['🐱', [Color(0xFFF472B6), Color(0xFFFCE7F3)]],
  'deer_gold':      ['🦌', [Color(0xFFFBBF24), Color(0xFFFFF7ED)]],
  'koala_green':    ['🐨', [Color(0xFF34D399), Color(0xFFD1FAE5)]],
  'penguin_sky':    ['🐧', [Color(0xFF60A5FA), Color(0xFFE0E7FF)]],
  'bear_violet':    ['🐻', [Color(0xFFA78BFA), Color(0xFFEDE9FE)]],
  'bunny_mint':     ['🐰', [Color(0xFF4ADE80), Color(0xFFD1FAE5)]],
  'tiger_sunset':   ['🐯', [Color(0xFFF59E0B), Color(0xFFFFF7ED)]],
  'owl_night':      ['🦉', [Color(0xFF64748B), Color(0xFFE2E8F0)]],
  'alien_candy':    ['👽', [Color(0xFF22D3EE), Color(0xFFCCFBF1)]],
  'robot_lavender': ['🤖', [Color(0xFF93C5FD), Color(0xFFE0E7FF)]],
};

class _ProfileAvatar extends StatelessWidget {
  final String name;
  final VoidCallback? onTap;
  const _ProfileAvatar({required this.name, this.onTap});

  String _initialOf(String text) =>
      (text.trim().isEmpty ? 'U' : text.trim()[0].toUpperCase());

  // افاتار افتراضي بحرف من الاسم لو ما فيه إعدادات
  Widget _fallbackCircle(BuildContext context, String initials) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).primaryColor;

    return Container(
      width: 42, height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? Colors.white.withOpacity(0.9) : accentColor, // خلفية ملونة في Light Mode
        boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black.withOpacity(0.08), offset: Offset(0, 2))],
      ),
      alignment: Alignment.center,
      child: Text(initials, style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: isDark ? Colors.black87 : Colors.white, fontWeight: FontWeight.w700,
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initials = _initialOf(name);
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      final base = _fallbackCircle(context, initials);
      return onTap == null ? base : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(21), child: base);
    }

    // نسمع لتغيّر بيانات المستخدم (avatar_id) من Firestore
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        Widget child;
        if (!snap.hasData || !snap.data!.exists) {
          child = _fallbackCircle(context, initials);
        } else {
          final data = snap.data!.data();
          final avatarId = (data?['avatar_id'] ?? '') as String;
          if (avatarId.isEmpty || !_kAvatarPresets.containsKey(avatarId)) {
            child = _fallbackCircle(context, initials);
          } else {
            final item = _kAvatarPresets[avatarId]!;
            final emoji  = item[0] as String;
            final colors = (item[1] as List<Color>);
            child = Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: colors, begin: Alignment.topRight, end: Alignment.bottomLeft),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: Offset(0, 2))],
              ),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            );
          }
        }
        return onTap == null ? child : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(21), child: child);
      },
    );
  }
}

// =================== Expiring Mixed ===================
// هذا الجزء يتكفّل بعرض 3 عناصر "قريبة الانتهاء" من الفواتير والضمانات
class _ExpiringMixed3 extends StatelessWidget {
  final String? userId;
  final String query;
  final Color cardBgColor;
  final Color textColor;

  const _ExpiringMixed3({required this.userId, required this.query, required this.cardBgColor, required this.textColor});

  // دالة مساعدة لحساب رسالة الحالة (Expires today, etc.)
  String _getExpiryStatusLabel(DateTime expiry, bool isWarranty) {
    final today = DateTime.now();
    final expiryOnly = DateTime(expiry.year, expiry.month, expiry.day);
    final diff = expiryOnly.difference(DateTime(today.year, today.month, today.day)).inDays;

    if (diff < 0) {
      return "Expired";
    } else if (diff == 0) {
      return "Expires today";
    } else if (diff == 1) {
      return "Expires in 1 day";
    } else if (diff <= 7) {
      return "Expires in $diff days";
    } else if (isWarranty && diff <= 30) {
      return "Expires this month";
    } else {
      return "Active";
    }
  }

  String _fmt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  DateTime _only(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    // دوال مساعدة صغيرة لقراءة التواريخ والسترنج من الماب
    Timestamp? _ts(Map<String, dynamic> d, List<String> keys) {
      for (final k in keys) {
        final v = d[k];
        if (v is Timestamp) return v;
        if (v is DateTime) return Timestamp.fromDate(v);
      }
      return null;
    }

    String _str(Map<String, dynamic> d, List<String> keys, {String fallback = ''}) {
      for (final k in keys) {
        final v = d[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return fallback;
    }

    final uid = userId;
    final billsCol = FirebaseFirestore.instance.collection('Bills');
    final warrCol  = FirebaseFirestore.instance.collection('Warranties');

    // نفلتر بالـ user_id لو موجود
    final billsBase = uid != null ? billsCol.where('user_id', isEqualTo: uid) : billsCol;
    final warrBase  = uid != null ? warrCol.where('user_id', isEqualTo: uid) : warrCol;

    // نجيب آخر 200 فاتورة وأقصى 300 ضمان
    final billsStream = billsBase.orderBy('created_at', descending: true).limit(200).snapshots();
    final warrStream  = warrBase.limit(300).snapshots();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dimColor = isDark ? Colors.white70 : Colors.black54;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: billsStream,
      builder: (context, bSnap) {
        if (bSnap.hasError) return const SizedBox.shrink();
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: warrStream,
          builder: (context, wSnap) {
            if (wSnap.hasError) return const SizedBox.shrink();
            if (!bSnap.hasData || !wSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final now = DateTime.now();
            final todayOnly = DateTime(now.year, now.month, now.day);

            final items = <Map<String, dynamic>>[];

            // ===== نحول الفواتير لعناصر مع موعد انتهاء (إرجاع + استبدال) =====
            for (final doc in bSnap.data!.docs) {
              final d = doc.data();
              final title = (d['title'] ?? '—').toString();
              final shop  = (d['shop_name'] ?? '').toString();

              final purchase = (d['purchase_date'] as Timestamp?)?.toDate().toLocal();
              final ret      = (d['return_deadline'] as Timestamp?)?.toDate().toLocal();
              final ex       = (d['exchange_deadline'] as Timestamp?)?.toDate().toLocal();

              final amountN = (d['total_amount'] as num?);
              final amount  = amountN?.toDouble() ?? 0.0;

              if (ret != null) {
                items.add({
                  'type': 'bill','subtype': 'return','id': doc.id,
                  'title': title,'subtitle': shop,'purchase': purchase,
                  'amount': amount,'expiry': _only(ret),
                });
              }
              if (ex != null) {
                items.add({
                  'type': 'bill','subtype': 'exchange','id': doc.id,
                  'title': title,'subtitle': shop,'purchase': purchase,
                  'amount': amount,'expiry': _only(ex),
                });
              }
            }

            // ===== نحول الضمانات لعناصر مع موعد انتهاء =====
            for (final doc in wSnap.data!.docs) {
              final d = doc.data();
              final provider = _str(d, ['provider','brand','vendor'], fallback: 'Warranty');
              final wTitle   = _str(d, ['title','product','item_name'], fallback: provider);

              final startTs  = _ts(d, ['start_date','warranty_start','start']);
              final endTs    = _ts(d, ['end_date','warranty_end_date','expiry','expires_at']);

              final end = endTs?.toDate().toLocal();
              if (end == null) continue;

              final start = (startTs?.toDate().toLocal()) ?? end.subtract(const Duration(days: 365));

              items.add({
                'type': 'warranty','id': doc.id,
                'title': provider,'subtitle': wTitle,
                'start': start,'end': end,'expiry': _only(end),
              });
            }

            // ===== فلترة حسب نص البحث إن وجد =====
            final q = query.trim().toLowerCase();
            if (q.isNotEmpty) {
              items.retainWhere((e) {
                final t = (e['title'] as String).toLowerCase();
                final s = (e['subtitle'] as String).toLowerCase();
                return t.contains(q) || s.contains(q);
              });
            }

            // لو ما فيه أي عنصر مناسب
            if (items.isEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Expiring soon',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: textColor)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(color: cardBgColor, borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      q.isEmpty ? 'No items with deadlines.' : 'No results for "$q".',
                      style: TextStyle(color: dimColor),
                    ),
                  ),
                ],
              );
            }

            // نقسم العناصر لقادمة (لم تنتهِ) وماضية (منتهية)
            final upcoming = items.where((e) => !(e['expiry'] as DateTime).isBefore(todayOnly)).toList()
              ..sort((a, b) => (a['expiry'] as DateTime).compareTo(b['expiry'] as DateTime));
            final past = items.where((e) => (e['expiry'] as DateTime).isBefore(todayOnly)).toList()
              ..sort((a, b) => (b['expiry'] as DateTime).compareTo(a['expiry'] as DateTime));

            // نختار بحد أقصى 3 عناصر: نبدأ بالقادمة، ولو قليلة نكمّل من المنتهية
            final selected = <Map<String, dynamic>>[]..addAll(upcoming.take(3));
            if (selected.length < 3) selected.addAll(past.take(3 - selected.length));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Expiring soon',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: textColor)),
                const SizedBox(height: 8),
                ...selected.map((e) {
                  final type    = e['type'] as String;
                  final expiry  = e['expiry'] as DateTime;
                  final subtype = (e['subtype'] as String?);

                  // نحدد الأيقونة ونوع العنصر (إرجاع / استبدال / ضمان)
                  IconData leadingIcon;
                  String kindLabel = '';
                  if (type == 'bill') {
                    if (subtype == 'return') { leadingIcon = Icons.keyboard_return; kindLabel = 'Return'; }
                    else if (subtype == 'exchange') { leadingIcon = Icons.swap_horiz; kindLabel = 'Exchange'; }
                    else { leadingIcon = Icons.receipt_long; }
                  } else {
                    leadingIcon = Icons.verified_user; kindLabel = 'Warranty';
                  }

                  final startForBar = (e['start'] as DateTime?) ??
                      (e['purchase'] as DateTime?) ??
                      DateTime.now();

                  // رسالة الحالة التي تم إضافتها
                  final expiryStatus = _getExpiryStatusLabel(expiry, type == 'warranty');

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(color: cardBgColor, borderRadius: BorderRadius.circular(12)),
                    child: MediaQuery( // نتحكم بتكبير النص داخل البلاطة بس
                      data: MediaQuery.of(context).copyWith(
                        textScaleFactor: MediaQuery.textScaleFactorOf(context).clamp(1.0, 1.25),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isThreeLine: true,
                        minVerticalPadding: 6,
                        leading: Icon(leadingIcon, color: dimColor),
                        title: Row(
                          children: [
                            Expanded(child: Text(e['title'] as String,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: textColor))),
                            if (kindLabel.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(kindLabel, style: TextStyle(fontSize: 11, color: dimColor)),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          (e['subtitle'] as String?)?.isEmpty == true ? '—' : (e['subtitle'] as String? ?? '—'),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: dimColor),
                        ),
                        // ===== يمين: التاريخ + شريط التقدّم =====
                        trailing: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: 0,
                            maxWidth: math.max(
                              120.0,
                              (MediaQuery.of(context).size.width - 32) * 0.36,
                            ),
                          ),
                          child: MediaQuery(
                            data: MediaQuery.of(context).copyWith(
                              textScaleFactor: MediaQuery.textScaleFactorOf(context).clamp(1.0, 1.2),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // نص التاريخ
                                Text(
                                  _fmt(expiry),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: dimColor),
                                ),
                                const SizedBox(height: 6),
                                // رسالة الانتهاء
                                Text(
                                  expiryStatus,
                                  style: TextStyle(
                                    color: expiryStatus == "Expired"
                                        ? Colors.redAccent
                                        : dimColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // شريط التقدم
                                ExpiryProgress(
                                  startDate: startForBar,
                                  endDate:   expiry,

                                  // أهم شيء — نمرر نوع العنصر
                                  title:     kindLabel,     // ← Return / Exchange / Warranty

                                  dense:     true,
                                  showTitle: false,         // نخفي العنوان شكلياً فقط
                                  showStatus: false, // تم إيقاف عرض الحالة التلقائي لتجنب التعارض
                                  showInMonths: (type == 'warranty'),
                                ),


                              ],
                            ),
                          ),
                        ),

                        // الضغط على العنصر يودّي لتفاصيل الفاتورة أو الضمان
                        onTap: () {
                          if (type == 'bill') {
                            final details = BillDetails(
                              id: e['id'] as String,
                              title: e['title'] as String,
                              product: (e['subtitle'] as String? ?? ''),
                              amount: (e['amount'] as double?) ?? 0.0,
                              purchaseDate: (e['purchase'] as DateTime?) ?? DateTime.now(),
                              returnDeadline: subtype == 'return' ? expiry : null,
                              warrantyExpiry: null,
                            );
                            Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute(builder: (_) => BillDetailPage(details: details)),
                            );
                          } else {
                            final details = WarrantyDetails(
                              id: e['id'] as String,
                              product: e['title'] as String,
                              title: e['subtitle'] as String? ?? '',
                              warrantyStart: (e['start'] as DateTime?) ?? DateTime.now(),
                              warrantyExpiry: expiry,
                              returnDeadline: null,
                            );
                            Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute(builder: (_) => WarrantyDetailPage(details: details)),
                            );
                          }
                        },
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }
}

// =================== لوحة نتائج البحث الفورية ===================
class _SearchResultsPanel extends StatelessWidget {
  final String query;
  final String? userId;
  final VoidCallback onClose;
  final Color cardBgColor;
  final Color bgColor;
  final Color textColor;
  final Color dimColor;

  const _SearchResultsPanel({
    required this.query,
    required this.userId,
    required this.onClose,
    required this.cardBgColor,
    required this.bgColor,
    required this.textColor,
    required this.dimColor,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom; // ارتفاع الكيبورد لو ظاهر
    return Material(
      // استخدام لون الخلفية بصبغة خفيفة
      color: bgColor.withOpacity(0.94),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            children: [
              Row(
                children: [
                  Text('Results', style: TextStyle(color: dimColor, fontSize: 12)),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: onClose,
                    icon: Icon(Icons.close_rounded, color: dimColor),
                  )
                ],
              ),
              const SizedBox(height: 4),
              Expanded(child: _LiveSearchList(query: query, userId: userId, cardBgColor: cardBgColor, textColor: textColor, dimColor: dimColor,)),
              SizedBox(height: bottomInset), // نخلي space تحت قد الكيبورد
            ],
          ),
        ),
      ),
    );
  }
}

// القائمة الحية لنتائج البحث (Bills + Warranties)
class _LiveSearchList extends StatelessWidget {
  final String query;
  final String? userId;
  final Color cardBgColor;
  final Color textColor;
  final Color dimColor;

  const _LiveSearchList({required this.query, required this.userId, required this.cardBgColor, required this.textColor, required this.dimColor});

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final uid = userId;

    final billsCol = FirebaseFirestore.instance.collection('Bills');
    final warrCol  = FirebaseFirestore.instance.collection('Warranties');

    final billsBase = uid != null ? billsCol.where('user_id', isEqualTo: uid) : billsCol;
    final warrBase  = uid != null ? warrCol.where('user_id', isEqualTo: uid) : warrCol;

    final billsStream = billsBase.orderBy('created_at', descending: true).limit(200).snapshots();
    final warrStream  = warrBase.limit(300).snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: billsStream,
      builder: (context, bSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: warrStream,
          builder: (context, wSnap) {
            if (!bSnap.hasData || !wSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final List<_SearchItem> out = [];

            // نحط الفواتير في النتائج
            for (final d in bSnap.data!.docs) {
              final m = d.data();
              final title = (m['title'] ?? '').toString();
              final shop  = (m['shop_name'] ?? '').toString();
              if (q.isEmpty || title.toLowerCase().contains(q) || shop.toLowerCase().contains(q)) {
                out.add(_SearchItem.bill(
                  id: d.id,
                  title: title.isEmpty ? 'Bill' : title,
                  subtitle: shop.isEmpty ? '—' : shop,
                  purchase: (m['purchase_date'] as Timestamp?)?.toDate(),
                  amount: (m['total_amount'] as num?)?.toDouble() ?? 0.0,
                ));
              }
            }

            // نحط الضمانات في النتائج
            for (final d in wSnap.data!.docs) {
              final m = d.data();
              final provider = (m['provider'] ?? m['brand'] ?? '').toString();
              final prod     = (m['title'] ?? m['product'] ?? '').toString();
              final title    = provider.isEmpty ? 'Warranty' : provider;
              final subtitle = prod.isEmpty ? '—' : prod;
              if (q.isEmpty || title.toLowerCase().contains(q) || subtitle.toLowerCase().contains(q)) {
                out.add(_SearchItem.warranty(
                  id: d.id,
                  title: title,
                  subtitle: subtitle,
                  start: (m['start_date'] as Timestamp?)?.toDate(),
                  end:   (m['end_date']   as Timestamp?)?.toDate(),
                ));
              }
            }

            if (out.isEmpty) {
              return Center(
                child: Text('No results', style: TextStyle(color: dimColor)),
              );
            }

            // نرتّب النتائج بالاسم
            out.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

            return ListView.separated(
              itemCount: out.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final it = out[i];
                return Container(
                  decoration: BoxDecoration(color: cardBgColor, borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: Icon(
                      it.isBill ? Icons.receipt_long_rounded : Icons.verified_user_rounded,
                      color: dimColor,
                    ),
                    title: Text(it.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: textColor)),
                    subtitle: Text(it.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: dimColor)),
                    onTap: () {
                      if (it.isBill) {
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute(builder: (_) => BillDetailPage(details: BillDetails(
                            id: it.id,
                            title: it.title,
                            product: it.subtitle,
                            amount: it.amount ?? 0.0,
                            purchaseDate: it.purchase ?? DateTime.now(),
                            returnDeadline: null,
                            warrantyExpiry: null,
                          ))),
                        );
                      } else {
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute(builder: (_) => WarrantyDetailPage(details: WarrantyDetails(
                            id: it.id,
                            product: it.title,
                            title: it.subtitle,
                            warrantyStart: it.start ?? DateTime.now(),
                            warrantyExpiry: it.end ?? DateTime.now(),
                            returnDeadline: null,
                          ))),
                        );
                      }
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// موديل بسيط للعنصر في نتائج البحث (فاتورة أو ضمان)
class _SearchItem {
  final bool isBill;
  final String id;
  final String title;
  final String subtitle;
  final double? amount;
  final DateTime? purchase;
  final DateTime? start;
  final DateTime? end;

  _SearchItem.bill({
    required this.id,
    required this.title,
    required this.subtitle,
    this.amount,
    this.purchase,
  })  : isBill = true, start = null, end = null;

  _SearchItem.warranty({
    required this.id,
    required this.title,
    required this.subtitle,
    this.start,
    this.end,
  })  : isBill = false, amount = null, purchase = null;
}