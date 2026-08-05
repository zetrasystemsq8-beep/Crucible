import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/groq_client.dart';
import '../../core/zetra_auth.dart';
import '../vault/vault_feature.dart';
import '../vault/vault_screen.dart';

const _bg = Color(0xFF0B0C10);
const _accent = Color(0xFFE0272E);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.client, required this.vault});
  final GroqClient client;
  final VaultController vault;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 900), _route);
  }

  Future<void> _route() async {
    final hasSession = Supabase.instance.client.auth.currentSession != null;
    Widget destination;

    if (hasSession && AuthService.instance.isOtpVerifiedForCurrentSession) {
      try {
        await AuthService.instance.loadCurrentProfile();
        destination = VaultScreen(client: widget.client, vault: widget.vault);
      } catch (_) {
        destination = LoginScreen(client: widget.client, vault: widget.vault);
      }
    } else if (hasSession) {
      // Session exists but the mandatory code step was never completed —
      // send back to VerifyOtpScreen WITHOUT requesting a new code.
      destination = VerifyOtpScreen(client: widget.client, vault: widget.vault);
    } else {
      destination = LoginScreen(client: widget.client, vault: widget.vault);
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => destination));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: _bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.diamond_outlined, color: _accent, size: 48),
            SizedBox(height: 16),
            Text('CRUCIBLE', style: TextStyle(color: Colors.white, letterSpacing: 4, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.client, required this.vault});
  final GroqClient client;
  final VaultController vault;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _zetramailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _zetramailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateZetraMail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Please enter your ZetraMail address';
    final emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
    if (!emailRegex.hasMatch(email)) return 'Please enter a valid email';
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Please enter your password';
    if (password.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _errorMessage = null; });

    try {
      await AuthService.instance.login(
        zetramail: _zetramailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => VerifyOtpScreen(client: widget.client, vault: widget.vault)),
        (route) => false,
      );
    } on ZetraAuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Could not sign in. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _continueAsGuest() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => VaultScreen(client: widget.client, vault: widget.vault)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 72, height: 72,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _accent, width: 1.5)),
                        child: const Icon(Icons.diamond_outlined, color: _accent, size: 32),
                      ),
                      const SizedBox(height: 20),
                      const Text('CRUCIBLE', textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 22, letterSpacing: 4, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('Sign in with your ZetraMail address', textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54, fontSize: 13)),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _zetramailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white),
                        validator: _validateZetraMail,
                        decoration: _inputDecoration('ZetraMail address', Icons.email_outlined),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: Colors.white),
                        validator: _validatePassword,
                        onFieldSubmitted: (_) => _continue(),
                        decoration: _inputDecoration('Password', Icons.lock_outline_rounded).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.white38),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(_errorMessage!, style: const TextStyle(color: _accent, fontSize: 13)),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: _accent),
                        onPressed: _loading ? null : _continue,
                        child: _loading
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                            : const Text('Log In', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _loading ? null : _continueAsGuest,
                      child: const Text('Continue as Guest', style: TextStyle(color: Colors.white54)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white38),
      prefixIcon: Icon(icon, color: Colors.white38),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
      focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: _accent)),
    );
  }
}

class VerifyOtpScreen extends StatefulWidget {
  const VerifyOtpScreen({super.key, required this.client, required this.vault});
  final GroqClient client;
  final VaultController vault;

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _loading = false;
  bool _resending = false;
  String? _errorMessage;

  static const int _cooldown = 30;
  int _secondsLeft = _cooldown;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _cooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_secondsLeft <= 1) { t.cancel(); setState(() => _secondsLeft = 0); }
      else { setState(() => _secondsLeft--); }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  String? _validateCode(String? value) {
    final code = value?.trim() ?? '';
    if (code.isEmpty) return 'Please enter the code';
    if (code.length < 4) return 'Enter the code from your ZetraMail';
    return null;
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _errorMessage = null; });

    try {
      await AuthService.instance.verifyCode(code: _codeController.text.trim());
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => VaultScreen(client: widget.client, vault: widget.vault)),
        (route) => false,
      );
    } on ZetraAuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Invalid or expired code. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0) return;
    setState(() { _resending = true; _errorMessage = null; });
    try {
      await AuthService.instance.resendCode();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A new code has been sent to your ZetraMail inbox.')));
      _startCooldown();
    } on ZetraAuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _useDifferentAccount() async {
    await AuthService.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen(client: widget.client, vault: widget.vault)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(backgroundColor: _bg, elevation: 0, title: const Text('Verify Your Zetra ID', style: TextStyle(color: Colors.white, fontSize: 15))),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.mark_email_read_rounded, size: 48, color: _accent),
                      const SizedBox(height: 20),
                      const Text('Open your ZetraMail in the Zetra ID app, copy the code, and paste it below.',
                          textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
                        validator: _validateCode,
                        onFieldSubmitted: (_) => _verify(),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '------',
                          hintStyle: const TextStyle(color: Colors.white24),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(_errorMessage!, style: const TextStyle(color: _accent, fontSize: 13), textAlign: TextAlign.center),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: _accent),
                        onPressed: _loading ? null : _verify,
                        child: _loading
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                            : const Text('Verify', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: (_resending || _secondsLeft > 0) ? null : _resend,
                      child: Text(
                        _resending ? '...' : (_secondsLeft > 0 ? 'Resend code in ${_secondsLeft}s' : "Didn't get a code? Resend"),
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ),
                    TextButton(
                      onPressed: _useDifferentAccount,
                      child: const Text('Use a different account', style: TextStyle(color: Colors.white38)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
