# Deprecated

This repo has been archived in favor of the one in the FirebaseExtended org: https://github.com/FirebaseExtended/ai-quickdraw-flutter

# Vertex AI Quickdraw

The vertex_ai_quickdraw repository contains a sample app showcasing the power of Firebase Vertex AI. It's written using Flutter and [the Vertex AI in Firebase Flutter package](https://pub.dev/packages/firebase_vertexai).

Inspired by [Quick, Draw!](https://quickdraw.withgoogle.com/), the quickdraw sample app users the LLM to recognize your line drawings and compare it against a target figure you're asked to draw in 20 seconds or less.

Enjoy!

# Getting Started

This sample relies on a Firebase project, which you then initialize in your app. You can learn how to set that up with the steps described in [the Get started with the Gemini API using the Vertex AI in Firebase SDKs docs](https://firebase.google.com/docs/vertex-ai/get-started?platform=flutter).

# Usage

To use quickdraw, follow along with what the app is asking you to draw. When Vertex AI recognizes it, you win!

![screencap](README/screencap.gif)

# Implementation details

The quickdraw sample interacts with Vertex AI in the `_recognize` function:

```dart
class _HomePageState extends State<HomePage> {
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

  ...

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
}
```

As the user draws, each stroke triggers a call to `_recognize`. You can see from the initialization of the Vertex model that it's been instructed to recognize drawings from a list of ~200 potential figures, e.g. pen, umbrella, dog, etc. With this instructions in place, the `_recognize` function bundles the image that the user produced with a prompt to recogize the image. And because the Flash model is so fast, it can do this between strokes, never slowing down the user as they draw.


# Multi-platform

This sample has been tested and works on all supported Firebase platforms: Android, iOS, web and macOS.

# Feedback

Are you having trouble with this app even after it's been configured correctly? Feel free to drop issues or, even better, PRs, into [the vertex_ai_quickdraw repo](https://github.com/csells/vertex_ai_quickdraw).
