import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:integration_test/integration_test.dart";
import "package:fake_cloud_firestore/fake_cloud_firestore.dart";

/// واجهة مبسّطة للـ OCR (نحقنها في الواجهة)
abstract class OcrClient { Future<Map<String, dynamic>> extract(String imagePath); }

/// Fake تمثّل استجابة Gemini بشكل واقعي (بدون شبكة)
class FakeGeminiClient implements OcrClient {
  @override
  Future<Map<String, dynamic>> extract(String imagePath) async {
    // رجعي قيم تشبه اللي يطلعها OCR
    return {
      "total": "123.45",
      "date": "2025-10-01",
      "store": "Market A",
      "warrantyMonths": 12,
      "raw_text": "Total: 123.45 SAR | Date: 2025-10-01"
    };
  }
}

/// شاشة مصغّرة: زر "Scan" يستدعي OCR ثم يملأ الحقول ويمكن حفظها في قاعدة محلية
class OcrAddBillMini extends StatefulWidget {
  final OcrClient ocr;
  final FakeFirebaseFirestore db;
  const OcrAddBillMini({super.key, required this.ocr, required this.db});

  @override
  State<OcrAddBillMini> createState() => _OcrAddBillMiniState();
}

class _OcrAddBillMiniState extends State<OcrAddBillMini> {
  final _title = TextEditingController();
  final _total = TextEditingController();
  final _date  = TextEditingController();

  Future<void> _scan() async {
    final j = await widget.ocr.extract('dummy.jpg');
    _title.text = (j['store'] ?? 'Untitled').toString();
    _total.text = (j['total'] ?? '').toString();
    _date.text  = (j['date'] ?? '').toString();
    setState((){});
  }

  Future<void> _save() async {
    await widget.db.collection('Bills').add({
      'title': _title.text.trim(),
      'total': double.tryParse(_total.text.trim()) ?? 0.0,
      'purchase_date': _date.text.trim(),
      'created_at': DateTime.now().toIso8601String(),
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OCR → Add Bill')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(key: const Key('field_title'), controller: _title, decoration: const InputDecoration(labelText: 'Title/Store')),
          TextField(key: const Key('field_total'), controller: _total, decoration: const InputDecoration(labelText: 'Total')),
          TextField(key: const Key('field_date'),  controller: _date,  decoration: const InputDecoration(labelText: 'Date')),
          const SizedBox(height: 10),
          Row(children: [
            ElevatedButton(key: const Key('btn_scan'), onPressed: _scan, child: const Text('Scan')),
            const SizedBox(width: 12),
            ElevatedButton(key: const Key('btn_save'), onPressed: _save, child: const Text('Save')),
          ]),
        ]),
      ),
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('OCR flow: scan → autofill → save to DB → visible in list', (tester) async {
    final db = FakeFirebaseFirestore();
    final app = MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          appBar: AppBar(title: const Text('Bills')),
          body: StreamBuilder(
            stream: db.collection('Bills').snapshots(),
            builder: (_, snap) {
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) return const Center(child: Text('No bills yet'));
              return ListView(children: [
                for (final d in docs) ListTile(title: Text('${d['title']}'), subtitle: Text('Total: ${d['total']}')),
              ]);
            },
          ),
          floatingActionButton: FloatingActionButton(
            key: const Key('fab_ocr'),
            onPressed: () {
              Navigator.push(ctx, MaterialPageRoute(
                builder: (_) => OcrAddBillMini(ocr: FakeGeminiClient(), db: db),
              ));
            },
            child: const Icon(Icons.document_scanner),
          ),
        ),
      ),
    );

    await tester.pumpWidget(app);
    expect(find.text('No bills yet'), findsOneWidget);

    // افتح شاشة OCR المصغّرة
    await tester.tap(find.byKey(const Key('fab_ocr')));
    await tester.pumpAndSettle();

    // اضغط Scan → يمتلئ النموذج تلقائيًا
    await tester.tap(find.byKey(const Key('btn_scan')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('field_title')), findsOneWidget);
    expect(find.text('Market A'), findsOneWidget);
    expect(find.text('123.45'), findsOneWidget);
    expect(find.text('2025-10-01'), findsOneWidget);

    // احفظ
    await tester.tap(find.byKey(const Key('btn_save')));
    await tester.pumpAndSettle();

    // رجعنا للقائمة → المفروض تظهر الفاتورة
    expect(find.text('Market A'), findsOneWidget);
    expect(find.textContaining('123.45'), findsOneWidget);
  }, timeout: const Timeout(Duration(minutes: 2)));
}