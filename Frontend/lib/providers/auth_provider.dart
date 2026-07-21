// lib/providers/auth_provider.dart
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/auth_response.dart';
import '../data/models/user_model.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.read(authServiceProvider);
  return AuthNotifier(authService);
});

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final UserModel? user;
  final String? error;
  final AuthResponse? authResponse;
  final bool isInitialized; // ✅ جديد: للتأكد من التهيئة

  AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.user,
    this.error,
    this.authResponse,
    this.isInitialized = false, // ✅ جديد
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    UserModel? user,
    bool clearUser = false,
    String? error,
    bool clearError = false,
    AuthResponse? authResponse,
    bool clearAuthResponse = false,
    bool? isInitialized,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: clearUser ? null : (user ?? this.user),
      error: clearError ? null : (error ?? this.error),
      authResponse: clearAuthResponse ? null : (authResponse ?? this.authResponse),
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(AuthState()) {
    // ✅ التحقق من حالة المستخدم بشكل غير متزامن
    _checkAuth();
  }

  // ✅ تعديل _checkAuth ليكون Future
  Future<void> _checkAuth() async {
    try {
      final isLoggedIn = await _authService.isLoggedIn();
      final user = await _authService.getCurrentUser();

      if (isLoggedIn && user != null) {
        state = state.copyWith(
          isAuthenticated: true,
          user: user,
          isInitialized: true,
        );
      } else {
        state = state.copyWith(isInitialized: true);
      }
    } catch (e) {
      // في حالة الخطأ، اعتبر أن المستخدم غير مسجل دخول
      state = state.copyWith(
        isAuthenticated: false,
        clearUser: true,
        isInitialized: true,
        error: 'Error checking auth state',
      );
    }
  }

  // ✅ دالة للتحقق من التهيئة
  Future<void> initialize() async {
    await _checkAuth();
  }

  // ✅ دالة verifyOTP (موجودة بالفعل)
  Future<void> verifyOTP({
    required String email,
    required String otp,
    String type = 'Verification',
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _authService.verifyOTP(
        email: email,
        otp: otp,
        type: type,
      );

      state = state.copyWith(
        isLoading: false,
        authResponse: response,
        error: response.message,
        clearError: response.success,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'An unexpected error occurred',
      );
    }
  }

  // Signup
  Future<void> signup({
    required String fullName,
    required String email,
    required String password,
    String? phone,
    String role = 'Customer',
    String? businessType, // ✅ جديد
    String? companyId, // ✅ جديد
    String? city,
    String? region,
    String? locationAddress,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _authService.signup(
        fullName: fullName,
        email: email,
        password: password,
        phone: phone,
        role: role,
        businessType: businessType, // ✅ جديد
        companyId: companyId, // ✅ جديد
        city: city,
        region: region,
        locationAddress: locationAddress,
      );

      state = state.copyWith(
        isLoading: false,
        authResponse: response,
        error: response.message,
        clearError: response.success,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'An unexpected error occurred',
      );
    }
  }

  // Verify Signup
  Future<void> verifySignup({
    required String email,
    required String otp,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _authService.verifySignup(
        email: email,
        otp: otp,
      );

      if (response.success && response.user != null) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          user: response.user,
          authResponse: response,
          clearError: true,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          authResponse: response,
          error: response.message,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'An unexpected error occurred',
      );
    }
  }

  // Resend OTP
  Future<void> resendOTP({required String email}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _authService.resendOtp(email: email);

      state = state.copyWith(
        isLoading: false,
        authResponse: response,
        error: response.message,
        clearError: response.success,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'An unexpected error occurred',
      );
    }
  }

  // Login
  Future<void> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _authService.login(
        email: email,
        password: password,
      );

      if (response.success && response.user != null) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          user: response.user,
          authResponse: response,
          clearError: true,
        );
      } else if (response.requireVerification == true) {
        state = state.copyWith(
          isLoading: false,
          authResponse: response,
          error: response.message,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          authResponse: response,
          error: response.message,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'An unexpected error occurred',
      );
    }
  }

  // Logout
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);

    try {
      await _authService.logout();

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        clearUser: true,
        clearAuthResponse: true,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        clearUser: true,
        clearAuthResponse: true,
        clearError: true,
      );
    }
  }

  // Forgot Password
  Future<void> forgotPassword({required String email}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _authService.forgotPassword(email: email);

      state = state.copyWith(
        isLoading: false,
        authResponse: response,
        error: response.message,
        clearError: response.success,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'An unexpected error occurred',
      );
    }
  }

  // Reset Password
  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _authService.resetPassword(
        email: email,
        otp: otp,
        newPassword: newPassword,
      );

      state = state.copyWith(
        isLoading: false,
        authResponse: response,
        error: response.message,
        clearError: response.success,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'An unexpected error occurred',
      );
    }
  }

  // Get Profile
  Future<void> getProfile() async {
    state = state.copyWith(isLoading: true);

    try {
      final response = await _authService.getProfile();

      if (response.success && response.data != null) {
        state = state.copyWith(
          isLoading: false,
          user: response.data,
          clearError: true,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.message,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'An unexpected error occurred',
      );
    }
  }

  // Update Profile
  Future<void> updateProfile({
    String? fullName,
    String? phone,
    String? locationAddress,
    String? city,
    String? region,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _authService.updateProfile(
        fullName: fullName,
        phone: phone,
        locationAddress: locationAddress,
        city: city,
        region: region,
      );

      if (response.success && response.data != null) {
        state = state.copyWith(
          isLoading: false,
          user: response.data,
          clearError: true,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.message,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'An unexpected error occurred',
      );
    }
  }

  // Change Password
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      state = state.copyWith(
        isLoading: false,
        error: response.message,
        clearError: response.success,
      );
      return response.success;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'An unexpected error occurred',
      );
      return false;
    }
  }

  // Upload Avatar
  Future<bool> uploadAvatar(File imageFile) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _authService.uploadAvatar(imageFile);

      if (response.success && response.data != null) {
        state = state.copyWith(
          isLoading: false,
          user: response.data,
          clearError: true,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.message,
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'An unexpected error occurred',
      );
      return false;
    }
  }

  // Clear error
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  // Reset auth response
  void resetAuthResponse() {
    state = state.copyWith(clearAuthResponse: true);
  }

  // ✅ دالة للتحقق مما إذا كان المستخدم مسجل دخول (مزامنة)
  bool get isAuthenticatedSync => state.isAuthenticated;
}