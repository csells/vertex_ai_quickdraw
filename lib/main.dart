import 'dart:async';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

import 'drawings.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MaterialApp(home: HomePage()));
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _normal16style = TextStyle(fontSize: 16);
  static const _bold24style = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  late final _controller = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.red,
    exportBackgroundColor: Colors.white,
    exportPenColor: Colors.black,
    onDrawEnd: _recognize,
  );

  final _model = FirebaseVertexAI.instance.generativeModel(
    model: 'gemini-1.5-flash-002',
    systemInstruction: Content.text(
        'You are an expert in recognizing hand-drawn images. '
        'You will be given an image of a hand-drawn figure and you will '
        'recognize it. Your response should be the name of the object in the '
        'image. The choices will be from the following list: $drawings '
        'If you are sure of your answer, respond with the name followed '
        'by "." If not sure, respond with "?" at the end.'),
  );

  static const _roundDuration = Duration(seconds: 21);
  final _random = Random();
  String _currentDrawing = '';
  String _currentResponse = '';
  Timer? _timer;
  DateTime? _timerStart;
  var _score = 0;
  var _rounds = 0;

  Duration get _timeLeft => _timerStart == null
      ? Duration.zero
      : _roundDuration - DateTime.now().difference(_timerStart!);

  @override
  void initState() {
    super.initState();

    // move to the first round
    _nextDrawing();
  }

  void _nextDrawing() {
    setState(() {
      _rounds++;
      _currentDrawing = drawings[_random.nextInt(drawings.length)];
      _currentResponse = '';
      _controller.clear();
      _timerStart = DateTime.now();
    });

    // start the timer for the round
    assert(_timer == null);
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(
        () => unawaited(
          (_timeLeft <= Duration.zero ? _lose : null)?.call(),
        ),
      ),
    );
  }

  Future<void> _recognize() async {
    // the round is over, ignore the current drawing
    if (_timeLeft <= Duration.zero) return;

    // if no image to recognize, just return
    final image = await _controller.toPngBytes();
    if (image == null) return;

    final response = await _model.generateContent([
      Content.text('recognize the attached image'),
      Content.inlineData('image/png', image),
    ]);

    // if response matches the target object name, we have a winner!
    setState(() => _currentResponse = response.text?.trim() ?? '');
    if (_currentResponse
        .substring(0, _currentResponse.length - 1)
        .contains(_currentDrawing)) {
      await _win();
    }
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
    _timerStart = null;
  }

  Future<void> _lose() async {
    _cancelTimer();
    await _notifyUser('Time is up!');
    _nextDrawing();
  }

  Future<void> _win() async {
    _cancelTimer();
    setState(() => _score++);
    await _notifyUser('You got it!');
    _nextDrawing();
  }

  Future<void> _notifyUser(String title) => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(
            'The AI was looking for: $_currentDrawing.'
            '\n\nThe AI found: $_currentResponse',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Vertex AI Quickdraw!')),
        body: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Draw:',
                style: _normal16style,
              ),
              Text(
                _currentDrawing,
                style: _bold24style,
              ),
              Text(
                'Time Left: ${_timeLeft.inSeconds} sec',
                style: _normal16style,
              ),
              Text(
                'Score: $_score/$_rounds',
                style: _normal16style,
              ),
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
}
