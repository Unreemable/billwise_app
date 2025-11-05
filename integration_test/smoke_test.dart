import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  // استخدمي Binding الخاصة بالتكامل
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('smoke: builds and increments with setState', (tester) async {
    // ويدجت Stateful بسيطة
    final widget = MaterialApp(
      home: _CounterPage(),
    );

    await tester.pumpWidget(widget);

    expect(find.text('count: 0'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump(); // إطار واحد يكفي

    expect(find.text('count: 1'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30))); // سقف زمني واضح
}

class _CounterPage extends StatefulWidget {
  @override
  State<_CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<_CounterPage> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Integration Smoke')),
      body: Center(child: Text('count: $_count')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _count++),
        child: const Icon(Icons.add),
      ),
    );
  }
}
