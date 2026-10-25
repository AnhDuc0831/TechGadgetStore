import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Web Client ID lấy từ Google Cloud Console (dùng để xác thực backend Supabase)
  static const String? webClientId = null;

  User? get currentUser => _supabase.auth.currentUser;
  Session? get currentSession => _supabase.auth.currentSession;
  String? get accessToken => _supabase.auth.currentSession?.accessToken;
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Đăng nhập bằng Google qua Supabase
  Future<AuthResponse> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Nền tảng Web: sử dụng OAuth redirect
        await _supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: kIsWeb ? null : 'io.supabase.techgadget://login-callback/',
        );
        return AuthResponse(session: _supabase.auth.currentSession);
      }

      // Nền tảng Mobile (Android / iOS): Sử dụng GoogleSignIn lấy idToken
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: webClientId,
        scopes: ['email', 'profile'],
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw const AuthException('Đã hủy đăng nhập Google.');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        // Fallback sang Browser OAuth nếu chưa thiết lập Web Client ID
        await _supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'io.supabase.techgadget://login-callback/',
        );
        return AuthResponse(session: _supabase.auth.currentSession);
      }

      return await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(e.toString());
    }
  }

  /// Đăng nhập bằng Email/Password
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Đăng ký bằng Email/Password
  Future<AuthResponse> signUpWithEmail(String email, String password, {String? fullName}) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
      data: fullName != null ? {'full_name': fullName} : null,
    );
  }

  /// Đăng xuất toàn bộ tài khoản
  Future<void> signOut() async {
    try {
      final googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
      }
    } catch (_) {}
    await _supabase.auth.signOut();
  }
}
