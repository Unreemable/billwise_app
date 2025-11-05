import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:integration_test/integration_test.dart";
import "package:fake_cloud_firestore/fake_cloud_firestore.dart";

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("E2E: edit an existing bill", (tester) async {
    final db = FakeFirebaseFirestore();
    // Seed one bill
    final seeded = await db.collection("Bills").add({
      "title": "Old Title",
      "total": 50.0,
      "created_at": DateTime.now().toIso8601String(),
    });

    await tester.pumpWidget(MaterialApp(home: _HomePage(db: db)));
    await tester.pumpAndSettle();

    // Existing bill visible
    expect(find.text("Old Title"), findsOneWidget);

    // Tap to edit
    await tester.tap(find.text("Old Title"));
    await tester.pumpAndSettle();

    // Edit and save
    await tester.enterText(find.byKey(const Key("field_title")), "Updated Bill");
    await tester.enterText(find.byKey(const Key("field_total")), "99.99");
    await tester.tap(find.byKey(const Key("btn_save")));
    await tester.pumpAndSettle();

    // Back to list -> updated
    expect(find.text("Updated Bill"), findsOneWidget);
    expect(find.textContaining("99.99"), findsOneWidget);

    // Verify in DB
    final doc = await db.collection("Bills").doc(seeded.id).get();
    expect(doc.data()?["title"], "Updated Bill");
    expect(doc.data()?["total"], 99.99);
  }, timeout: const Timeout(Duration(minutes: 2)));
}

class _HomePage extends StatelessWidget {
  final FakeFirebaseFirestore db;
  const _HomePage({required this.db});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bills")),
      body: StreamBuilder(
        stream: db.collection("Bills").snapshots(),
        builder: (_, snap) {
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(child: Text("No bills yet"));
          }
          final docs = snap.data!.docs;
          return ListView(
            children: [
              for (final d in docs)
                ListTile(
                  title: Text("${d["title"]}"),
                  subtitle: Text("Total: ${d["total"]}"),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _EditBillPage(db: db, id: d.id, data: d.data()),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _EditBillPage extends StatefulWidget {
  final FakeFirebaseFirestore db;
  final String id;
  final Map<String, dynamic> data;
  const _EditBillPage({required this.db, required this.id, required this.data});

  @override
  State<_EditBillPage> createState() => _EditBillPageState();
}

class _EditBillPageState extends State<_EditBillPage> {
  late TextEditingController title;
  late TextEditingController total;

  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.data["title"]);
    total = TextEditingController(text: "${widget.data["total"]}");
  }

  Future<void> _save() async {
    await widget.db.collection("Bills").doc(widget.id).update({
      "title": title.text.trim(),
      "total": double.tryParse(total.text.trim()) ?? 0.0,
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Bill")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(key: const Key("field_title"), controller: title, decoration: const InputDecoration(labelText: "Title")),
            TextField(key: const Key("field_total"), controller: total, decoration: const InputDecoration(labelText: "Total")),
            const SizedBox(height: 10),
            ElevatedButton(key: const Key("btn_save"), onPressed: _save, child: const Text("Save")),
          ],
        ),
      ),
    );
  }
}