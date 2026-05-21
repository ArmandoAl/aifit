import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/stylist_repository.dart';
import '../../domain/chat_models.dart';
import '../../../outfit/services/outfit_service.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final StylistRepository repository;
  final OutfitService _outfitService;

  ChatBloc({
    required this.repository,
    OutfitService? outfitService,
  })  : _outfitService = outfitService ?? OutfitService(),
        super(const ChatInitial()) {
    on<ChatSessionStarted>(_onSessionStarted);
    on<ChatMessageSent>(_onMessageSent);
    on<ChatGenerateOutfitRequested>(_onGenerateOutfit);
  }

  void _onSessionStarted(ChatSessionStarted event, Emitter<ChatState> emit) {
    final welcome = repository.welcomeMessage();
    emit(
      ChatLoaded(
        messages: [ChatMessage.assistantText(welcome.assistantMessage)],
        accumulatedIntent: welcome.intentState,
        readyToGenerate: welcome.readyToGenerate,
      ),
    );
  }

  Future<void> _onMessageSent(
    ChatMessageSent event,
    Emitter<ChatState> emit,
  ) async {
    if (event.text.trim().isEmpty) return;

    final current = state;
    if (current is! ChatLoaded) return;

    final userMsg = ChatMessage.userText(event.text.trim());
    var messages = [...current.messages, userMsg];

    // Quitar CTA anterior si el usuario sigue conversando
    messages = _withoutStaleCta(messages);

    emit(
      current.copyWith(
        messages: messages,
        isTyping: true,
        readyToGenerate: false,
      ),
    );

    try {
      final turn = await repository.sendMessage(
        userMessage: event.text.trim(),
        history: messages,
        currentIntent: current.accumulatedIntent,
      );

      final loaded = state as ChatLoaded;
      var updated = [
        ...loaded.messages,
        ChatMessage.assistantText(turn.assistantMessage),
      ];

      if (turn.readyToGenerate) {
        updated = [...updated, ChatMessage.cta()];
      }

      emit(
        loaded.copyWith(
          messages: updated,
          isTyping: false,
          accumulatedIntent: turn.intentState,
          readyToGenerate: turn.readyToGenerate,
        ),
      );
    } catch (e) {
      debugPrint('❌ Stylist chat error: $e');
      final loaded = state as ChatLoaded;
      emit(
        loaded.copyWith(
          messages: [
            ...loaded.messages,
            ChatMessage.assistantText(
              "I'm having a brief connection issue — could you try again?",
            ),
          ],
          isTyping: false,
        ),
      );
    }
  }

  Future<void> _onGenerateOutfit(
    ChatGenerateOutfitRequested event,
    Emitter<ChatState> emit,
  ) async {
    final current = state;
    if (current is! ChatLoaded || current.isGenerating) return;

    final prompt = current.accumulatedIntent.toUserPrompt();
    var messages = _withoutStaleCta(current.messages);
    messages = [
      ...messages,
      ChatMessage.assistantText(
        "Perfect — I'm putting together looks from your wardrobe.",
      ),
      ChatMessage.loading('analyzing'),
    ];

    emit(
      current.copyWith(
        messages: messages,
        isGenerating: true,
        readyToGenerate: false,
      ),
    );

    try {
      _updateLoadingPhase(emit, 'filtering');
      await Future.delayed(const Duration(milliseconds: 80));
      _updateLoadingPhase(emit, 'generating');
      await Future.delayed(const Duration(milliseconds: 80));

      if (event.generateTryOn) {
        _updateLoadingPhase(emit, 'creating_image');
      }

      final result = await _outfitService.generateCompleteOutfit(
        userPrompt: prompt,
        generateImage: event.generateTryOn,
      );

      final loaded = state as ChatLoaded;
      var resultMessages = _withoutLoading(loaded.messages);

      if (result.outfits.isEmpty) {
        resultMessages = [
          ...resultMessages,
          ChatMessage.error(
            "I couldn't build a full look with your current wardrobe. Try adjusting colors or occasion.",
          ),
        ];
      } else {
        resultMessages = [
          ...resultMessages,
          ChatMessage.assistantText(
            "Here are your curated looks — tap any card to see details.",
          ),
        ];

        for (final outfit in result.outfits) {
          final tryOnUrl =
              result.tryOnImageUrls[outfit.id] ?? result.tryOnImageUrl;
          resultMessages = [
            ...resultMessages,
            ChatMessage.outfit(
              ChatOutfitPreview(
                outfit: outfit,
                tryOnImageUrl: tryOnUrl,
                explanation: outfit.explanation,
              ),
            ),
          ];
        }
      }

      emit(
        loaded.copyWith(
          messages: resultMessages,
          isGenerating: false,
        ),
      );
    } catch (e) {
      debugPrint('❌ Outfit generation from chat: $e');
      final loaded = state as ChatLoaded;
      emit(
        loaded.copyWith(
          messages: [
            ..._withoutLoading(loaded.messages),
            ChatMessage.error(
              'Something went wrong while generating. Please try again.',
            ),
          ],
          isGenerating: false,
        ),
      );
    }
  }

  void _updateLoadingPhase(Emitter<ChatState> emit, String phase) {
    final current = state;
    if (current is! ChatLoaded) return;
    final without = _withoutLoading(current.messages);
    emit(
      current.copyWith(
        messages: [...without, ChatMessage.loading(phase)],
      ),
    );
  }

  List<ChatMessage> _withoutStaleCta(List<ChatMessage> messages) {
    return messages
        .where((m) => m.type != ChatMessageType.ctaGenerate)
        .toList();
  }

  List<ChatMessage> _withoutLoading(List<ChatMessage> messages) {
    return messages
        .where((m) => m.type != ChatMessageType.generationLoading)
        .toList();
  }
}
