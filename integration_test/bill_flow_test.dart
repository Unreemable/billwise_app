import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:integration_test/integration_test.dart";
import "package:fake_cloud_firestore/fake_cloud_firestore.dart";

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    "E2E: add a bill -> saved to DB -> appears in list",
    (tester) async {
      // قاعدة بيانات مزيّفة (بدون سحابة)
      final db = FakeFirebaseFirestore();

      // شغّل تطبيق مصغّر: صفحة رئيسية + صفحة إضافة فاتورة
      await tester.pumpWidget(MaterialApp(home: _HomePage(db: db)));
      await tester.pumpAndSettle();

      // قبل الإضافة: القائمة فارغة
      expect(find.text("No bills yet"), findsOneWidget);

      // افتح صفحة الإضافة
      await tester.tap(find.byKey(const Key("fab_add_bill")));
      await tester.pumpAndSettle();

      // اكتب العنوان والمبلغ
      await tester.enterText(find.byKey(const Key("field_title")), "Test Bill");
      await tester.enterText(find.byKey(const Key("field_total")), "123.45");

      // اضغط حفظ
      await tester.tap(find.byKey(const Key("btn_save")));
      await tester.pumpAndSettle();

      // نرجع للهوم: لازم نشوف الفاتورة الجديدة في القائمة
      expect(find.text("Test Bill"), findsOneWidget);
      expect(find.textContaining("123.45"), findsOneWidget);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

/// صفحة رئيسية: تعرض قائمة الفواتير من FakeFirestore
class _HomePage extends StatelessWidget {
  final FakeFirebaseFirestore db;
  const _HomePage({required this.db});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bills")),
      body: StreamBuilder(
        stream: db.collection("Bills").orderBy("created_at", descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No bills yet"));
          }
          final docs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i].data();
              return ListTile(
                title: Text("${d["title"]}"),
                subtitle: Text("Total: ${d["total"]}"),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key("fab_add_bill"),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => _AddBillPage(db: db)),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// صفحة إضافة فاتورة: حقول إدخال + حفظ في FakeFirestore ثم رجوع
class _AddBillPage extends StatefulWidget {
  final FakeFirebaseFirestore db;
  const _AddBillPage({required this.db});

  @override
  State<_AddBillPage> createState() => _AddBillPageState();
}

class _AddBillPageState extends State<_AddBillPage> {
  final _title = TextEditingController();
  final _total = TextEditingController();
  String? _error;

  Future<void> _save() async {
    final title = _title.text.trim();
    final totalStr = _total.text.trim();
    final total = double.tryParse(totalStr);

    if (title.isEmpty || total == null) {
      setState(() => _error = "البيانات غير صحيحة");
      return;
    }

    await widget.db.collection("Bills").add({
      "title": title,
      "total": total,
      "created_at": DateTime.now().toIso8601String(),
      "user_id": "test-uid",
    });

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Bill")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            TextField(
              key: const Key("field_title"),
              controller: _title,
              decoration: const InputDecoration(labelText: "Title"),
            ),
            TextField(
              key: const Key("field_total"),
              controller: _total,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Total"),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              key: const Key("btn_save"),
              onPressed: _save,
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }
}