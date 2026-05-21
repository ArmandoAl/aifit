import '../domain/chat_models.dart';
import '../domain/stylist_intent_state.dart';
import '../services/stylist_chat_service.dart';
import 'stylist_repository.dart';

class StylistRepositoryImpl implements StylistRepository {
  final StylistChatService _chatService;

  StylistRepositoryImpl({StylistChatService? chatService})
      : _chatService = chatService ?? StylistChatService();

  @override
  Future<StylistChatTurn> sendMessage({
    required String userMessage,
    required List<ChatMessage> history,
    required StylistIntentState currentIntent,
  }) async {
    final recent = history
        .where((m) => m.type == ChatMessageType.text)
        .toList()
        .reversed
        .take(8)
        .toList()
        .reversed
        .map(
          (m) => MapEntry(
            m.role == ChatRole.user ? 'user' : 'assistant',
            m.text ?? '',
          ),
        )
        .toList();

    final response = await _chatService.chat(
      userMessage: userMessage,
      currentIntent: currentIntent,
      recentTurns: recent,
    );

    final mergedIntent = currentIntent.merge(response.intentState);
    final ready = response.readyToGenerate || mergedIntent.hasMinimumContext;

    return StylistChatTurn(
      assistantMessage: response.assistantMessage,
      intentState: mergedIntent,
      readyToGenerate: ready,
    );
  }

  @override
  StylistChatTurn welcomeMessage() {
    return StylistChatTurn(
      assistantMessage:
          "Hi — I'm your personal stylist. Tell me the occasion, vibe, or colors you have in mind, and I'll curate looks from your wardrobe.",
      intentState: const StylistIntentState(),
      readyToGenerate: false,
    );
  }
}
