import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../common/models.dart';
import '../bills/ui/bill_detail_page.dart';
import '../warranties/ui/warranty_detail_page.dart';
import 'notifications_service.dart';

/// صفحة "الإشعارات داخل التطبيق"
/// ما تجيب إشعارات FCM، بل تبني ف feed من الفواتير والضمانات بناءً على تواريخها.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  static const route = '/notifications';

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  // فورمات التاريخ الأساسي (نستخدمه في نص الموعد)
  final _fmtDate = DateFormat('yyyy-MM-dd');

  // فورمات الشريحة الصغيرة اللي فيها اليوم + الوقت
  final _fmtChip = DateFormat('MMM d, HH:mm');

  bool _loading = true;

  // القوائم الثلاث (اليوم - قادمة - منتهية)
  List<_NotifFeedItem> _today = [];
  List<_NotifFeedItem> _upcoming = [];
  List<_NotifFeedItem> _missed = [];

  // مجموعة مفاتيح الإشعارات اللي المستخدم حذفها نهائياً (من السحابة)
  // (هنا بس نقرأها، ما فيه منطق حذف حاليًا)
  final Set<String> _dismissed = {};

  // ألوان وهوية الصفحة
  static const _kPrimary = Color(0xFF5B6BFF);
  static const _kHeaderGrad = LinearGradient(
    colors: [Color(0xFF1B0B66), Color(0xFF0B0425)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // أسهل طريقة تجيب uid للمستخدم الحالي
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ===== دوال مساعدة على التواريخ =====

  /// ترجع نفس التاريخ لكن مضبوطة على الساعة 00:00 (نستخدمها عشان نقارن بالأيام مو بالساعات)
  DateTime _atMidnight(DateTime x) => DateTime(x.year, x.month, x.day, 0, 0);

  /// تتحقق إذا t موجود بين start و end بشكل شامل (>=start و <=end)
  bool _inInclusive(DateTime t, DateTime start, DateTime end) =>
      (t.isAfter(start) || t.isAtSameMomentAs(start)) &&
          (t.isBefore(end) || t.isAtSameMomentAs(end));

  /// تحاول تفهم أي نوع تاريخ (Timestamp / int / String / DateTime)
  /// وترجعه كـ DateTime. لو ما قدرت ترجعه => null
  DateTime? _parseAnyDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(v);
      } catch (_) {}
    }
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return null;
      // نحاول parse فورمات ISO مثل 2025-11-19T00:00:00
      try {
        return DateTime.parse(s);
      } catch (_) {}
      // نحاول فورمات محدد yyyy-MM-dd
      try {
        final p = DateFormat('yyyy-MM-dd').parseStrict(s);
        return DateTime(p.year, p.month, p.day);
      } catch (_) {}
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    // أول ما تفتح الصفحة نحمّل الداتا من Firestore
    _load();
  }

  /// الدالة الأساسية اللي:
  /// 1) تجيب الفواتير والضمانات من Firestore
  /// 2) تبني منها NotifFeedItem
  /// 3) تقسّمها إلى: اليوم / قادمة / منتهية
  Future<void> _load() async {
    try {
      final uid = _uid;
      if (uid == null) {
        // ما فيه مستخدم مسجّل
        setState(() => _loading = false);
        return;
      }

      // نحمّل أولاً الإشعارات اللي سبق حذفها (من السحابة)
      await _loadDismissedFromCloud(uid);

      final now = DateTime.now();

      // نافذة زمنية واسعة لعرض الأحداث:
      // من 90 يوم قبل اليوم إلى سنة قدّام
      final startWindow = now.subtract(const Duration(days: 90));
      final endWindow = now.add(const Duration(days: 365));

      final items = <_NotifFeedItem>[];

      // ===== 1) الفواتير Bills =====
      final billsSnap = await FirebaseFirestore.instance
          .collection('Bills')
          .where('user_id', isEqualTo: uid)
          .get();

      for (final doc in billsSnap.docs) {
        final d = doc.data();

        // عنوان الفاتورة، ولو فاضي نخليه "Bill"
        final title = (d['title'] ?? 'Bill').toString().trim().isEmpty
            ? 'Bill'
            : (d['title'] as String).trim();

        // اسم المحل (ما نعرضه هنا كلابل، بس ممكن تستخدمينه لاحقًا)
        final shop = (d['shop_name'] ?? '').toString().trim();
        final label = shop.isEmpty ? title : title;

        // تاريخ آخر يوم استرجاع
        final ret = _parseAnyDate(d['return_deadline']);
        if (ret != null) {
          final r0 = _atMidnight(ret);
          if (_inInclusive(r0, startWindow, endWindow)) {
            items.add(
              _NotifFeedItem(
                when: r0,
                title: label,
                deadlineText: 'Return deadline: ${_fmtDate.format(r0)}',
                kind: _NotifKind.returnDeadline,
                billId: doc.id,
                billData: d,
              ),
            );
          }
        }

        // تاريخ آخر يوم استبدال
        final ex = _parseAnyDate(d['exchange_deadline']);
        if (ex != null) {
          final e0 = _atMidnight(ex);
          if (_inInclusive(e0, startWindow, endWindow)) {
            items.add(
              _NotifFeedItem(
                when: e0,
                title: label,
                deadlineText: 'Exchange deadline: ${_fmtDate.format(e0)}',
                kind: _NotifKind.exchangeDeadline,
                billId: doc.id,
                billData: d,
              ),
            );
          }
        }
      }

      // ===== 2) الضمانات Warranties =====
      final warrSnap = await FirebaseFirestore.instance
          .collection('Warranties')
          .where('user_id', isEqualTo: uid)
          .get();

      for (final doc in warrSnap.docs) {
        final d = doc.data();

        // نحاول نطلع اسم مناسب للضمان (براند / مزوّد / بائع... إلخ)
        final providerRaw =
        (d['provider'] ?? d['brand'] ?? d['vendor'] ?? '').toString();
        final provider =
        providerRaw.trim().isEmpty ? 'Warranty' : providerRaw.trim();

        // تواريخ نهاية الضمان (ندور في أكثر من حقل محتمل)
        final end = _parseAnyDate(
          d['end_date'] ??
              d['warranty_end_date'] ??
              d['expiry'] ??
              d['expires_at'],
        );
        if (end != null) {
          final w0 = _atMidnight(end);
          if (_inInclusive(w0, startWindow, endWindow)) {
            items.add(
              _NotifFeedItem(
                when: w0,
                title: provider,
                deadlineText: 'Warranty ends: ${_fmtDate.format(w0)}',
                kind: _NotifKind.warrantyDeadline,
                warrantyId: doc.id,
                warrantyData: d,
              ),
            );
          }
        }
      }

      // ===== تقسيم الإشعارات بناءً على اليوم =====
      final startToday = DateTime(now.year, now.month, now.day);
      final endToday = startToday.add(const Duration(days: 1));

      final today = <_NotifFeedItem>[];
      final upcoming = <_NotifFeedItem>[];
      final missed = <_NotifFeedItem>[];

      for (final it in items) {
        // لو هذا الإشعار موجود في dismissed نتجاهله
        if (_dismissed.contains(it.key)) continue;

        if (it.when.isBefore(startToday)) {
          // التاريخ قبل اليوم => منتهية
          missed.add(it);
        } else if (it.when.isBefore(endToday)) {
          // التاريخ ضمن اليوم الحالي
          today.add(it);
        } else {
          // التاريخ بعد اليوم الحالي => قادمة
          upcoming.add(it);
        }
      }

      // ترتيب: اليوم / القادمة تصاعدي، المنتهية تنازلي (الأحدث أول)
      today.sort((a, b) => a.when.compareTo(b.when));
      upcoming.sort((a, b) => a.when.compareTo(b.when));
      missed.sort((a, b) => b.when.compareTo(a.when));

      if (!mounted) return;
      setState(() {
        _today = today;
        _upcoming = upcoming;
        _missed = missed;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load notifications: $e')),
      );
    }
  }

  /// تجيب من Firestore قائمة الإشعارات اللي سبق حذفها نهائيًا من المستخدم
  /// (users/{uid}/dismissedNotifs/*)
  Future<void> _loadDismissedFromCloud(String uid) async {
    _dismissed.clear();
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('dismissedNotifs')
        .get();
    for (final d in snap.docs) {
      _dismissed.add(d.id);
    }
  }

  /// ترسل إشعار محلي تجريبي (ما له علاقة بالـ FCM)
  Future<void> _sendNow() async {
    await NotificationsService.I.requestPermissions();
    await NotificationsService.I.showNow(
      title: 'BillWise',
      body: 'إشعار تجريبي ⚡',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sent a test notification')),
    );
  }

  // ===== لما المستخدم يضغط على كرت الإشعار =====
  Future<void> _handleTap(_NotifFeedItem item) async {
    // ----- لو الإشعار مرتبط بفاتورة ----- //
    if (item.billId != null) {
      try {
        Map<String, dynamic>? d = item.billData;

        // لو ما عندنا الداتا كاملة، نرجع نقرأ الوثيقة من Firestore
        if (d == null) {
          final snap = await FirebaseFirestore.instance
              .collection('Bills')
              .doc(item.billId!)
              .get();
          if (!snap.exists) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bill not found')),
              );
            }
            return;
          }
          d = snap.data()!;
        }

        // نجهز BillDetails عشان نفتح صفحة تفاصيل الفاتورة
        final title = (d['title'] ?? 'Bill').toString();
        final shop = (d['shop_name'] ?? '').toString();
        final amount = (d['total_amount'] as num?)?.toDouble();
        final purchase =
            (d['purchase_date'] as Timestamp?)?.toDate().toLocal() ??
                DateTime.now();
        final ret =
        (d['return_deadline'] as Timestamp?)?.toDate().toLocal();
        final ex =
        (d['exchange_deadline'] as Timestamp?)?.toDate().toLocal();
        final hasWarranty = (d['warranty_coverage'] as bool?) ?? false;
        final wEnd =
        (d['warranty_end_date'] as Timestamp?)?.toDate().toLocal();

        final billDetails = BillDetails(
          id: item.billId!, // String (غير قابل للـ null)
          title: title,
          product: shop.isEmpty ? null : shop,
          amount: amount,
          purchaseDate: purchase,
          returnDeadline: ret,
          exchangeDeadline: ex,
          hasWarranty: hasWarranty,
          warrantyExpiry: wEnd,
        );

        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BillDetailPage(details: billDetails),
          ),
        );
        return;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to open bill: $e')),
          );
        }
        return;
      }
    }

    // ----- لو الإشعار مرتبط بضمان ----- //
    if (item.warrantyId != null) {
      try {
        Map<String, dynamic>? d = item.warrantyData;

        // لو ما عندنا الداتا كاملة، نرجع نقرأ الوثيقة من Firestore
        if (d == null) {
          final snap = await FirebaseFirestore.instance
              .collection('Warranties')
              .doc(item.warrantyId!)
              .get();
          if (!snap.exists) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Warranty not found')),
              );
            }
            return;
          }
          d = snap.data()!;
        }

        // تجهيز الحقول للنموذج WarrantyDetails

        // اسم مزوّد الضمان / البراند / البائع...
        final providerRaw =
        (d['provider'] ?? d['brand'] ?? d['vendor'] ?? '').toString();
        final provider =
        providerRaw.trim().isEmpty ? 'Warranty' : providerRaw.trim();

        // اسم المنتج
        final productRaw =
        (d['product_name'] ?? d['product'] ?? '').toString().trim();

        // السيريال (ما نستخدمه هنا، لكن لو حبّيتي تضيفينه للنموذج لاحقًا)
        final serialRaw =
        (d['serial_number'] ?? d['serial'] ?? '').toString().trim();

        // بداية الضمان
        final start =
            (d['start_date'] as Timestamp?)?.toDate().toLocal() ??
                (d['warranty_start_date'] as Timestamp?)
                    ?.toDate()
                    .toLocal() ??
                DateTime.now();

        // نهاية الضمان
        final end =
            (d['end_date'] as Timestamp?)?.toDate().toLocal() ??
                (d['warranty_end_date'] as Timestamp?)
                    ?.toDate()
                    .toLocal() ??
                start;

        // 👇 هذا مطابق لتعريف WarrantyDetails اللي عندك في models.dart
        final warrantyDetails = WarrantyDetails(
          id: item.warrantyId!, // String
          title: provider,
          product: productRaw.isEmpty ? '—' : productRaw,
          warrantyStart: start,
          warrantyExpiry: end,
        );

        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WarrantyDetailPage(details: warrantyDetails),
          ),
        );
        return;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to open warranty: $e')),
          );
        }
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: _kHeaderGrad),
        ),
      ),
      body: _loading
      // لو لسه نحمّل من Firestore
          ? const Center(child: CircularProgressIndicator())
      // لو التحميل خلص، نفعّل السحب لتحديث القائمة
          : RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
          children: [
            _section(
              'Due today',
              _today,
              isToday: true,
              deletable: false,
            ),
            _section(
              'Upcoming',
              _upcoming,
              deletable: false,
            ),
            _section(
              'Already ended',
              _missed,
              deletable: false,
              dim: true,
            ),
          ],
        ),
      ),
      // زر إرسال إشعار تجريبي (محلي)
      floatingActionButton: FloatingActionButton(
        onPressed: _sendNow,
        tooltip: 'Send test notification',
        backgroundColor: _kPrimary,
        child: const Icon(Icons.bolt),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      backgroundColor: cs.surface,
    );
  }

  /// تبني جزء من الصفحة لقسم واحد:
  /// (العنوان + قائمة الكروت)
  Widget _section(
      String title,
      List<_NotifFeedItem> list, {
        bool isToday = false,
        bool deletable = false, // حاليًا مو مستخدم (ما فيه سوايب حذف)
        bool dim = false,
      }) {
    // نفلتر أي عنصر تم حذفه مسبقًا (موجود في dismissed)
    final visible = list.where((e) => !_dismissed.contains(e.key)).toList();
    if (visible.isEmpty) {
      // لو ما فيه عناصر نعرض "No items"
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ListTile(
          title:
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('No items'),
        ),
      );
    }

    // لو فيه عناصر، نعرض العنوان وبعده الكروت
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, top: 12, bottom: 6),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        ...visible.map((e) {
          final s = _styleFor(e.kind);
          return _NotifTile(
            isToday: isToday,
            dim: dim,
            baseColor: s.baseColor,
            todayBackground: isToday ? _kPrimary : null,
            icon: s.icon,
            kindLabel: s.kindLabel,
            title: e.title,
            deadlineText: e.deadlineText,
            whenText: _fmtChip.format(e.when),
            onTap: () => _handleTap(e),
          );
        }),
      ],
    );
  }

  /// ترجع شكل الـ style حسب نوع الإشعار (استرجاع / استبدال / ضمان...)
  _KindStyle _styleFor(_NotifKind k) {
    switch (k) {
      case _NotifKind.returnDeadline:
        return _KindStyle(
          baseColor: Colors.red.shade600,
          icon: Icons.swap_horiz,
          kindLabel: 'Return • Deadline',
        );
      case _NotifKind.exchangeDeadline:
        return _KindStyle(
          baseColor: Colors.red.shade600,
          icon: Icons.change_circle_outlined,
          kindLabel: 'Exchange • Deadline',
        );
      case _NotifKind.warrantyDeadline:
        return _KindStyle(
          baseColor: Colors.red.shade600,
          icon: Icons.verified,
          kindLabel: 'Warranty • Deadline',
        );
      default:
        return _KindStyle(
          baseColor: Colors.blue.shade600,
          icon: Icons.notifications,
          kindLabel: 'Deadline',
        );
    }
  }
}

