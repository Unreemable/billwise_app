import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

class _TestForm extends StatefulWidget {
  const _TestForm({super.key});
  @override
  State<_TestForm> createState() => _TestFormState();
}

class _TestFormState extends State<_TestForm> {
  final _title = TextEditingController();
  String? _error;

  void _save() {
    setState(() {
      _error = _title.text.trim().isEmpty ? "العنوان مطلوب" : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            TextField(
              key: const Key("titleField"),
              controller: _title,
              decoration: InputDecoration(errorText: _error),
            ),
            ElevatedButton(onPressed: _save, child: const Text("حفظ")),
          ],
        ),
      ),
    );
  }
}

void main() {
  testWidgets("shows error when saving with empty title", (tester) async {
    await tester.pumpWidget(const _TestForm());
    await tester.tap(find.text("حفظ"));
    await tester.pump();
    expect(find.text("العنوان مطلوب"), findsOneWidget);
  });
}