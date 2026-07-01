// lib/data/models/auth_response.dart
import 'user_model.dart';

class AuthResponse {
  final bool success;
  final String message;
  final String? token;
  final String? tempToken;
  final UserModel? user;
  final bool? requireVerification;
  final String? expiresIn;

  AuthResponse({
    required this.success,
    required this.message,
    this.token,
    this.tempToken,
    this.user,
    this.requireVerification,
    this.expiresIn,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      token: json['token'],
      tempToken: json['tempToken'],
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
      requireVerification: json['requireVerification'],
      expiresIn: json['expiresIn'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'token': token,
      'tempToken': tempToken,
      'user': user?.toJson(),
      'requireVerification': requireVerification,
      'expiresIn': expiresIn,
    };
  }
}