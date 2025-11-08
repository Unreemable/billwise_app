// ================== Bills Page with Home GradientBottomBar ==================
import 'dart:ui' as ui; // for TextDirection.ltr
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../common/models.dart';
import '../../common/widgets/expiry_progress.dart';
import '../data/bill_service.dart';
import 'add_bill_page.dart';
import 'bill_detail_page.dart';
// لو تبغى فتح تبويب الضمانات:
import '../../warranties/ui/warranty_list_page.dart';

// ===== نفس ألوان الهوم =====
const Color _kBgDark   = Color(0xFF0E0722);
const Color _kCardDark = Color(0x1AFFFFFF);
const Color _kTextDim  = Colors.white70;
const LinearGradient _kHeaderGradient = LinearGradient(
  colors: [Color(0xFF1A0B3A), Color(0xFF0E0722)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const LinearGradient _kSearchGradient = LinearGradient(
  colors: [Color(0xFF6C3EFF), Color(0xFF3E8EFD)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// ============ Bottom Gradient Bar (منسوخة من الهوم) ============
class GradientBottomBar extends StatelessWidget {
  final int selectedIndex;               // 0 = Warranties, 1 = Bills
  final ValueChanged<int> onTap;
  final Color startColor;
  final Color endColor;

  const GradientBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    this.startColor = const Color(0xFF6C3EFF),
    this.endColor   = const Color(0xFF3E8EFD),
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return SafeArea(
      top: false,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [startColor, endColor],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottomInset),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _BottomItem(
                    icon: Icons.verified_user_rounded,
                    label: 'Warranties',
                    selected: selectedIndex == 0,
                    onTap: () => onTap(0),
                  ),
                  const SizedBox(width: 18),
                  _FabDot(
                    onTap: () {
                      // يفتح صفحة الهوم
                      Navigator.of(context, rootNavigator: true).pushNamed('/home');
                    },
                  ),
                  const SizedBox(width: 18),
                  _BottomItem(
                    icon: Icons.receipt_long_rounded,
                    label: 'Bills',
                    selected: selectedIndex == 1,
                    onTap: () => onTap(1),
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

class _BottomItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  const _BottomItem({required this.icon, required this.label, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : Colors.white70;
    final selectedBg = Colors.white.withOpacity(.16);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? selectedBg : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: fg, size: 20),
            const SizedBox(width: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: TextStyle(color: fg, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _FabDot extends StatelessWidget {
  final VoidCallback? onTap;
  const _FabDot({this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(27),
      onTap: onTap,
      child: Container(
        width: 54, height: 54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF6C3EFF), Color(0xFF3E8EFD)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF934DFE).withOpacity(.45),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: const Icon(Icons.home_filled, color: Colors.white),
      ),
    );
  }
}

// ===============================================================

class BillListPage extends StatefulWidget {
  const BillListPage({super.key});
  static const route = '/bills';

  @override
  State<BillListPage> createState() => _BillListPageState();
}

enum _BillSort { newest, oldest, nearExpiry }

class _BillListPageState extends State<BillListPage> {
  final _searchCtrl = TextEditingController();
  final _money = NumberFormat.currency(locale: 'en', symbol: 'SAR ', decimalDigits: 2);
  _BillSort _sort = _BillSort.newest;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ================ Helpers ================
  DateTime _onlyDate(DateTime d) => DateTime(d.year, d.month, d.day);
  int _monthsBetween(DateTime a, DateTime b) {
    final aa = DateTime(a.year, a.month);
    final bb = DateTime(b.year, b.month);
    return (bb.year - aa.year) * 12 + (bb.month - aa.month);
  }

  Color? _threeDayReturnColor(DateTime? startUtc, DateTime? endUtc) {
    if (startUtc == null || endUtc == null) return null;
    final s = _onlyDate(startUtc.toLocal());
    final e = _onlyDate(endUtc.toLocal());
    if (e.difference(s).inDays != 3) return null;
    final today = _onlyDate(DateTime.now());
    final diff = today.difference(s).inDays;
    if (diff < 0) return Colors.blueGrey;
    if (diff == 0) return Colors.green;
    if (diff == 1) return Colors.orange;
    if (diff == 2) return Colors.red;
    return Colors.grey;
  }

  String? _threeDayReturnLabel(DateTime? startUtc, DateTime? endUtc) {
    if (startUtc == null || endUtc == null) return null;
    final s = _onlyDate(startUtc.toLocal());
    final e = _onlyDate(endUtc.toLocal());
    if (e.difference(s).inDays != 3) return null;
    final today = _onlyDate(DateTime.now());
    final diff = today.difference(s).inDays;
    if (diff < 0) return 'Starts soon';
    if (diff == 0) return 'Day 1 of 3';
    if (diff == 1) return 'Day 2 of 3';
    if (diff == 2) return 'Final day (3 of 3)';
    return 'Expired';
  }

  Color? _sevenDayExchangeColor(DateTime? startUtc, DateTime? endUtc) {
    if (startUtc == null || endUtc == null) return null;
    final s = _onlyDate(startUtc.toLocal());
    final e = _onlyDate(endUtc.toLocal());
    if (e.difference(s).inDays != 7) return null;
    final today = _onlyDate(DateTime.now());
    final diff = today.difference(s).inDays + 1;
    if (diff <= 0) return Colors.blueGrey;
    if (diff >= 1 && diff <= 3) return Colors.green;
    if (diff >= 4 && diff <= 6) return Colors.orange;
    if (diff == 7) return Colors.red;
    return Colors.grey;
  }

  String? _sevenDayExchangeLabel(DateTime? startUtc, DateTime? endUtc) {
    if (startUtc == null || endUtc == null) return null;
    final s = _onlyDate(startUtc.toLocal());
    final e = _onlyDate(endUtc.toLocal());
    if (e.difference(s).inDays != 7) return null;
    final today = _onlyDate(DateTime.now());
    final diff = today.difference(s).inDays + 1;
    if (diff <= 0) return 'Starts soon';
    if (diff >= 1 && diff <= 3) return 'Days 1–3 of 7';
    if (diff >= 4 && diff <= 6) return 'Days 4–6 of 7';
    if (diff == 7) return 'Final day (7 of 7)';
    return 'Expired';
  }

  Color? _warrantyColor(DateTime? startUtc, DateTime? endUtc) {
    if (startUtc == null || endUtc == null) return null;
    final s = _onlyDate(startUtc.toLocal());
    final e = _onlyDate(endUtc.toLocal());
    final today = _onlyDate(DateTime.now());
    if (today.isBefore(s)) return Colors.blueGrey;
    if (!today.isBefore(e)) return Colors.grey;

    final totalMonths = _monthsBetween(s, e);
    final elapsedMonths = _monthsBetween(s, today);
    if (totalMonths >= 23 && totalMonths <= 25) {
      if (elapsedMonths < 12) return Colors.green;
      if (elapsedMonths < 18) return Colors.orange;
      return Colors.red;
    }

    final totalDays = e.difference(s).inDays;
    final elapsedDays = today.difference(s).inDays;
    if (totalDays <= 0) return Colors.grey;
    final t1 = (totalDays / 3).ceil();
    final t2 = (2 * totalDays / 3).ceil();
    if (elapsedDays < t1) return Colors.green;
    if (elapsedDays < t2) return Colors.orange;
    return Colors.red;
  }

  String? _warrantyLabel(DateTime? startUtc, DateTime? endUtc) {
    if (startUtc == null || endUtc == null) return null;
    final s = _onlyDate(startUtc.toLocal());
    final e = _onlyDate(endUtc.toLocal());
    final today = _onlyDate(DateTime.now());
    if (today.isBefore(s)) return 'Starts soon';
    if (!today.isBefore(e)) return 'Expired';

    final totalMonths = _monthsBetween(s, e);
    final elapsedMonths = _monthsBetween(s, today);
    if (totalMonths >= 23 && totalMonths <= 25) {
      if (elapsedMonths < 12) return 'Year 1 of 2';
      if (elapsedMonths < 18) return 'Year 2 (first 6 months)';
      return 'Year 2 (final 6 months)';
    }

    final totalDays = e.difference(s).inDays;
    final elapsedDays = today.difference(s).inDays;
    if (totalDays <= 0) return 'Expired';
    final t1 = (totalDays / 3).ceil();
    final t2 = (2 * totalDays / 3).ceil();
    if (elapsedDays < t1) return 'First third';
    if (elapsedDays < t2) return 'Second third';
    return 'Final third';
  }

  Chip _statusChip(DateTime? startUtc, DateTime? endUtc, {Color? overrideColor}) {
    if (startUtc == null || endUtc == null) return const Chip(label: Text('—'));
    final s = _onlyDate(startUtc.toLocal());
    final e = _onlyDate(endUtc.toLocal());
    final today = _onlyDate(DateTime.now());

    late String text;
    late Color color;
    late IconData icon;

    if (today.isBefore(s)) {
      text = 'upcoming'; color = Colors.blueGrey; icon = Icons.schedule;
    } else if (today.isAfter(e) || today.isAtSameMomentAs(e)) {
      text = 'expired';  color = Colors.red;      icon = Icons.close_rounded;
    } else {
      text = 'active';   color = overrideColor ?? Colors.green; icon = Icons.check_circle_rounded;
    }

    return Chip(
      avatar: Icon(icon, size: 16, color: Colors.white),
      label: Text(text, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _policyBlock({required String title, required DateTime? start, required DateTime? end}) {
    if (start == null || end == null) return const SizedBox.shrink();

    final kind = title.toLowerCase();
    final isReturn = kind == 'return';
    final isExchange = kind == 'exchange';
    final isWarranty = kind == 'warranty';

    final threeDayColor = isReturn ? _threeDayReturnColor(start, end) : null;
    final threeDayLabel = isReturn ? _threeDayReturnLabel(start, end) : null;

    final sevenDayColor = isExchange ? _sevenDayExchangeColor(start, end) : null;
    final sevenDayLabel = isExchange ? _sevenDayExchangeLabel(start, end) : null;

    final warrantyColor = isWarranty ? _warrantyColor(start, end) : null;
    final warrantyLabel = isWarranty ? _warrantyLabel(start, end) : null;

    final barColor = threeDayColor ?? sevenDayColor ?? warrantyColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (threeDayColor != null) ...[
          Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: threeDayColor, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(threeDayLabel ?? 'Return (3-day window)',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 6),
        ],
        if (sevenDayColor != null) ...[
          Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: sevenDayColor, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(sevenDayLabel ?? 'Exchange (7-day window)',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 6),
        ],
        if (warrantyColor != null) ...[
          Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: warrantyColor, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(warrantyLabel ?? 'Warranty (3 segments)',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 6),
        ],
        ExpiryProgress(
          title: title,
          startDate: start,
          endDate: end,
          dense: true,
          showInMonths: isWarranty,
          barColor: barColor,
        ),
        const SizedBox(height: 6),
        Align(alignment: Alignment.centerLeft, child: _statusChip(start, end, overrideColor: barColor)),
      ],
    );
  }

  DateTime? _nearestExpiry(Map<String, dynamic> d) {
    DateTime? parseTs(dynamic v) => (v is Timestamp) ? v.toDate().toLocal() : null;
    DateTime? minDate(DateTime? a, DateTime? b) {
      if (a == null) return b;
      if (b == null) return a;
      return a.isBefore(b) ? a : b;
    }
    final ret = parseTs(d['return_deadline']);
    final ex  = parseTs(d['exchange_deadline']);
    final w   = parseTs(d['warranty_end_date']);
    final m = minDate(minDate(ret, ex), w);
    return m == null ? null : DateTime(m.year, m.month, m.day);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: _kBgDark,

        // ===== AppBar بدون سهم =====
        appBar: AppBar(
          automaticallyImplyLeading: false, // لا تظهر أسهم تلقائيًا
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Bills', style: TextStyle(color: Colors.white)),
          flexibleSpace: Container(decoration: const BoxDecoration(gradient: _kHeaderGradient)),
        ),

        // ===== Bottom Bar حق الهوم =====
        bottomNavigationBar: GradientBottomBar(
          selectedIndex: 1, // Bills
          onTap: (i) {
            if (i == 0) {
              Navigator.of(context, rootNavigator: true).pushNamed(WarrantyListPage.route);
            } else if (i == 1) {
              // أنت بالفعل في Bills — لا شيء
            }
          },
        ),

        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            await Navigator.of(context, rootNavigator: true)
                .push(MaterialPageRoute(builder: (_) => const AddBillPage()));
            if (mounted) setState(() {}); // refresh after adding
          },
          child: const Icon(Icons.add),
        ),

        body: uid == null
            ? const Center(child: Text('Please sign in to view your bills.', style: TextStyle(color: Colors.white)))
            : Column(
          children: [
            // ====== شريط البحث بنفس ستايل الهوم ======
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: _kSearchGradient,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF934DFE).withOpacity(.45),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        cursorColor: Colors.white,
                        decoration: const InputDecoration(
                          hintText: 'Search by title or store',
                          hintStyle: TextStyle(color: Colors.white70),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    if (_searchCtrl.text.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear',
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ====== فلاتر الفرز ======
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Newest'),
                    selected: _sort == _BillSort.newest,
                    onSelected: (_) => setState(() => _sort = _BillSort.newest),
                    labelStyle: TextStyle(color: _sort == _BillSort.newest ? Colors.white : _kTextDim),
                    selectedColor: Colors.white.withOpacity(.14),
                    backgroundColor: Colors.white.withOpacity(.06),
                  ),
                  ChoiceChip(
                    label: const Text('Oldest'),
                    selected: _sort == _BillSort.oldest,
                    onSelected: (_) => setState(() => _sort = _BillSort.oldest),
                    labelStyle: TextStyle(color: _sort == _BillSort.oldest ? Colors.white : _kTextDim),
                    selectedColor: Colors.white.withOpacity(.14),
                    backgroundColor: Colors.white.withOpacity(.06),
                  ),
                  ChoiceChip(
                    label: const Text('Near expiry'),
                    selected: _sort == _BillSort.nearExpiry,
                    onSelected: (_) => setState(() => _sort = _BillSort.nearExpiry),
                    labelStyle: TextStyle(color: _sort == _BillSort.nearExpiry ? Colors.white : _kTextDim),
                    selectedColor: Colors.white.withOpacity(.14),
                    backgroundColor: Colors.white.withOpacity(.06),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // ====== القائمة ======
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: BillService.instance.streamBillsSnapshot(
                  userId: uid,
                  orderBy: 'created_at',
                  descending: _sort != _BillSort.oldest,
                ),
                builder: (context, s) {
                  if (s.hasError) {
                    return Center(child: Text('Error: ${s.error}', style: const TextStyle(color: Colors.white)));
                  }
                  if (!s.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  var docs = s.data!.docs;

                  final q = _searchCtrl.text.trim().toLowerCase();
                  if (q.isNotEmpty) {
                    docs = docs.where((e) {
                      final d = e.data();
                      final title = (d['title'] ?? '').toString().toLowerCase();
                      final shop  = (d['shop_name'] ?? '').toString().toLowerCase();
                      return title.contains(q) || shop.contains(q);
                    }).toList();
                  }

                  if (docs.isEmpty) {
                    return const Center(child: Text('No bills found.', style: TextStyle(color: Colors.white)));
                  }

                  if (_sort == _BillSort.nearExpiry) {
                    docs.sort((a, b) {
                      final ax = _nearestExpiry(a.data());
                      final bx = _nearestExpiry(b.data());
                      if (ax == null && bx == null) return 0;
                      if (ax == null) return 1;
                      if (bx == null) return -1;
                      return ax.compareTo(bx);
                    });
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemCount: docs.length,
                    itemBuilder: (_, i) {
                      final doc = docs[i];
                      final d = doc.data();

                      final title  = (d['title'] ?? '—').toString();
                      final shop   = (d['shop_name'] ?? '—').toString();
                      final amount = (d['total_amount'] as num?)?.toDouble();

                      final purchase = (d['purchase_date'] as Timestamp?)?.toDate().toLocal();
                      final ret      = (d['return_deadline'] as Timestamp?)?.toDate().toLocal();
                      final ex       = (d['exchange_deadline'] as Timestamp?)?.toDate().toLocal();

                      final hasWarranty = (d['warranty_coverage'] as bool?) ?? false;
                      final wEnd        = (d['warranty_end_date'] as Timestamp?)?.toDate().toLocal();

                      return Container(
                        decoration: BoxDecoration(
                          color: _kCardDark,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          title: Text(
                            shop,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text(
                                '${title == shop ? '' : '$title • '}${amount == null ? '-' : _money.format(amount)}',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                              const SizedBox(height: 10),
                              _policyBlock(title: 'Return',   start: purchase, end: ret),
                              const SizedBox(height: 10),
                              _policyBlock(title: 'Exchange', start: purchase, end: ex),
                              const SizedBox(height: 10),
                              if (hasWarranty && wEnd != null)
                                _policyBlock(title: 'Warranty', start: purchase, end: wEnd),
                            ],
                          ),
                          onTap: () {
                            final details = BillDetails(
                              id: doc.id,
                              title: title,
                              product: shop,
                              amount: amount ?? 0,
                              purchaseDate: purchase ?? DateTime.now(),
                              returnDeadline: ret,
                              exchangeDeadline: ex,
                              hasWarranty: hasWarranty,
                              warrantyExpiry: wEnd,
                            );
                            Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute(builder: (_) => BillDetailPage(details: details)),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
