import 'dart:convert';
import 'package:http/http.dart' as http;

/// One shared client for every Groq call in the app.
/// Zetra and Arbiter both go through this — different models,
/// different system prompts, same plumbing.
class GroqClient {
  GroqClient({required this.apiKey});

  final String apiKey;
  static const _endpoint = 'https://api.groq.com/openai/v1/chat/completions';

  /// [messages] uses standard role/content maps:
  /// {'role': 'system'|'user'|'assistant', 'content': '...'}
  Future<String> chat({
    required String model,
    required List<Map<String, String>> messages,
    double temperature = 0.7,
    int maxTokens = 1024,
  }) async {
    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'messages': messages,
        'temperature': temperature,
        'max_tokens': maxTokens,
      }),
    );

    if (response.statusCode != 200) {
      throw GroqException(
        'Groq request failed (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>;
    if (choices.isEmpty) {
      throw GroqException('Groq returned no choices for model $model');
    }
    final message = choices.first['message'] as Map<String, dynamic>;
    return (message['content'] as String).trim();
  }
}

class GroqException implements Exception {
  GroqException(this.message);
  final String message;

  @override
  String toString() => 'GroqException: $message';
}
