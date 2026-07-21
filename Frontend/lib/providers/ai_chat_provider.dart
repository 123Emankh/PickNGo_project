// lib/providers/ai_chat_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/chat_message_model.dart';
import '../services/ai_chat_service.dart';
import '../core/i18n/locale_notifier.dart';

final aiChatServiceProvider = Provider<AiChatService>((ref) {
  return AiChatService();
});

class AiChatState {
  final List<ChatMessageModel> messages;
  final bool isSending;
  final bool isLoadingHistory;
  final String? error;
  final bool historyLoaded;

  AiChatState({
    this.messages = const [],
    this.isSending = false,
    this.isLoadingHistory = false,
    this.error,
    this.historyLoaded = false,
  });

  AiChatState copyWith({
    List<ChatMessageModel>? messages,
    bool? isSending,
    bool? isLoadingHistory,
    String? error,
    bool? historyLoaded,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      error: error,
      historyLoaded: historyLoaded ?? this.historyLoaded,
    );
  }
}

final aiChatProvider = StateNotifierProvider<AiChatNotifier, AiChatState>((ref) {
  final service = ref.read(aiChatServiceProvider);
  return AiChatNotifier(service, ref);
});

class AiChatNotifier extends StateNotifier<AiChatState> {
  final AiChatService _service;
  final Ref _ref;

  AiChatNotifier(this._service, this._ref) : super(AiChatState());

  Future<void> loadHistoryIfNeeded() async {
    if (state.historyLoaded || state.isLoadingHistory) return;
    state = state.copyWith(isLoadingHistory: true);
    final result = await _service.getHistory();
    state = state.copyWith(
      isLoadingHistory: false,
      historyLoaded: true,
      messages: result.success ? result.messages : state.messages,
    );
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isSending) return;

    final userMessage = ChatMessageModel.local(role: 'user', content: trimmed);
    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isSending: true,
      error: null,
    );

    final locale = _ref.read(localeNotifierProvider).languageCode;
    final result = await _service.sendMessage(message: trimmed, locale: locale);

    if (result.success && result.reply != null) {
      final reply = ChatMessageModel.local(role: 'model', content: result.reply!);
      state = state.copyWith(messages: [...state.messages, reply], isSending: false);
    } else if (result.message.isEmpty) {
      // ✅ الطلب أُلغي عمدًا لصالح طلب أحدث (راجع ai_chat_service.dart) -
      // مش خطأ حقيقي، ما لازم يظهر أي رسالة خطأ للمستخدم
      state = state.copyWith(isSending: false);
    } else {
      state = state.copyWith(isSending: false, error: result.message);
    }
  }

  Future<void> clearHistory() async {
    final ok = await _service.clearHistory();
    if (ok) {
      state = AiChatState(historyLoaded: true);
    }
  }

  /// أسئلة سريعة مقترحة حسب دور المستخدم الحالي - راجع ai_chat_screen.dart لعرضها
  List<String> quickSuggestionsFor(String? role) {
    switch (role) {
      case 'Restaurant':
        return [
          'Write a description for my new product',
          'Suggest a catchy title for a burger meal',
          'Write short marketing text for a promotion',
        ];
      case 'Admin':
        return [
          'How many orders were completed today?',
          'Which restaurant has the highest sales this week?',
          'Which drivers are online right now?',
          'Which stores need approval?',
        ];
      case 'Driver':
        return [
          'How do delivery fees work?',
          'How do loyalty points work for customers?',
        ];
      default:
        return [
          'Where is my order?',
          'Recommend a restaurant for me',
          'How do loyalty points work?',
          'Explain delivery fees',
        ];
    }
  }
}
