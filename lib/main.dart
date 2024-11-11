import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:signature/signature.dart';

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
  // initialize the signature controller
  final _controller = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.red,
    exportBackgroundColor: Colors.white,
    exportPenColor: Colors.black,
    onDrawStart: () => debugPrint('onDrawStart called!'),
    onDrawEnd: () => debugPrint('onDrawEnd called!'),
  );

  @override
  void initState() {
    super.initState();
    _controller
      ..addListener(() => debugPrint('Value changed'))
      ..onDrawEnd = () => setState(
            () {
              // setState for build to update value of "empty label" in gui
            },
          );
  }

  @override
  void dispose() {
    // IMPORTANT to dispose of the controller
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Vertex AI Quickdraw!')),
        body: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Signature(
                  key: const Key('signature'),
                  controller: _controller,
                  backgroundColor: Colors.grey[300]!,
                ),
              ),
            ),
            Text(_controller.isEmpty
                ? "Signature pad is empty"
                : "Signature pad is not empty"),
          ],
        ),
        bottomNavigationBar: BottomAppBar(
          child: Container(
            decoration: const BoxDecoration(color: Colors.black),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              mainAxisSize: MainAxisSize.max,
              children: [
                IconButton(
                  key: const Key('exportPNG'),
                  icon: const Icon(Icons.image),
                  color: Colors.blue,
                  onPressed: _exportImage,
                  tooltip: 'Export Image',
                ),
                IconButton(
                  key: const Key('exportSVG'),
                  icon: const Icon(Icons.share),
                  color: Colors.blue,
                  onPressed: _exportSVG,
                  tooltip: 'Export SVG',
                ),
                IconButton(
                  icon: const Icon(Icons.undo),
                  color: Colors.blue,
                  onPressed: _undo,
                  tooltip: 'Undo',
                ),
                IconButton(
                  icon: const Icon(Icons.redo),
                  color: Colors.blue,
                  onPressed: _redo,
                  tooltip: 'Redo',
                ),
                IconButton(
                  key: const Key('clear'),
                  icon: const Icon(Icons.clear),
                  color: Colors.blue,
                  onPressed: _clear,
                  tooltip: 'Clear',
                ),
                IconButton(
                  icon: const Icon(Icons.remove_red_eye),
                  color: Colors.blue,
                  onPressed: _recognize,
                  tooltip: 'Recognize',
                ),
              ],
            ),
          ),
        ),
      );

  Future<void> _exportImage() async {
    if (_controller.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          key: Key('snackbarPNG'),
          content: Text('No content'),
        ),
      );
      return;
    }

    final data = await _controller.toPngBytes();
    if (data == null) return;

    if (!mounted) return;
    await _push(
      context,
      Scaffold(
        appBar: AppBar(
          title: const Text('PNG Image'),
        ),
        body: Center(
          child: Container(
            color: Colors.grey[300],
            child: Image.memory(data),
          ),
        ),
      ),
    );
  }

  Future<void> _exportSVG() async {
    if (_controller.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          key: Key('snackbarSVG'),
          content: Text('No content'),
        ),
      );
      return;
    }

    final SvgPicture data = _controller.toSVG()!;

    if (!mounted) return;
    await _push(
      context,
      Scaffold(
        appBar: AppBar(
          title: const Text('SVG Image'),
        ),
        body: Center(
          child: Container(
            color: Colors.grey[300],
            child: data,
          ),
        ),
      ),
    );
  }

  /// Pushes a widget to a new route.
  Future _push(BuildContext context, Widget widget) =>
      Navigator.of(context).push(
        MaterialPageRoute(builder: (BuildContext context) => widget),
      );

  void _clear() => setState(() => _controller.clear());
  void _undo() => setState(() => _controller.undo());
  void _redo() => setState(() => _controller.redo());

  Future<void> _recognize() async {
    final image = await _controller.toPngBytes();
    if (image == null) return;

    final svg = _controller.toSVG();

    final provider = VertexProvider(
      generativeModel: FirebaseVertexAI.instance.generativeModel(
        model: 'gemini-1.5-flash-002',
        systemInstruction: Content.text(
          'You are an expert in recognizing hand-drawn images. You will be '
          'given an image of a hand-drawn figure and you will recognize it.'
          'Your response should be the name of the object in the image.'
          'The choices will be from the following list: '
          'apple, banana, cat, dog, elephant, fish, horse, lion, monkey, '
          'orange, pear, pineapple, strawberry, tiger, watermelon',
        ),
      ),
    );

    await File('/Users/csells/Downloads/image.png').writeAsBytes(image);
    // await File('/Users/csells/Downloads/image.svg').writeAsString(svg.);

    final attachment = ImageFileAttachment(
      name: 'image.png',
      mimeType: 'image/png',
      bytes: image,
    );

    final stream = provider.generateStream(
      'what is the attached image?',
      attachments: [attachment],
    );

    final response = await stream.join();
    debugPrint(response);
  }
}
