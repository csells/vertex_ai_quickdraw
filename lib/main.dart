import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:signature/signature.dart';

import 'drawings.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(App());
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  Widget build(BuildContext context) => MaterialApp(home: HomePage());
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final _controller = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.red,
    exportBackgroundColor: Colors.white,
    exportPenColor: Colors.black,
    onDrawEnd: () => _recognize(),
  );

  final _provider = VertexProvider(
    generativeModel: FirebaseVertexAI.instance.generativeModel(
      model: 'gemini-1.5-flash-002',
      systemInstruction: Content.text(
        'You are an expert in recognizing hand-drawn images. You will be '
        'given an image of a hand-drawn figure and you will recognize it.'
        'Your response should be the name of the object in the image.'
        'The choices will be from the following list: $drawings '
        'Your response should be the name of the object in the image. '
        'If you are sure of your answer, respond with the name followed by '
        '"." (a period). If you are not sure, respond with what you think '
        'the answer is followed by "?" (a question mark).',
      ),
    ),
  );

  final _random = Random();
  late String _currentDrawing;
  late String _currentResponse;

  @override
  void initState() {
    super.initState();
    _nextDrawing();
  }

  void _nextDrawing() => setState(
        () {
          _currentDrawing = drawings[_random.nextInt(drawings.length)];
          _currentResponse = '';
        },
      );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Vertex AI Quickdraw!')),
        body: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Text('Draw a $_currentDrawing'),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Signature(
                    controller: _controller,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              Text(_currentResponse),
            ],
          ),
        ),
      );

  Future<void> _recognize() async {
    final image = await _controller.toPngBytes();
    if (image == null) return;

    final response = await _provider.generateStream(
      'recognize the attached image',
      attachments: [
        ImageFileAttachment(
          name: 'drawing.png',
          mimeType: 'image/png',
          bytes: image,
        )
      ],
    ).join();

    setState(() => _currentResponse = response.trim());
  }
}
