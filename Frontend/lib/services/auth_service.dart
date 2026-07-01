// lib/services/auth_service.dart
import 'package:flutter/foundation.dart';
import '../core/constants/api_constants.dart';
import '../data/models/auth_response.dart';
import '../data/models/api_response.dart';
import '../data/models/user_model.dart';
import 'api_service.dart';
import 'storage_service.dart';

class AuthService {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();

  // Signup Initial
  Future<AuthResponse> signup({
    required String fullName,
    required String email,
    required String password,
    String? phone,
    String role = 'Customer',
    String? businessType,
    String? city,
    String? region,
    String? locationAddress,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConstants.signup,
        data: {
          'full_name': fullName,
          'email': email,
          'password': password,
          'phone': phone,
          'role': role,
          'businessType': businessType,
          'city': city,
          'region': region,
          'location_address': locationAddress,
        },
      );

      final authResponse = AuthResponse.fromJson(response.data);
      
      // Save temp token for verification
      if (authResponse.tempToken != null) {
        await _storageService.saveTempToken(authResponse.tempToken!);
      }
      
      return authResponse;
    } catch (e) {
      if (kDebugMode) {
        print('Signup error: $e');
      }
      return AuthResponse(
        success: false,
        message: 'Network error. Please check your connection.',
      );
    }
  }

  // Verify Signup
  Future<AuthResponse> verifySignup({
    required String email,
    required String otp,
  }) async {
    try {
      final tempToken = await _storageService.getTempToken();
      if (tempToken == null || tempToken.isEmpty) {
        return AuthResponse(
          success: false,
          message: 'No temporary token found. Please start signup again.',
        );
      }

      final response = await _apiService.postWithTempToken(
        ApiConstants.verifySignup,
        tempToken: tempToken,
        data: {
          'email': email,
          'otp': otp,
        },
      );

      final authResponse = AuthResponse.fromJson(response.data);
      
      // Save token and user data
      if (authResponse.success && authResponse.token != null) {
        await _storageService.saveToken(authResponse.token!);
        if (authResponse.user != null) {
          await _storageService.saveUser(authResponse.user!);
        }
        await _storageService.clearTempToken();
      }
      
      return authResponse;
    } catch (e) {
      if (kDebugMode) {
        print('Verify signup error: $e');
      }
      return AuthResponse(
        success: false,
        message: 'Network error. Please check your connection.',
      );
    }
  }

  // Resend OTP
  Future<AuthResponse> resendOtp({
    required String email,
  }) async {
    try {
      final tempToken = await _storageService.getTempToken();
      if (tempToken == null || tempToken.isEmpty) {
        return AuthResponse(
          success: false,
          message: 'No temporary token found. Please start signup again.',
        );
      }

      final response = await _apiService.postWithTempToken(
        ApiConstants.resendOtp,
        tempToken: tempToken,
        data: {
          'email': email,
        },
      );

      return AuthResponse.fromJson(response.data);
    } catch (e) {
      if (kDebugMode) {
        print('Resend OTP error: $e');
      }
      return AuthResponse(
        success: false,
        message: 'Network error. Please check your connection.',
      );
    }
  }

  // Login
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConstants.login,
        data: {
          'email': email,
          'password': password,
        },
      );

      final authResponse = AuthResponse.fromJson(response.data);
      
      // Save token and user data
      if (authResponse.success && authResponse.token != null) {
        await _storageService.saveToken(authResponse.token!);
        if (authResponse.user != null) {
          await _storageService.saveUser(authResponse.user!);
        }
      }
      
      // If verification required, save temp token
      if (authResponse.requireVerification == true && authResponse.tempToken != null) {
        await _storageService.saveTempToken(authResponse.tempToken!);
      }
      
      return authResponse;
    } catch (e) {
      if (kDebugMode) {
        print('Login error: $e');
      }
      return AuthResponse(
        success: false,
        message: 'Network error. Please check your connection.',
      );
    }
  }

  // Forgot Password
  Future<AuthResponse> forgotPassword({
    required String email,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConstants.forgotPassword,
        data: {
          'email': email,
        },
      );

      return AuthResponse.fromJson(response.data);
    } catch (e) {
      if (kDebugMode) {
        print('Forgot password error: $e');
      }
      return AuthResponse(
        success: false,
        message: 'Network error. Please check your connection.',
      );
    }
  }

  // Reset Password
  Future<AuthResponse> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConstants.resetPassword,
        data: {
          'email': email,
          'otp': otp,
          'new_password': newPassword,
        },
      );

      return AuthResponse.fromJson(response.data);
    } catch (e) {
      if (kDebugMode) {
        print('Reset password error: $e');
      }
      return AuthResponse(
        success: false,
        message: 'Network error. Please check your connection.',
      );
    }
  }

  // Logout
  Future<AuthResponse> logout() async {
    try {
      final response = await _apiService.post(
        ApiConstants.logout,
      );

      await _storageService.clearAll();
      return AuthResponse.fromJson(response.data);
    } catch (e) {
      await _storageService.clearAll();
      return AuthResponse(
        success: true,
        message: 'Logged out successfully',
      );
    }
  }

  // Get Profile
  Future<ApiResponse<UserModel>> getProfile() async {
    try {
      final response = await _apiService.get(
        ApiConstants.profile,
      );

      if (response.data['success'] == true) {
        final user = UserModel.fromJson(response.data['user']);
        await _storageService.saveUser(user);
        return ApiResponse(
          success: true,
          message: 'Profile retrieved successfully',
          data: user,
        );
      } else {
        return ApiResponse.error(
          response.data['message'] ?? 'Failed to get profile',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Get profile error: $e');
      }
      return ApiResponse.error('Network error. Please check your connection.');
    }
  }

  // Update Profile
  Future<ApiResponse<UserModel>> updateProfile({
    String? fullName,
    String? phone,
    String? locationAddress,
    String? city,
    String? region,
  }) async {
    try {
      final response = await _apiService.put(
        ApiConstants.updateProfile,
        data: {
          'full_name': fullName,
          'phone': phone,
          'location_address': locationAddress,
          'city': city,
          'region': region,
        },
      );

      if (response.data['success'] == true) {
        final user = UserModel.fromJson(response.data['user']);
        await _storageService.saveUser(user);
        return ApiResponse(
          success: true,
          message: 'Profile updated successfully',
          data: user,
        );
      } else {
        return ApiResponse.error(
          response.data['message'] ?? 'Failed to update profile',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Update profile error: $e');
      }
      return ApiResponse.error('Network error. Please check your connection.');
    }
  }

  // Verify OTP only
  Future<AuthResponse> verifyOTP({
    required String email,
    required String otp,
    String type = 'Verification',
  }) async {
    try {
      final response = await _apiService.post(
        ApiConstants.verifyOtp,
        data: {
          'email': email,
          'otp': otp,
          'type': type,
        },
      );

      return AuthResponse.fromJson(response.data);
    } catch (e) {
      if (kDebugMode) {
        print('Verify OTP error: $e');
      }
      return AuthResponse(
        success: false,
        message: 'Network error. Please check your connection.',
      );
    }
  }

  Future<bool> isLoggedIn() async {
    return await _storageService.isLoggedIn();
  }

  Future<UserModel?> getCurrentUser() async {
    return await _storageService.getUser();
  }

  Future<String?> getToken() async {
    return await _storageService.getToken();
  }
}