/* ========= نماذج منطق الإشعار (Models) ========= */

/// أنواع الإشعارات المحتملة.
/// في هذا الكود نستخدم فقط الـ *Deadline*
/// لكن محجوزة أنواع Reminder لو حبيتي توسعين المنطق لاحقًا.
enum _NotifKind {
  returnReminder,
  returnDeadline,
  exchangeReminder,
  exchangeDeadline,
  warrantyReminder,
  warrantyDeadline,
}

/// عنصر واحد في الـ feed (يمثل موعد واحد)
class _NotifFeedItem {
  _NotifFeedItem({
    required this.when,
    required this.title,
    required this.deadlineText,
    required this.kind,
    this.billId,
    this.warrantyId,
    this.billData,
    this.warrantyData,
  });

  // التاريخ اللي نرتب عليه الإشعار (يوم الاسترجاع / الاستبدال / انتهاء الضمان)
  final DateTime when;

  // العنوان المعروض في الكرت (مثلاً: اسم الفاتورة / مزود الضمان)
  final String title;

  // النص اللي يصف الموعد (مثلاً: Return deadline: 2025-11-19)
  final String deadlineText;

  // نوع الإشعار (استرجاع / استبدال / ضمان...)
  final _NotifKind kind;

  // روابط لفتح صفحة التفاصيل
  final String? billId;
  final String? warrantyId;

