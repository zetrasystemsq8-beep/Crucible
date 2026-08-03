import 'package:flutter/material.dart';
import 'core/groq_client.dart';
import 'features/crucible/crucible_feature.dart';
import 'features/crucible/crucible_screen.dart';

void main() {
  runApp(const CrucibleApp());
}

class CrucibleApp extends StatelessWidget {
  const CrucibleApp({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: replace with your actual Groq API key, ideally loaded from
    // a secure source (--dart-define, env var, secrets manager) —
    // never hardcode a real key in source control.
    const groqApiKey = String.fromEnvironment('GROQ_API_KEY');

    final client = GroqClient(apiKey: groqApiKey);
    final controller = CrucibleController(client: client);

    return MaterialApp(
      title: 'Crucible',
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: CrucibleScreen(controller: controller),
    );
  }
}
