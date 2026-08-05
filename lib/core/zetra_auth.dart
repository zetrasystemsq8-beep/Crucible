import 'package:supabase_flutter/supabase_flutter.dart';

class ZetraProfile {
  final String id;
  final String zetramail;
  final String username;
  final bool verified;
  final String? avatarUrl;

  ZetraProfile({
    required this.id,
    required this.zetramail,
    required this.username,
    required this.verified,
    this.avatarUrl,
  });

  factory ZetraProfile.fromMap(Map<String, dynamic> map) {
    return ZetraProfile(
      id: map['id'] as String,
      zetramail: map['zetramail'] as String? ?? '',
      username: map['username'] as String? ?? '',
      verified: map['verified'] as bool? ?? false,
      avatarUrl: map['avatar_url'] as String?,
    );
  }
}

class ZetraAuthException implements Exception {
  final String message;
  ZetraAuthException(this.message);
  @override
  String toString() => message;
}

/// Crucible's client of the shared Zetra ecosystem auth (same backend as
/// NaijaLearn). Uses the same resolve_login_email / request_otp /
/// verify_otp RPCs and profiles table. The OTP-verified flag is stored
/// under an app-specific metadata key ('cru_otp_verified') — NOT shared
/// with NaijaLearn's 'nl_otp_verified' — so completing the code step in
/// one app never silently satisfies it in another.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const String invalidCredentialsMessage = 'Invalid ZetraMail or password.';
  static const String invalidOtpMessage = 'Invalid or expired code. Please try again.';
  static const String profileLoadErrorMessage = 'Could not load your profile. Please try again.';

  static const String _otpVerifiedMetaKey = 'cru_otp_verified';

  SupabaseClient get _client => Supabase.instance.client;

  ZetraProfile? currentProfile;

  bool get isSignedIn => _client.auth.currentSession != null;

  bool get isOtpVerifiedForCurrentSession =>
      _client.auth.currentUser?.userMetadata?[_otpVerifiedMetaKey] == true;

  bool get isFullyAuthenticated => isSignedIn && isOtpVerifiedForCurrentSession;

  Future<ZetraProfile> login({required String zetramail, required String password}) async {
    final normalized = zetramail.trim().toLowerCase();
    if (normalized.isEmpty) throw ZetraAuthException(invalidCredentialsMessage);

    String? resolvedEmail;
    try {
      final result = await _client.rpc('resolve_login_email', params: {'p_identifier': normalized});
      resolvedEmail = result is String ? result : null;
    } on PostgrestException {
      throw ZetraAuthException(invalidCredentialsMessage);
    }

    if (resolvedEmail == null || resolvedEmail.isEmpty) {
      throw ZetraAuthException(invalidCredentialsMessage);
    }

    AuthResponse response;
    try {
      response = await _client.auth.signInWithPassword(email: resolvedEmail, password: password);
    } on AuthException {
      throw ZetraAuthException(invalidCredentialsMessage);
    }

    final user = response.user;
    if (user == null) throw ZetraAuthException(invalidCredentialsMessage);

    try {
      await _client.auth.updateUser(UserAttributes(data: {_otpVerifiedMetaKey: false}));
    } catch (_) {}

    final profile = await loadCurrentProfile();

    try {
      await _client.rpc('request_otp');
    } on PostgrestException {
      throw ZetraAuthException('Could not send your verification code. Please try again.');
    }

    return profile;
  }

  Future<ZetraProfile> loadCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) throw ZetraAuthException('Not signed in.');

    Map<String, dynamic>? row;
    try {
      row = await _client.from('profiles').select().eq('id', user.id).maybeSingle();
    } on PostgrestException {
      throw ZetraAuthException(profileLoadErrorMessage);
    }

    if (row == null) throw ZetraAuthException(profileLoadErrorMessage);

    currentProfile = ZetraProfile.fromMap(row);
    return currentProfile!;
  }

  Future<ZetraProfile> verifyCode({required String code}) async {
    final session = _client.auth.currentSession;
    if (session == null) throw ZetraAuthException("You're not signed in. Please log in again.");

    dynamic result;
    try {
      result = await _client.rpc('verify_otp', params: {'p_code': code.trim()});
    } on PostgrestException {
      throw ZetraAuthException(invalidOtpMessage);
    }

    if (result != true) throw ZetraAuthException(invalidOtpMessage);

    try {
      await _client.auth.updateUser(UserAttributes(data: {_otpVerifiedMetaKey: true}));
    } catch (_) {}

    return loadCurrentProfile();
  }

  Future<void> resendCode() async {
    final session = _client.auth.currentSession;
    if (session == null) throw ZetraAuthException("You're not signed in. Please log in again.");
    try {
      await _client.rpc('request_otp');
    } on PostgrestException {
      throw ZetraAuthException('Could not resend code. Please try again.');
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.updateUser(UserAttributes(data: {_otpVerifiedMetaKey: false}));
    } catch (_) {}
    currentProfile = null;
    await _client.auth.signOut();
  }
}
