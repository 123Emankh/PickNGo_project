// lib/services/ai_chat_service.dart
//
// بيربط الفرونت مع /api/ai بالباك إند (المساعد الذكي - Gemini): إرسال
// رسالة وجلب الرد، وجلب/حذف تاريخ المحادثة.
//
// ⚠️ تحقيق إنتاج (Production investigation): المستخدمين كانوا بشوفوا
// "AI assistant is temporarily unavailable" بشكل متكرر، وبينحل بمجرد
// Retry يدوي. السبب الجذري الحقيقي كان بالباك إند (Gemini free tier
// rate limit - راجع geminiClient.js/aiChatService.js بالباك إند)، مش هون -
// بس بما إنه الباك إند هلق بيعيد المحاولة تلقائيًا لحد 3 مرات بـ backoff
// لكل جولة (وممكن يصير عنا لحد 5 جولات + نداء أخير)، أطول زمن انتظار
// معقول ارتفع فعليًا بشكل مقصود ومُبرَّر - فـ receiveTimeout الافتراضي
// (30 ثانية، مشترك مع كل endpoint تاني بـ ApiService) صار قصير كفاية إنه
// يقطع الطلب بينما الباك إند لسا شغال بينجح فعليًا. الحل: timeout أطول
// خاص بهاد الـ endpoint فقط (مش تعديل عام يأثر على تسجيل الدخول/الطلبات).
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/api_constants.dart';
import '../core/utils/api_error.dart';
import '../data/models/chat_message_model.dart';
import 'api_service.dart';

class ChatMessageResult {
  final bool success;
  final String message;
  final String? reply;

  ChatMessageResult({required this.success, this.message = '', this.reply});
}

class ChatHistoryResult {
  final bool success;
  final String message;
  final List<ChatMessageModel> messages;

  ChatHistoryResult({required this.success, this.message = '', this.messages = const []});
}

class AiChatService {
  final ApiService _apiService = ApiService();

  // ✅ لتفادي أي طلب قديم لسا معلّق (مثلاً المستخدم فتح الشات، بعت رسالة،
  // سكّر الشاشة، فتحها تاني وبعت رسالة جديدة بسرعة) - منلغي أي طلب سابق
  // قبل ما نبدأ الجديد، عشان ما يوصل ردّين لنفس الشاشة بترتيب غلط. هاد
  // أهم دفاعيًا من كونه سبب المشكلة الأصلية (السبب الحقيقي كان بالباك إند).
  CancelToken? _activeCancelToken;

  /// يبعت رسالة المستخدم للمساعد الذكي وبيرجع رده النهائي (بعد أي استعلام
  /// بيانات حية لزم الباك إند يعمله بالنيابة عنا - المستخدم ما بشوف هاي التفاصيل)
  Future<ChatMessageResult> sendMessage({required String message, required String locale}) async {
    _activeCancelToken?.cancel('superseded by a newer message');
    final cancelToken = CancelToken();
    _activeCancelToken = cancelToken;

    try {
      final response = await _apiService.post(
        ApiConstants.aiChatMessage,
        data: {'message': message, 'locale': locale},
        cancelToken: cancelToken,
        // ✅ 90 ثانية بدل الـ 30 الافتراضية - راجع تعليق الملف. مبنية على
        // أسوأ حالة واقعية فعليًا: لحد 5 جولات tool-calling × لحد 3 محاولات
        // إعادة (backoff) بالباك إند + نداء أخير احتياطي، مش رقم عشوائي.
        options: Options(receiveTimeout: const Duration(seconds: 90), sendTimeout: const Duration(seconds: 90)),
      );
      final data = response.data;
      return ChatMessageResult(
        success: data['success'] ?? false,
        message: data['message'] ?? '',
        reply: data['reply'],
      );
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        // ✅ ملغى عمدًا لصالح طلب أحدث - ما لازم يظهر كخطأ للمستخدم إطلاقًا
        return ChatMessageResult(success: false, message: '');
      }
      if (kDebugMode) print('AiChatService.sendMessage error: $e');
      return ChatMessageResult(
        success: false,
        message: extractApiErrorMessage(e, fallback: 'The AI assistant is temporarily unavailable.'),
      );
    } finally {
      if (_activeCancelToken == cancelToken) _activeCancelToken = null;
    }
  }

  Future<ChatHistoryResult> getHistory() async {
    try {
      final response = await _apiService.get(ApiConstants.aiChatHistory);
      final data = response.data;
      if (data['success'] == true && data['messages'] != null) {
        return ChatHistoryResult(
          success: true,
          messages: (data['messages'] as List).map((m) => ChatMessageModel.fromJson(m)).toList(),
        );
      }
      return ChatHistoryResult(success: true, messages: []);
    } catch (e) {
      if (kDebugMode) print('AiChatService.getHistory error: $e');
      return ChatHistoryResult(
        success: false,
        message: extractApiErrorMessage(e, fallback: 'Network error while loading chat history'),
      );
    }
  }

  Future<bool> clearHistory() async {
    try {
      final response = await _apiService.delete(ApiConstants.aiChatHistory);
      return response.data['success'] ?? false;
    } catch (e) {
      if (kDebugMode) print('AiChatService.clearHistory error: $e');
      return false;
    }
  }
}
