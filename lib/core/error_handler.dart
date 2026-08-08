import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'zetra_auth.dart';

const String noConnectionMessage = "No internet connection. Check your network and try again.";

/// Converts a caught exception into a short, non-technical message safe
/// to show in the UI — never raw exception text or stack traces.
String friendlyMessage(Object error) {
  if (error is ZetraAuthException) return error.message;
  if (error is SocketException) return noConnectionMessage;
  if (error is TimeoutException) return "That took too long to respond. Try again.";
  if (error is HttpException) return "Couldn't reach the server. Try again in a moment.";
  if (error is PostgrestException) return "Something went wrong saving your data. Try again.";
  if (error is AuthException) return "Your session has a problem — try logging in again.";
  if (error is FormatException) return "Received an unexpected response. Try again.";

  final text = error.toString();
  if (text.contains('SocketException') || text.contains('Failed host lookup')) {
    return noConnectionMessage;
  }
  if (text.contains('TimeoutException')) {
    return "That took too long to respond. Try again.";
  }
  if (text.contains('429')) {
    return "Zetra is getting a lot of requests right now — wait a moment and try again.";
  }
  if (text.contains('401') || text.contains('403')) {
    return "Couldn't authenticate with the AI service. Try again later.";
  }
  if (text.contains('500') || text.contains('502') || text.contains('503')) {
    return "The AI service is temporarily unavailable. Try again shortly.";
  }

  return "Something went wrong. Please try again.";
}

/// App-wide crash handling: widget build errors show a plain fallback
/// screen instead of the red "exception" box, and uncaught Flutter
/// framework errors are logged instead of silently crashing.
void setupGlobalErrorHandling() {
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0C10),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.error_outline_rounded, color: Colors.white38, size: 40),
              SizedBox(height: 12),
              Text("Something went wrong displaying this screen.",
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  };

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[Crucible] Flutter error: ${details.exceptionAsString()}');
  };
}
