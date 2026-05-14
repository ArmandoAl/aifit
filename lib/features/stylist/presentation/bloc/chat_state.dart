import 'package:equatable/equatable.dart';
import '../../domain/chat_models.dart';

abstract class ChatState extends Equatable {
  const ChatState();

  @override
  List<Object?> get props => [];
}

class ChatInitial extends ChatState {
  const ChatInitial();
}

class ChatLoaded extends ChatState {
  final List<ChatMessage> messages;
  final bool isTyping;

  const ChatLoaded({
    required this.messages,
    this.isTyping = false,
  });

  ChatLoaded copyWith({
    List<ChatMessage>? messages,
    bool? isTyping,
  }) {
    return ChatLoaded(
      messages: messages ?? this.messages,
      isTyping: isTyping ?? this.isTyping,
    );
  }

  @override
  List<Object?> get props => [messages, isTyping];
}
