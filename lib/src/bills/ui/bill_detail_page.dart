import 'dart:io';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../common/models.dart';
import '../../common/widgets/expiry_progress.dart';

/// أسماء الشهور المستخدمة في تنسيق التاريخ بشكل جميل (مثال: "02 March 2025")
const List<String> _kMonthNames = [
  'January','February','March','April','May','June',
  'July','August','September','October','November','December'
];

/// ===== الحالة العامة للفاتورة (بادج عالية المستوى) =====
/// هذا ملخّص لحقوق الاسترجاع/الاستبدال:
/// - active:       الاسترجاع و/أو الاستبدال ما زال متاحاً
/// - exchangeOnly: الاسترجاع منتهي، الاستبدال ما زال متاحاً
/// - expired:      لا استرجاع ولا استبدال متاح
enum _BillOverallStatus {
  active,
  exchangeOnly,
  expired,
}

class BillDetailPage extends StatefulWidget {
  const BillDetailPage({super.key, required this.details});
  static const route = '/bill-detail';

  /// تفاصيل الفاتورة يتم تمريرها من شاشة القائمة (Bills page).
  final BillDetails details;

  @override
  State<BillDetailPage> createState() => _BillDetailPageState();
}

class _BillDetailPageState extends State<BillDetailPage> {
  late BillDetails _d;

  /// مهيئ لتنسيق المبلغ (SAR xx.xx)
  final _money = NumberFormat.currency(
    locale: 'en',
    symbol: 'SAR ',
    decimalDigits: 2,
  );

  // ===== حالة صورة الفاتورة (مسار محلي أو رابط شبكة) =====
  String? _receiptPath;      // قد يكون مسار ملف محلي أو رابط http(s)
  bool _loadingReceipt = false;
  String? _receiptError;

  /// تاريخ "النهاية" الأساسي المستخدم لعرض شارة الحالة العامة.
  /// الأولوية: الاسترجاع → الاستبدال → انتهاء الضمان.
  DateTime? get _primaryEnd =>
      _d.returnDeadline ?? _d.exchangeDeadline ?? _d.warrantyExpiry;

  @override
  void initState() {
    super.initState();
    _d = widget.details;
    _loadReceiptPath();
  }

  // ===== منطق الحالة العامة للفاتورة =====

  /// يتحقق إذا كان تاريخان في نفس اليوم (نفس السنة/الشهر/اليوم).
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// يحدد الحالة العامة للفاتورة بناءً على تواريخ الاسترجاع والاستبدال:
  /// 1) إذا لا يوجد استرجاع ولا استبدال → expired.
  /// 2) إذا الاسترجاع ما زال صالح اليوم أو في المستقبل → active.
  /// 3) وإلا إذا الاستبدال ما زال صالحاً → exchangeOnly.
  /// 4) غير ذلك → expired.
  _BillOverallStatus get _overallStatus {
    final today = DateTime.now();
    final DateTime? ret = _d.returnDeadline;
    final DateTime? exc = _d.exchangeDeadline;

    // لا استرجاع ولا استبدال → نعتبرها منتهية من ناحية الحقوق
    if (ret == null && exc == null) {
      return _BillOverallStatus.expired;
    }

    // 1) الاسترجاع ما زال متاحاً → Active (أخضر)
    if (ret != null &&
        (today.isBefore(ret) || _isSameDay(today, ret))) {
      return _BillOverallStatus.active;
    }

    // 2) الاسترجاع منتهي، لكن الاستبدال ما زال متاحاً → Exchange only (برتقالي)
    if (exc != null &&
        (today.isBefore(exc) || _isSameDay(today, exc))) {
      return _BillOverallStatus.exchangeOnly;
    }

    // 3) لا استرجاع ولا استبدال متاحين → Expired (أحمر)
    return _BillOverallStatus.expired;
  }

