import 'dart:async';
import 'dart:io';

/// Lightweight connectivity check — no external package needed. A fast
/// DNS lookup with a short timeout. Doesn't guarantee the Groq API
/// itself is reachable, but reliably tells "no network at all" apart
/// from a real API failure, so the app can show the right message
/// BEFORE even attempting the request instead of waiting on a timeout.
Future<bool> hasInternetConnection() async {
  try {
    final result = await InternetAddress.lookup('api.groq.com')
        .timeout(const Duration(seconds: 4));
    return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
  } on SocketException {
    return false;
  } on TimeoutException {
    return false;
  } catch (_) {
    return false;
  }
}
