import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/groq_client.dart';
import 'core/error_handler.dart';
import 'features/vault/vault_feature.dart';
import 'features/auth/auth_screens.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    setupGlobalErrorHandling();

    await Supabase.initialize(
      url: const String.fromEnvironment('SUPABASE_URL'),
      anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
    );

    const groqApiKey = String.fromEnvironment('GROQ_API_KEY');
    final client = GroqClient(apiKey: groqApiKey);
    final vault = VaultController(repository: VaultRepository());

    runApp(CrucibleApp(client: client, vault: vault));
  }, (error, stack) {
    debugPrint('[Crucible] Uncaught error: $error');
  });
}

class CrucibleApp extends StatelessWidget {
  final GroqClient client;
  final VaultController vault;

  const CrucibleApp({super.key, required this.client, required this.vault});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crucible',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFFE0272E),
        scaffoldBackgroundColor: const Color(0xFF0B0C10),
      ),
      home: SplashScreen(client: client, vault: vault),
    );
  }
}
