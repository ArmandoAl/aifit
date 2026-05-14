import 'package:equatable/equatable.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

class ChatMessageSent extends ChatEvent {
  final String text;

  const ChatMessageSent(this.text);

  @override
  List<Object?> get props => [text];
}
