import 'dart:io';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../common/models.dart';
import '../../common/widgets/expiry_progress.dart';

const List<String> _kMonthNames = [
  'January','February','March','April','May','June',
  'July','August','September','October','November','December'
];

// ===== الحالة العامة للفاتورة =====
enum _BillOverallStatus {
  active,        // رجوع + استبدال شغّالة أو على الأقل الاسترجاع شغّال
  exchangeOnly,  // الاسترجاع انتهى، الاستبدال فقط شغّال
  expired,       // لا استرجاع ولا استبدال
}

class BillDetailPage extends StatefulWidget {
  const BillDetailPage({super.key, required this.details});
  static const route = '/bill-detail';

  final BillDetails details;

  @override
  State<BillDetailPage> createState() => _BillDetailPageState();
}

class _BillDetailPageState extends State<BillDetailPage> {
  late BillDetails _d;
  final _money = NumberFormat.currency(locale: 'en', symbol: 'SAR ', decimalDigits: 2);

  // ===== receipt image state =====
  String? _receiptPath; // local path OR http url
  bool _loadingReceipt = false;
  String? _receiptError;

  DateTime? get _primaryEnd =>
      _d.returnDeadline ?? _d.exchangeDeadline ?? _d.warrantyExpiry;

  @override
  void initState() {
    super.initState();
    _d = widget.details;
    _loadReceiptPath();
  }

