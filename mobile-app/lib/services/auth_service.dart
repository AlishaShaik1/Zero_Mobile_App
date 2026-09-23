import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  SupabaseClient get client => Supabase.instance.client;

  /// Returns true if a valid user session currently exists.
  bool get isLoggedIn => client.auth.currentSession != null;

  /// Gets the currently authenticated Supabase user.
  User? get currentUser => client.auth.currentUser;

  /// Gets the active session.
  Session? get currentSession => client.auth.currentSession;

  /// Gets the user's display name or email prefix.
  String get userName {
    final user = currentUser;
    if (user == null) return 'Guest';
    final name = user.userMetadata?['full_name'] as String?;
    if (name != null && name.trim().isNotEmpty) return name;
    if (user.email != null && user.email!.contains('@')) {
      return user.email!.split('@').first;
    }
    return 'Zero User';
  }

  /// Sign up user with email and password
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
  }) async {
    return await client.auth.signUp(
      email: email.trim(),
      password: password,
      data: fullName != null && fullName.isNotEmpty
          ? {'full_name': fullName.trim()}
          : null,
    );
  }

  /// Sign in user with email and password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Anonymous Sign-In fallback
  Future<AuthResponse> signInAnonymously() async {
    return await client.auth.signInAnonymously();
  }

  /// Sign out currently logged-in user
  Future<void> signOut() async {
    await client.auth.signOut();
  }

  /// Send password reset email
  Future<void> resetPassword(String email) async {
    await client.auth.resetPasswordForEmail(email.trim());
  }

  /// Stream of auth state changes (e.g. signedIn, signedOut, tokenRefreshed)
  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;
}
