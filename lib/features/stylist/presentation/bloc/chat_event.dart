import 'package:equatable/equatable.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

class ChatSessionStarted extends ChatEvent {
  const ChatSessionStarted();
}

class ChatMessageSent extends ChatEvent {
  final String text;

  const ChatMessageSent(this.text);

  @override
  List<Object?> get props => [text];
}

class ChatGenerateOutfitRequested extends ChatEvent {
  final bool generateTryOn;

  const ChatGenerateOutfitRequested({this.generateTryOn = true});

  @override
  List<Object?> get props => [generateTryOn];
}
