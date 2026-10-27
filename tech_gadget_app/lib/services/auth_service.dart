import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Web Client ID lấy từ Google Cloud Console (bắt buộc loại Web Application)
  static const String webClientId = '';

  User? get currentUser => _supabase.auth.currentUser;
  Session? get currentSession => _supabase.auth.currentSession;
  String? get accessToken => _supabase.auth.currentSession?.accessToken;
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Đăng nhập bằng Google 100% Native trong App (Không qua Web/Trình duyệt)
  Future<AuthResponse> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: webClientId,
        scopes: ['email', 'profile'],
      );

      // Xóa phiên cache trước đó để luôn hiển thị hộp thoại chọn tài khoản gốc của Android
      await googleSignIn.signOut().catchError((_) => null);

      // Kích hoạt hộp thoại Popup gốc Android (trồi lên từ cạnh dưới màn hình)
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw const AuthException('Đã hủy đăng nhập Google.');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        throw const AuthException(
          'Không thể lấy ID Token từ Google. Vui lòng kiểm tra cấu hình Web Client ID.',
        );
      }

      // Xác thực trực tiếp qua ID Token với Supabase (hoàn toàn Native trong App)
      return await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    } catch (e) {
      if (e is AuthException) rethrow;
      final err = e.toString();
      if (err.contains('ApiException: 10') || err.contains('sign_in_failed')) {
        throw const AuthException(
          'Lỗi xác thực Google (ApiException 10): Hãy đảm bảo Client ID Android trên Google Cloud đã điền đúng SHA-1 và Package Name.',
        );
      }
      throw AuthException(err);
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
