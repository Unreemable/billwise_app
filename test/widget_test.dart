import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class ExampleForm extends StatefulWidget {
  const ExampleForm({super.key});
  @override
  State<ExampleForm> createState() => _ExampleFormState();
}

class _ExampleFormState extends State<ExampleForm> {
  final _controller = TextEditingController();
  String? _error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(children: [
          TextField(
            key: const Key('titleField'),
            controller: _controller,
            decoration: InputDecoration(errorText: _error),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _error = _controller.text.trim().isEmpty ? 'العنوان مطلوب' : null;
              });
            },
            child: const Text('حفظ'),
          ),
        ]),
      ),
    );
  }
}

void main() {
  testWidgets('Shows error when empty title on save', (tester) async {
    await tester.pumpWidget(const ExampleForm());
    await tester.tap(find.text('حفظ'));
    await tester.pump();
    expect(find.text('العنوان مطلوب'), findsOneWidget);
  });
}
