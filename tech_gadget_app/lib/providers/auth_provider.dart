import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/profile_api_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final ProfileApiService _profileApiService = ProfileApiService();

  StreamSubscription<AuthState>? _authSubscription;

  User? _currentUser;
  UserProfile? _userProfile;
  bool _isLoading = false;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  UserProfile? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  AuthProvider() {
    _initAuthListener();
  }

  void _initAuthListener() {
    _currentUser = _authService.currentUser;
    if (_currentUser != null) {
      fetchProfile();
    }

    _authSubscription = _authService.authStateChanges.listen((data) {
      final session = data.session;
      _currentUser = session?.user;

      if (_currentUser != null) {
        fetchProfile();
      } else {
        _userProfile = null;
        notifyListeners();
      }
    });
  }

  /// Lấy thông tin hồ sơ từ .NET API
  Future<void> fetchProfile() async {
    final token = _authService.accessToken;
    if (token == null) return;

    try {
      _userProfile = await _profileApiService.getMyProfile(token);
      _errorMessage = null;
    } catch (e) {
      // Fallback: nếu .NET API chưa bật hoặc đang kết nối offline, dùng thông tin cơ bản từ Supabase User
      _userProfile = UserProfile(
        id: _currentUser!.id,
        fullName: _currentUser!.userMetadata?['full_name'] as String? ??
            _currentUser!.userMetadata?['name'] as String?,
        avatarUrl: _currentUser!.userMetadata?['avatar_url'] as String? ??
            _currentUser!.userMetadata?['picture'] as String?,
        phone: _currentUser!.phone,
        role: 'customer',
        createdAt: DateTime.tryParse(_currentUser!.createdAt) ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _errorMessage = 'Chưa thể đồng bộ từ .NET API: $e';
    }
    notifyListeners();
  }

  /// Đăng nhập bằng Google
  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _authService.signInWithGoogle();
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e is AuthException ? e.message : e.toString();
      _setLoading(false);
      return false;
    }
  }

  /// Đăng nhập bằng Email/Password
  Future<bool> signInWithEmail(String email, String password) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _authService.signInWithEmail(email, password);
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e is AuthException ? e.message : e.toString();
      _setLoading(false);
      return false;
    }
  }

  /// Đăng ký bằng Email/Password
  Future<bool> signUpWithEmail(String email, String password, {String? fullName}) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _authService.signUpWithEmail(email, password, fullName: fullName);
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e is AuthException ? e.message : e.toString();
      _setLoading(false);
      return false;
    }
  }

  /// Cập nhật thông tin Profile qua .NET API
  Future<bool> updateProfile({
    String? fullName,
    String? avatarUrl,
    String? phone,
  }) async {
    final token = _authService.accessToken;
    if (token == null) return false;

    _setLoading(true);
    try {
      _userProfile = await _profileApiService.updateMyProfile(
        token,
        fullName: fullName,
        avatarUrl: avatarUrl,
        phone: phone,
      );
      _errorMessage = null;
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  /// Đăng xuất tài khoản
  Future<void> signOut() async {
    _setLoading(true);
    await _authService.signOut();
    _currentUser = null;
    _userProfile = null;
    _setLoading(false);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
