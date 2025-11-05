import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:integration_test/integration_test.dart";
import "package:fake_cloud_firestore/fake_cloud_firestore.dart";

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("E2E: add warranty and verify in list", (tester) async {
    final db = FakeFirebaseFirestore();

    await tester.pumpWidget(MaterialApp(home: _WarrantyHome(db: db)));
    await tester.pumpAndSettle();

    expect(find.text("No warranties yet"), findsOneWidget);

    await tester.tap(find.byKey(const Key("fab_add_warranty")));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key("field_item")), "Laptop");
    await tester.enterText(find.byKey(const Key("field_duration")), "12");
    await tester.tap(find.byKey(const Key("btn_save")));
    await tester.pumpAndSettle();

    expect(find.text("Laptop"), findsOneWidget);
    expect(find.textContaining("12 months"), findsOneWidget);
  }, timeout: const Timeout(Duration(minutes: 2)));
}

class _WarrantyHome extends StatelessWidget {
  final FakeFirebaseFirestore db;
  const _WarrantyHome({required this.db});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Warranties")),
      body: StreamBuilder(
        stream: db.collection("Warranties").snapshots(),
        builder: (_, snap) {
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(child: Text("No warranties yet"));
          }
          final docs = snap.data!.docs;
          return ListView(
            children: [
              for (final d in docs)
                ListTile(title: Text("${d["item"]}"), subtitle: Text("${d["duration"]} months")),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key("fab_add_warranty"),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => _AddWarranty(db: db)),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AddWarranty extends StatefulWidget {
  final FakeFirebaseFirestore db;
  const _AddWarranty({required this.db});

  @override
  State<_AddWarranty> createState() => _AddWarrantyState();
}

class _AddWarrantyState extends State<_AddWarranty> {
  final _item = TextEditingController();
  final _duration = TextEditingController();

  Future<void> _save() async {
    final dur = int.tryParse(_duration.text.trim()) ?? 0;
    await widget.db.collection("Warranties").add({
      "item": _item.text.trim(),
      "duration": dur,
      "created_at": DateTime.now().toIso8601String(),
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Warranty")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(key: const Key("field_item"), controller: _item, decoration: const InputDecoration(labelText: "Item name")),
            TextField(key: const Key("field_duration"), controller: _duration, decoration: const InputDecoration(labelText: "Duration (months)")),
            const SizedBox(height: 10),
            ElevatedButton(key: const Key("btn_save"), onPressed: _save, child: const Text("Save")),
          ],
        ),
      ),
    );
  }
}