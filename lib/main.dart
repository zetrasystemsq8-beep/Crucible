import 'package:flutter/material.dart';
import 'core/groq_client.dart';
import 'features/crucible/crucible_feature.dart';
import 'features/crucible/idea_canvas_screen.dart';

void main() {
  runApp(const CrucibleApp());
}

class CrucibleApp extends StatelessWidget {
  const CrucibleApp({super.key});

  @override
  Widget build(BuildContext context) {
    const groqApiKey = String.fromEnvironment('GROQ_API_KEY');
    final client = GroqClient(apiKey: groqApiKey);
    final controller = CrucibleController(client: client);

    return MaterialApp(
      title: 'Crucible',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.redAccent,
        scaffoldBackgroundColor: const Color(0xFF0F1115),
      ),
      home: IdeaCanvasScreen(controller: controller),
    );
  }
}
