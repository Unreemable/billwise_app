import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'src/gemini_service.dart';

class GeminiDemoPage extends StatefulWidget {
  const GeminiDemoPage({super.key});

  @override
  State<GeminiDemoPage> createState() => _GeminiDemoPageState();
}

class _GeminiDemoPageState extends State<GeminiDemoPage> {
  final _ctrl = TextEditingController(text: 'Say hello in Arabic.');
  String _output = '';
  bool _busy = false;

  Future<void> _runText() async {
    setState(() => _busy = true);
    try {
      final text = await GeminiService.i.generateText(_ctrl.text.trim());
      setState(() => _output = text);
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _runVision() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;

    setState(() => _busy = true);
    try {
      final bytes = await file.readAsBytes();
      final text = await GeminiService.i.describeImage(
        prompt: 'Describe the main information in this image.',
        imageBytes: Uint8List.fromList(bytes),
        mimeType: file.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg',
      );
      setState(() => _output = text);
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gemini (Demo)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: _ctrl, decoration: const InputDecoration(labelText: 'Prompt')),
          const SizedBox(height: 12),
          Row(children: [
            ElevatedButton(onPressed: _busy ? null : _runText, child: const Text('Generate Text')),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: _busy ? null : _runVision, child: const Text('Image → Text')),
          ]),
          const SizedBox(height: 16),
          if (_busy) const LinearProgressIndicator(),
          Expanded(
            child: SingleChildScrollView(child: SelectableText(_output)),
          ),
        ]),
      ),
    );
  }
}