  // ===== منطق الحالة العامة للفاتورة =====

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  _BillOverallStatus get _overallStatus {
    final today = DateTime.now();
    final DateTime? ret = _d.returnDeadline;
    final DateTime? exc = _d.exchangeDeadline;

    // لو ما فيه لا استرجاع ولا استبدال نعتبرها منتهية (من ناحية حقوق استرجاع/استبدال)
    if (ret == null && exc == null) {
      return _BillOverallStatus.expired;
    }

    // 1) الاسترجاع شغّال → أخضر
    if (ret != null &&
        (today.isBefore(ret) || _isSameDay(today, ret))) {
      return _BillOverallStatus.active;
    }

    // 2) الاسترجاع انتهى، لكن الاستبدال باقي → برتقالي
    if (exc != null &&
        (today.isBefore(exc) || _isSameDay(today, exc))) {
      return _BillOverallStatus.exchangeOnly;
    }

    // 3) لا استرجاع ولا استبدال متاح الآن → أحمر
    return _BillOverallStatus.expired;
  }

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
        setState(() => _receiptPath = (path is String && path.trim().isNotEmpty) ? path : null);
      }
    } catch (e) {
      if (mounted) setState(() => _receiptError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingReceipt = false);
    }
  }

  String _pretty(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_kMonthNames[d.month - 1]} ${d.year}';

  String _ymd(DateTime? d) =>
      d == null ? '—' : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ===== Actions =====

  Future<void> _deleteBill() async {
    if (_d.id == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete bill?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await FirebaseFirestore.instance.collection('Bills').doc(_d.id).delete();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

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
    // لا نحرر/نعدل الوارنتي من شاشة التعديل

    Future<void> pickDate(BuildContext ctx, DateTime? initial, void Function(DateTime?) assign) async {
      final now = DateTime.now();
      final base = initial ?? purchase;
      final picked = await showDatePicker(
        context: ctx,
        initialDate: base,
        firstDate: DateTime(now.year - 10),
        lastDate: DateTime(now.year + 10),
      );
      if (picked != null) assign(DateTime(picked.year, picked.month, picked.day));
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
            left: 16, right: 16,
            top: 12,
            bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (ctx, setLocal) {
              Widget dateRow(String label, DateTime? value, VoidCallback onPick, {VoidCallback? onClear}) {
                return Row(
                  children: [
                    Expanded(child: Text('$label:  ${_ymd(value)}')),
                    IconButton(icon: const Icon(Icons.event), onPressed: onPick),
                    if (onClear != null)
                      IconButton(icon: const Icon(Icons.clear), onPressed: onClear, tooltip: 'Clear'),
                  ],
                );
              }

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Edit bill', style: Theme.of(ctx).textTheme.titleLarge),
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
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(child: Text('Purchase date:  ${_ymd(purchase)}')),
                        IconButton(
                          icon: const Icon(Icons.event),
                          onPressed: () async {
                            await pickDate(ctx, purchase, (v) => setLocal(() { if (v != null) purchase = v; }));
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    dateRow('Return deadline', ret, () async {
                      await pickDate(ctx, ret, (v) => setLocal(() => ret = v));
                    }, onClear: () => setLocal(() => ret = null)),

                    dateRow('Exchange deadline', exc, () async {
                      await pickDate(ctx, exc, (v) => setLocal(() => exc = v));
                    }, onClear: () => setLocal(() => exc = null)),

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

    if (saved == true) {
      final title   = titleCtrl.text.trim().isEmpty ? '—' : titleCtrl.text.trim();
      final product = productCtrl.text.trim().isEmpty ? null : productCtrl.text.trim();
      final amount  = double.tryParse(amountCtrl.text.trim());

      final payload = <String, dynamic>{
        'title': title,
        'shop_name': product,
        'total_amount': amount,
        'purchase_date': Timestamp.fromDate(purchase),
        'return_deadline': ret == null ? null : Timestamp.fromDate(ret!),
        'exchange_deadline': exc == null ? null : Timestamp.fromDate(exc!),
        // لا نرسل warranty_end_date عشان تبقى كما هي في الداتابيس
      };

      try {
        await FirebaseFirestore.instance.collection('Bills').doc(_d.id).update(payload);

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
            warrantyExpiry: _d.warrantyExpiry, // تبقى بدون تغيير
          );
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved successfully')));
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    }

    titleCtrl.dispose();
    productCtrl.dispose();
    amountCtrl.dispose();
  }

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
        child: Text('Failed to load receipt: $_receiptError', style: const TextStyle(color: Colors.red)),
      );
    }
    if (_receiptPath == null) {
      return const SizedBox.shrink();
    }

    final isNetwork = _receiptPath!.startsWith('http');
    final imageWidget = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: isNetwork
          ? Image.network(_receiptPath!, height: 180, width: double.infinity, fit: BoxFit.cover)
          : Image.file(File(_receiptPath!), height: 180, width: double.infinity, fit: BoxFit.cover),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text('Receipt image', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        GestureDetector(onTap: _openFullScreenReceipt, child: imageWidget),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: _openFullScreenReceipt,
          icon: const Icon(Icons.open_in_full),
          label: const Text('Open'),
        ),
      ],
    );
  }

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
        // === هيدر مطابق للضمان/الهوم (تدرّج + سهم رجوع + لوقو) ===
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          actions: const [_LogoStub()],
          title: const Text('Bill'),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1B0E3E), Color(0xFF0B0B1A)], // نفس أجواء الضمان الداكنة
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
              color: const Color(0xFF19142A), // مثل ضمان
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.receipt_long, color: Colors.white70),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _d.title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (_primaryEnd != null) ...[
                          const SizedBox(width: 8),
                          _buildOverallStatusPill(), // 👈 badge واحدة عامة للفاتورة
                        ],
                      ],
                    ),

                    const SizedBox(height: 14),

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
                    _kv('Product/Store', _d.product ?? '—'),
                    _kv('Amount', _d.amount == null ? '—' : _money.format(_d.amount)),
                    _kv('Purchase date', _ymd(_d.purchaseDate)),
                    if (_d.returnDeadline != null) _kv('Return deadline', _ymd(_d.returnDeadline)),
                    if (_d.exchangeDeadline != null) _kv('Exchange deadline', _ymd(_d.exchangeDeadline)),
                    if (_d.warrantyExpiry != null) _kv('Warranty expiry', _ymd(_d.warrantyExpiry)),

                    _receiptSection(),
                  ],
                ),
              ),
            ),
          ],
        ),

        // ===== أزرار سفلية بنفس ستايل الضمان =====
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _openEditSheet,
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
        backgroundColor: const Color(0xFF0E0A1C), // خلفية داكنة مثل صفحة الضمان
      ),
    );
  }
}

// ===== small reusable bits =====

class _LogoStub extends StatelessWidget {
  const _LogoStub();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('B', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
          Text('ill Wise', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70)),
        ],
      ),
    );
  }
}

Widget _kv(String k, String v) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 160, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white))),
      Expanded(child: Text(v, style: const TextStyle(color: Colors.white70))),
    ],
  ),
);

Widget _section({
  required String title,
  required DateTime start,
  required DateTime end,
  required bool months,
}) {
  // نحافظ على نفس الـ ExpiryProgress لكن بدون عرض حالة إضافية
  return ExpiryProgress(
    title: title,
    startDate: start,
    endDate: end,
    showInMonths: months,
    dense: true,
    showTitle: true,
    showStatus: false, // 👈 منع تكرار badges "active" لكل قسم
  );
}
