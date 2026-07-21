// lib/screens/chat/ai_chat_screen.dart
//
// شاشة المحادثة مع المساعد الذكي (Gemini) - تصميم فقاعات محادثة عادي،
// بألوان/نصف قطر AppColors/AppRadius الموجودة أصلاً بالمشروع. ردود
// المساعد بتُعرض بـ Markdown (عناوين/قوائم/**تشديد**...) عبر markdown_widget،
// رسائل المستخدم نص عادي.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_widget/markdown_widget.dart';
import '../../core/theme/app_themes.dart';
import '../../core/i18n/app_localizations.dart';
import '../../data/models/chat_message_model.dart';
import '../../providers/ai_chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/chat/typing_indicator.dart';
import '../../widgets/main_layout.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(aiChatProvider.notifier).loadHistoryIfNeeded());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send([String? preset]) async {
    final text = preset ?? _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    await ref.read(aiChatProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  Future<void> _confirmClear(Locale locale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.t(locale, 'chatbot_clear_history')),
        content: Text(AppLocalizations.t(locale, 'chatbot_clear_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.t(locale, 'chatbot_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.t(locale, 'chatbot_clear'), style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(aiChatProvider.notifier).clearHistory();
    }
  }

  Widget _bubble(ChatMessageModel message, bool isDark) {
    final isUser = message.isUser;
    final bgColor = isUser
        ? AppColors.brand
        : (isDark ? AppColors.darkSurface : AppColors.lightSurfaceLow);
    final textColor = isUser ? Colors.white : (isDark ? Colors.white : const Color(0xFF1B1F23));

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: isUser
            ? Text(message.content, style: TextStyle(color: textColor, fontSize: 14.5))
            : MarkdownBlock(
                data: message.content,
                config: isDark
                    ? MarkdownConfig.darkConfig
                    : MarkdownConfig.defaultConfig,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final state = ref.watch(aiChatProvider);
    final notifier = ref.read(aiChatProvider.notifier);
    final role = ref.watch(authProvider).user?.role;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen(aiChatProvider, (previous, next) {
      if (next.messages.length != previous?.messages.length) _scrollToBottom();
    });

    // ✅ الشاشة بتنفتح من زر عائم عام (ChatFloatingButton) متاح لأي دور
    // مسجّل دخوله - الهيدر الموحّد الجديد (MainLayout/AppHeader) مبني
    // خصيصًا للزبون فما لازم يظهر لغير الأدوار التانية.
    if (role == 'Customer') {
      return MainLayout(
        builder: (context, isWeb, padding, width) =>
            _buildBody(context, locale, state, notifier, role, isDark, showTitleBar: true),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.t(locale, 'chatbot_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmClear(locale),
          ),
        ],
      ),
      body: _buildBody(context, locale, state, notifier, role, isDark),
    );
  }

  Widget _buildBody(
    BuildContext context,
    Locale locale,
    AiChatState state,
    AiChatNotifier notifier,
    String? role,
    bool isDark, {
    bool showTitleBar = false,
  }) {
    return Column(
        children: [
          if (showTitleBar)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.t(locale, 'chatbot_title'),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmClear(locale),
                  ),
                ],
              ),
            ),
          Expanded(
            child: state.isLoadingHistory
                ? const Center(child: CircularProgressIndicator())
                : state.messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            AppLocalizations.t(locale, 'chatbot_empty_title'),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: state.messages.length + (state.isSending ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == state.messages.length) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkSurface : AppColors.lightSurfaceLow,
                                  borderRadius: BorderRadius.circular(AppRadius.lg),
                                ),
                                child: TypingIndicator(color: AppColors.brand),
                              ),
                            );
                          }
                          return _bubble(state.messages[index], isDark);
                        },
                      ),
          ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      state.error!.isNotEmpty ? state.error! : AppLocalizations.t(locale, 'chatbot_error_generic'),
                      style: const TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _send(state.messages.isNotEmpty && state.messages.last.isUser ? state.messages.last.content : null),
                    child: Text(AppLocalizations.t(locale, 'chatbot_retry')),
                  ),
                ],
              ),
            ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: notifier.quickSuggestionsFor(role).map((q) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ActionChip(
                    label: Text(q, style: const TextStyle(fontSize: 12.5)),
                    onPressed: state.isSending ? null : () => _send(q),
                  ),
                );
              }).toList(),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: AppLocalizations.t(locale, 'chatbot_input_hint'),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.pill), borderSide: BorderSide.none),
                        filled: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: AppColors.brand),
                    onPressed: state.isSending ? null : () => _send(),
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ],
    );
  }
}
