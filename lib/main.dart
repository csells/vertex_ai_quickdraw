import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
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
    penStrokeWidth: 1,
    penColor: Colors.red,
    exportBackgroundColor: Colors.transparent,
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

  Future<void> exportImage(BuildContext context) async {
    if (_controller.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          key: Key('snackbarPNG'),
          content: Text('No content'),
        ),
      );
      return;
    }

    final Uint8List? data = await _controller.toPngBytes(
      height: 1000,
      width: 1000,
    );
    if (data == null) return;

    if (!mounted) return;
    await _push(
      // ignore: use_build_context_synchronously
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

  Future<void> exportSVG(BuildContext context) async {
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
              children: <Widget>[
                //SHOW EXPORTED IMAGE IN NEW ROUTE
                IconButton(
                  key: const Key('exportPNG'),
                  icon: const Icon(Icons.image),
                  color: Colors.blue,
                  onPressed: () => exportImage(context),
                  tooltip: 'Export Image',
                ),
                IconButton(
                  key: const Key('exportSVG'),
                  icon: const Icon(Icons.share),
                  color: Colors.blue,
                  onPressed: () => exportSVG(context),
                  tooltip: 'Export SVG',
                ),
                IconButton(
                  icon: const Icon(Icons.undo),
                  color: Colors.blue,
                  onPressed: () {
                    setState(() => _controller.undo());
                  },
                  tooltip: 'Undo',
                ),
                IconButton(
                  icon: const Icon(Icons.redo),
                  color: Colors.blue,
                  onPressed: () {
                    setState(() => _controller.redo());
                  },
                  tooltip: 'Redo',
                ),
                //CLEAR CANVAS
                IconButton(
                  key: const Key('clear'),
                  icon: const Icon(Icons.clear),
                  color: Colors.blue,
                  onPressed: () {
                    setState(() => _controller.clear());
                  },
                  tooltip: 'Clear',
                ),
                // STOP Edit
                IconButton(
                  key: const Key('stop'),
                  icon: Icon(
                    _controller.disabled ? Icons.pause : Icons.play_arrow,
                  ),
                  color: Colors.blue,
                  onPressed: () {
                    setState(
                        () => _controller.disabled = !_controller.disabled);
                  },
                  tooltip: _controller.disabled ? 'Pause' : 'Play',
                ),
              ],
            ),
          ),
        ),
      );
}