  // لو حابين نختصر ونستخدم الداتا بدون إعادة قراءة من Firestore
  final Map<String, dynamic>? billData;
  final Map<String, dynamic>? warrantyData;

  /// مفتاح فريد لهذا الإشعار (نوع + عنوان + التوقيت)
  /// نستخدمه عشان نخزّنه في dismissedNotifs (لو حبّينا مستقبلاً منطق حذف نهائي)
  String get key => '${kind.name}|$title|${when.millisecondsSinceEpoch}';
}

/* ========= جزء واجهة المستخدم (UI Widgets) ========= */

/// يحدد الشكل العام لألوان الإشعار (الأيقونة + لون البادج...)
class _KindStyle {
  final Color baseColor;
  final IconData icon;
  final String kindLabel;
  _KindStyle({
    required this.baseColor,
    required this.icon,
    required this.kindLabel,
  });
}

/// الويدجت المسؤولة عن شكل كل كرت إشعار في القائمة
class _NotifTile extends StatelessWidget {
  final bool isToday;          // هل هذا الإشعار تابع لقسم "اليوم"؟
  final bool dim;              // هل نخفف ألوانه (للمنتهية)؟
  final Color baseColor;       // اللون الأساسي حسب نوع الإشعار
  final Color? todayBackground; // لون خلفية مميز لليوم
  final IconData icon;         // أيقونة النوع
  final String kindLabel;      // نص البادج (Return • Deadline ...)
  final String title;          // عنوان الإشعار (الفاتورة / الضمان)
  final String deadlineText;   // نص الموعد (مثلاً Warranty ends: 2025-11-19)
  final String whenText;       // النص الصغير اللي فوق (MMM d, HH:mm)
  final VoidCallback? onTap;   // ماذا يحدث عند الضغط على الكرت

