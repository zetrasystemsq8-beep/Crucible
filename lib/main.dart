import 'package:flutter/material.dart';
import 'core/groq_client.dart';
import 'features/vault/vault_feature.dart';
import 'features/vault/vault_screen.dart';

void main() {
  runApp(const CrucibleApp());
}

class CrucibleApp extends StatelessWidget {
  const CrucibleApp({super.key});

  @override
  Widget build(BuildContext context) {
    const groqApiKey = String.fromEnvironment('GROQ_API_KEY');
    final client = GroqClient(apiKey: groqApiKey);
    final vault = VaultController(repository: VaultRepository());

    return MaterialApp(
      title: 'Crucible',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFFE0272E),
        scaffoldBackgroundColor: const Color(0xFF0B0C10),
      ),
      home: VaultScreen(client: client, vault: vault),
    );
  }
}
