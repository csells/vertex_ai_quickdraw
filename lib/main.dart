import 'dart:async';
import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart' as fat;
import 'package:flutter_ai_toolkit/src/providers/interface/attachments.dart';
import 'package:signature/signature.dart';

import 'drawings.dart';
import 'firebase_options.dart';

enum GameState {
  idle,
  drawing,
  checking,
  success,
  timeOut,
  gameOver,
}

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
  // Drawing controller
  late final SignatureController _controller;

  // Vertex provider for recognition
  late final fat.VertexProvider _provider;

  // Random object selection
  final _random = Random();

  // Current target object to draw
  late String _currentDrawing;

  // The AI’s latest response
  String _currentResponse = '';

  // Game state
  GameState _gameState = GameState.idle;

  // Timer
  Timer? _roundTimer;
  int _timeLeft = 20; // seconds per round

  // Score or round count can be tracked if you like
  int _score = 0;
  int _roundsPlayed = 0;

  @override
  void initState() {
    super.initState();
    _controller = SignatureController(
      penStrokeWidth: 2,
      penColor: Colors.red,
      exportBackgroundColor: Colors.white,
      exportPenColor: Colors.black,
      // Once player finishes a stroke, we initiate recognition
      onDrawEnd: () async {
        if (_gameState == GameState.drawing) {
          setState(() {
            _gameState = GameState.checking;
          });
          await _recognize();
        }
      },
    );

    _provider = fat.VertexProvider(
      generativeModel: FirebaseVertexAI.instance.generativeModel(
        model: 'gemini-1.5-flash-002',
        systemInstruction: Content.text(
            'You are an expert in recognizing hand-drawn images. '
            'You will be given an image of a hand-drawn figure and you will recognize it. '
            'Your response should be the name of the object in the image. '
            'The choices will be from the following list: $drawings '
            'If you are sure of your answer, respond with the name followed by "." '
            'If not sure, respond with "?" at the end.'),
      ),
    );

    _startGame();
  }

  void _startGame() {
    // Move to the first round
    _nextDrawing();
  }

  void _nextDrawing() {
    setState(() {
      _currentDrawing = drawings[_random.nextInt(drawings.length)];
      _currentResponse = '';
      _controller.clear();
      _gameState = GameState.drawing;
      _timeLeft = 20;
    });

    // Start the timer for the round
    _startTimer();
  }

  void _startTimer() {
    _roundTimer?.cancel();
    _roundTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _timeLeft--;
        if (_timeLeft <= 0) {
          // Time’s up
          _roundTimer?.cancel();
          if (_gameState == GameState.drawing ||
              _gameState == GameState.checking) {
            _gameState = GameState.timeOut;
          }
        }
      });
    });
  }

  Future<void> _recognize() async {
    if (_gameState != GameState.checking) return;
    final image = await _controller.toPngBytes();
    if (image == null) {
      // If no image to recognize, just return
      setState(() {
        _gameState = GameState.drawing;
      });
      return;
    }

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

    final trimmedResponse = response.trim();
    setState(() {
      _currentResponse = trimmedResponse;
    });

    // Check correctness
    _checkCorrectness(trimmedResponse);
  }

  void _checkCorrectness(String response) {
    if (_timeLeft <= 0) {
      // If time already ran out, just mark timeout
      setState(() {
        _gameState = GameState.timeOut;
      });
      return;
    }

    // Basic correctness check:
    // If response contains the target object name followed by '.', consider it correct.
    // This matches the instructions you gave the model.
    final targetLower = _currentDrawing.toLowerCase();
    final responseLower = response.toLowerCase();

    if (responseLower.contains(targetLower) && responseLower.endsWith('.')) {
      // Correct guess
      setState(() {
        _gameState = GameState.success;
        _score++;
        _roundsPlayed++;
      });

      // Proceed to the next object after a short delay
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        _nextDrawing();
      });
    } else {
      // If it didn’t guess correctly, let the user keep drawing until time runs out
      // The user can try redrawing or continuing.
      // Just go back to drawing state if time is still left
      if (_timeLeft > 0) {
        setState(() {
          _gameState = GameState.drawing;
        });
      }
    }
  }

  void _restartGame() {
    setState(() {
      _score = 0;
      _roundsPlayed = 0;
    });
    _startGame();
  }

  @override
  void dispose() {
    _controller.dispose();
    _roundTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    // Choose UI based on _gameState
    switch (_gameState) {
      case GameState.idle:
        body = Center(
          child: ElevatedButton(
            onPressed: _startGame,
            child: const Text('Start Game'),
          ),
        );
        break;
      case GameState.drawing:
      case GameState.checking:
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Draw a $_currentDrawing',
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text('Time Left: $_timeLeft sec',
                style: const TextStyle(fontSize: 16)),
            Text('Score: $_score', style: const TextStyle(fontSize: 16)),
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
        );
        break;
      case GameState.success:
        body = Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Success! The AI correctly identified $_currentDrawing.',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold)),
              Text('Score: $_score'),
              const SizedBox(height: 20),
              const Text('Loading next object...'),
            ],
          ),
        );
        break;
      case GameState.timeOut:
        body = Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Time’s Up!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Text('You drew: $_currentDrawing'),
              Text('Score: $_score'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _gameState = GameState.gameOver;
                  });
                },
                child: const Text('Continue'),
              )
            ],
          ),
        );
        break;
      case GameState.gameOver:
        body = Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Game Over!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Text('Final Score: $_score'),
              ElevatedButton(
                onPressed: _restartGame,
                child: const Text('Restart'),
              ),
            ],
          ),
        );
        break;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Vertex AI Quickdraw!')),
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: body,
      ),
    );
  }
}