  const _NotifTile({
    super.key,
    required this.isToday,
    required this.dim,
    required this.baseColor,
    required this.todayBackground,
    required this.icon,
    required this.kindLabel,
    required this.title,
    required this.deadlineText,
    required this.whenText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final faded = onSurface.withOpacity(0.60);
    final dimmed = dim ? onSurface.withOpacity(0.55) : onSurface;
    final radius = BorderRadius.circular(14);

    // لون خلفية الكرت: لو اليوم نخليه لون مميز، غير كذا نستخدم cardColor
    final bgColor = isToday
        ? (todayBackground ?? Colors.purple).withOpacity(0.10)
        : Theme.of(context).cardColor;

    return InkWell(
      onTap: onTap,
      borderRadius: radius,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF000000).withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: isToday
                ? (todayBackground ?? Colors.purple).withOpacity(0.25)
                : const Color(0x1F000000),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // دائرة الأيقونة
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: baseColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: baseColor, size: 20),
              ),
              const SizedBox(width: 12),
              // النصوص اللي على يمين الأيقونة
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // الصف العلوي: البادج + الوقت
                    Row(
                      children: [
                        Expanded(child: _badge(kindLabel, baseColor)),
                        const SizedBox(width: 8),
                        _timeChip(whenText, onSurface),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // العنوان (اسم الفاتورة / الضمان)
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: dimmed,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // نص الموعد (Return deadline ... / Warranty ends ...)
                    Text(
                      deadlineText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: faded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// بادج النوع (Return • Deadline / Exchange • Deadline ...)
  Widget _badge(String text, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: c.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(0.35)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: c,
          height: 1.0,
        ),
      ),
    );
  }

  /// الشريحة الصغيرة اللي فيها التاريخ/الوقت في يمين الصف العلوي
  Widget _timeChip(String text, Color onSurface) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: onSurface.withOpacity(0.26)),
      ),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}