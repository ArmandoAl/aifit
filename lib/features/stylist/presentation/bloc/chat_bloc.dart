import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/stylist_repository.dart';
import '../../domain/chat_models.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final StylistRepository repository;

  ChatBloc({required this.repository}) : super(const ChatLoaded(messages: [])) {
    on<ChatMessageSent>(_onMessageSent);
  }

  Future<void> _onMessageSent(
    ChatMessageSent event,
    Emitter<ChatState> emit,
  ) async {
    if (event.text.trim().isEmpty) return;

    final currentState = state;
    if (currentState is! ChatLoaded) return;

    // 1. Add user message immediately
    final userMsg = ChatMessage(
      id: DateTime.now().toString(),
      role: ChatRole.user,
      text: event.text,
      timestamp: DateTime.now(),
    );

    emit(currentState.copyWith(
      messages: [...currentState.messages, userMsg],
      isTyping: true,
    ));

    try {
      // 2. Call repository (AI Simulation)
      final response = await repository.sendPrompt(event.text);

      // 3. Create AI message with attached outfit
      final aiMsg = ChatMessage(
        id: DateTime.now().toString(),
        role: ChatRole.ai,
        text: response['text'],
        timestamp: DateTime.now(),
        outfit: GeneratedOutfit.fromJson(response),
      );

      final updatedState = state as ChatLoaded;
      emit(updatedState.copyWith(
        messages: [...updatedState.messages, aiMsg],
        isTyping: false,
      ));
    } catch (e) {
      final errorState = state as ChatLoaded;
      final errorMsg = ChatMessage(
        id: 'err',
        role: ChatRole.ai,
        text: "Sorry, I had a glitch.",
        timestamp: DateTime.now(),
      );

      emit(errorState.copyWith(
        messages: [...errorState.messages, errorMsg],
        isTyping: false,
      ));
    }
  }
}