  /// يبني شارة (بادج) ملونة تُعرض أعلى الكرت،
  /// تلخّص إذا الفاتورة فعّالة / استبدال فقط / منتهية.
  Widget _buildOverallStatusPill() {
    final status = _overallStatus;

    late Color color;
    late String label;

    switch (status) {
      case _BillOverallStatus.active:
        color = Colors.green;
        label = 'active';
        break;
      case _BillOverallStatus.exchangeOnly:
        color = Colors.orange;
        label = 'exchange only';
        break;
      case _BillOverallStatus.expired:
        color = Colors.red;
        label = 'expired';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// تحميل حقل receipt_image_path من وثيقة الفاتورة في Firestore.
  /// يمكن أن يكون null، أو مسار محلي، أو رابط URL.
  Future<void> _loadReceiptPath() async {
    if (_d.id == null) return;
    setState(() {
      _loadingReceipt = true;
      _receiptError = null;
    });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('Bills')
          .doc(_d.id)
          .get();
      final path = snap.data()?['receipt_image_path'];
      if (mounted) {
        setState(() => _receiptPath =
        (path is String && path.trim().isNotEmpty) ? path : null);
      }
    } catch (e) {
      if (mounted) setState(() => _receiptError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingReceipt = false);
    }
  }

  /// تنسيق جميل للتاريخ بصيغة "02 March 2025".
  String _pretty(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_kMonthNames[d.month - 1]} ${d.year}';

  /// تنسيق مختصر Y-M-D "yyyy-MM-dd" أو "—" إذا كان null.
  String _ymd(DateTime? d) =>
      d == null
          ? '—'
          : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ===== الإجراءات: حذف وتعديل =====

  /// حذف الفاتورة الحالية بعد عرض مربع حوار للتأكيد.
  Future<void> _deleteBill() async {
    if (_d.id == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete bill?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('Bills')
          .doc(_d.id)
          .delete();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  /// فتح BottomSheet لتعديل الفاتورة (العنوان، المنتج/المتجر، المبلغ،
  /// تاريخ الشراء، تاريخ الاسترجاع، تاريخ الاستبدال).
  ///
  /// ملاحظة: حقول الضمان لا يتم تعديلها من خلال هذه النافذة.
  Future<void> _openEditSheet() async {
    if (_d.id == null) return;

    final titleCtrl   = TextEditingController(text: _d.title);
    final productCtrl = TextEditingController(text: _d.product ?? '');
    final amountCtrl  = TextEditingController(
      text: _d.amount == null ? '' : _d.amount!.toStringAsFixed(2),
    );

    DateTime purchase = _d.purchaseDate;
    DateTime? ret = _d.returnDeadline;
    DateTime? exc = _d.exchangeDeadline;
    // لا نعدّل تواريخ الضمان من خلال هذه النافذة.

    /// مساعد لاختيار تاريخ وإسناده للمتغيرات المحلية.
    Future<void> pickDate(
        BuildContext ctx,
        DateTime? initial,
        void Function(DateTime?) assign,
        ) async {
      final now = DateTime.now();
      final base = initial ?? purchase;
      final picked = await showDatePicker(
        context: ctx,
        initialDate: base,
        firstDate: DateTime(now.year - 10),
        lastDate: DateTime(now.year + 10),
      );
      if (picked != null) {
        assign(DateTime(picked.year, picked.month, picked.day));
      }
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (ctx, setLocal) {
              /// ويدجت مساعدة صغيرة لعرض وتعديل حقل تاريخ واحد.
              Widget dateRow(
                  String label,
                  DateTime? value,
                  VoidCallback onPick, {
                    VoidCallback? onClear,
                  }) {
                return Row(
                  children: [
                    Expanded(
                      child: Text('$label:  ${_ymd(value)}'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.event),
                      onPressed: onPick,
                    ),
                    if (onClear != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: onClear,
                        tooltip: 'Clear',
                      ),
                  ],
                );
              }

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Edit bill',
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        prefixIcon: Icon(Icons.text_fields),
                      ),
                    ),
                    const SizedBox(height: 8),

                    TextField(
                      controller: productCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Product / Store',
                        prefixIcon: Icon(Icons.store),
                      ),
                    ),
                    const SizedBox(height: 8),

                    TextField(
                      controller: amountCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Amount (SAR)',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // صف تاريخ الشراء
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Purchase date:  ${_ymd(purchase)}',
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.event),
                          onPressed: () async {
                            await pickDate(
                              ctx,
                              purchase,
                                  (v) => setLocal(() {
                                if (v != null) purchase = v;
                              }),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // صف تاريخ الاسترجاع (مع زر مسح)
                    dateRow(
                      'Return deadline',
                      ret,
                          () async {
                        await pickDate(ctx, ret, (v) => setLocal(() => ret = v));
                      },
                      onClear: () => setLocal(() => ret = null),
                    ),

                    // صف تاريخ الاستبدال (مع زر مسح)
                    dateRow(
                      'Exchange deadline',
                      exc,
                          () async {
                        await pickDate(ctx, exc, (v) => setLocal(() => exc = v));
                      },
                      onClear: () => setLocal(() => exc = null),
                    ),

                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Save changes'),
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    // تنفيذ منطق الحفظ إذا المستخدم أكد التعديلات
    if (saved == true) {
      final title   = titleCtrl.text.trim().isEmpty
          ? '—'
          : titleCtrl.text.trim();
      final product = productCtrl.text.trim().isEmpty
          ? null
          : productCtrl.text.trim();
      final amount  = double.tryParse(amountCtrl.text.trim());

      final payload = <String, dynamic>{
        'title': title,
        'shop_name': product,
        'total_amount': amount,
        'purchase_date': Timestamp.fromDate(purchase),
        'return_deadline': ret == null ? null : Timestamp.fromDate(ret!),
        'exchange_deadline': exc == null ? null : Timestamp.fromDate(exc!),
        // عمداً لا نقوم بتحديث warranty_end_date من هنا.
      };

      try {
        await FirebaseFirestore.instance
            .collection('Bills')
            .doc(_d.id)
            .update(payload);

        // تحديث الحالة المحلية حتى تعكس الواجهة القيم الجديدة
        setState(() {
          _d = BillDetails(
            id: _d.id,
            title: title,
            product: product,
            amount: amount,
            purchaseDate: purchase,
            returnDeadline: ret,
            exchangeDeadline: exc,
            hasWarranty: _d.hasWarranty,
            warrantyExpiry: _d.warrantyExpiry, // تبقى كما هي
          );
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved successfully')),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }

    // التخلص من المتحكمات التي أنشأناها داخل هذه الدالة
    titleCtrl.dispose();
    productCtrl.dispose();
    amountCtrl.dispose();
  }

  /// يبني جزء "صورة الفاتورة":
  /// - يظهر شريط تحميل أثناء الجلب
  /// - يظهر رسالة خطأ عند الفشل
  /// - يعرض صورة مصغّرة يمكن فتحها في شاشة كاملة
  Widget _receiptSection() {
    if (_loadingReceipt) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }
    if (_receiptError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Failed to load receipt: $_receiptError',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }
    if (_receiptPath == null) {
      return const SizedBox.shrink();
    }

    final isNetwork = _receiptPath!.startsWith('http');
    final imageWidget = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: isNetwork
          ? Image.network(
        _receiptPath!,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
      )
          : Image.file(
        File(_receiptPath!),
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text(
          'Receipt image',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _openFullScreenReceipt,
          child: imageWidget,
        ),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: _openFullScreenReceipt,
          icon: const Icon(Icons.open_in_full),
          label: const Text('Open'),
        ),
      ],
    );
  }

  /// فتح صورة الفاتورة في حوار ملء الشاشة مع إمكانية التكبير/التصغير.
  void _openFullScreenReceipt() {
    if (_receiptPath == null) return;
    final isNetwork = _receiptPath!.startsWith('http');
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: isNetwork
              ? Image.network(_receiptPath!, fit: BoxFit.contain)
              : Image.file(File(_receiptPath!), fit: BoxFit.contain),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Scaffold(
        // === هيدر متناسق مع الضمان/الهوم (تدرّج + سهم رجوع + شعار بسيط) ===
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          actions: const [_LogoStub()],
          title: const Text('Bill'),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1B0E3E), Color(0xFF0B0B1A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),

        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Card(
              color: const Color(0xFF19142A), // كرت داكن (يتناسب مع صفحة الضمان)
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ===== صف الهيدر: أيقونة + عنوان + شارة الحالة العامة =====
                    Row(
                      children: [
                        const Icon(
                          Icons.receipt_long,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _d.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (_primaryEnd != null) ...[
                          const SizedBox(width: 8),
                          _buildOverallStatusPill(), // شارة واحدة عالية المستوى لحالة الفاتورة
                        ],
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ===== أجزاء الخط الزمني: استرجاع / استبدال / ضمان =====
                    if (_d.returnDeadline != null)
                      _section(
                        title: 'Return',
                        start: _d.purchaseDate,
                        end: _d.returnDeadline!,
                        months: false,
                      ),
                    if (_d.exchangeDeadline != null) ...[
                      const SizedBox(height: 8),
                      _section(
                        title: 'Exchange',
                        start: _d.purchaseDate,
                        end: _d.exchangeDeadline!,
                        months: false,
                      ),
                    ],
                    if (_d.warrantyExpiry != null) ...[
                      const SizedBox(height: 8),
                      _section(
                        title: 'Warranty',
                        start: _d.purchaseDate,
                        end: _d.warrantyExpiry!,
                        months: true,
                      ),
                    ],

                    const SizedBox(height: 6),

                    // ===== صفوف معلومات رئيسية (مفتاح/قيمة) =====
                    _kv('Product/Store', _d.product ?? '—'),
                    _kv(
                      'Amount',
                      _d.amount == null ? '—' : _money.format(_d.amount),
                    ),
                    _kv('Purchase date', _ymd(_d.purchaseDate)),
                    if (_d.returnDeadline != null)
                      _kv('Return deadline', _ymd(_d.returnDeadline)),
                    if (_d.exchangeDeadline != null)
                      _kv('Exchange deadline', _ymd(_d.exchangeDeadline)),
                    if (_d.warrantyExpiry != null)
                      _kv('Warranty expiry', _ymd(_d.warrantyExpiry)),

                    // ===== جزء صورة الفاتورة (إن وجدت) =====
                    _receiptSection(),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Inside bottomNavigationBar:
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    await _openEditSheet();  // ← يفتح الإيديت
                    setState(() {});         // ← التحديث الذهبي
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4A6CF7),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _deleteBill,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              ),
            ],
          ),
        ),

        backgroundColor: const Color(0xFF0E0A1C), // خلفية داكنة لتناسق مع صفحة الضمان
      ),
    );
  }
}

// ===== أجزاء صغيرة قابلة لإعادة الاستخدام (اللوجو + صف مفتاح/قيمة + قسم ExpiryProgress) =====

/// عنصر لوجو بسيط في الـ AppBar.
class _LogoStub extends StatelessWidget {
  const _LogoStub();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'B',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: Colors.white),
          ),
          Text(
            'ill Wise',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

/// صف قياسي (مفتاح - قيمة) يُستخدم في جزء تفاصيل الفاتورة.
Widget _kv(String k, String v) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 160,
        child: Text(
          k,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      Expanded(
        child: Text(
          v,
          style: const TextStyle(color: Colors.white70),
        ),
      ),
    ],
  ),
);

/// غلاف قسم واحد يستخدم ExpiryProgress لعرض خط زمني
/// (استرجاع / استبدال / ضمان). نخفي شارة الحالة الداخلية
/// لأننا نعرض بالفعل شارة حالة عامة لكل الفاتورة.
Widget _section({
  required String title,
  required DateTime start,
  required DateTime end,
  required bool months,
}) {
  return ExpiryProgress(
    key: ValueKey('$title-${start.toIso8601String()}-${end.toIso8601String()}'), // ★ السطر السحري
    title: title,
    startDate: start,
    endDate: end,
    showInMonths: months,
    dense: true,
    showTitle: true,
    showStatus: false,
  );
}
