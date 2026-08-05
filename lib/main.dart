import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/groq_client.dart';
import 'core/zetra_auth.dart';
import 'features/vault/vault_feature.dart';
import 'features/vault/vault_screen.dart';
import 'features/auth/auth_screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  final groqApiKey = dotenv.env['GROQ_API_KEY']!;
  final client = GroqClient(apiKey: groqApiKey);
  final vault = VaultController(repository: VaultRepository());

  runApp(CrucibleApp(client: client, vault: vault));
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
