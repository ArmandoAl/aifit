import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/chat_bloc.dart';
import '../bloc/chat_event.dart';
import '../bloc/chat_state.dart';
import '../../../../core/widgets/chat_bubble.dart';
import '../../../../core/widgets/outfit_recommendation_card.dart';

class StylistPage extends StatefulWidget {
  const StylistPage({super.key});

  @override
  State<StylistPage> createState() => _StylistPageState();
}

class _StylistPageState extends State<StylistPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ChatBloc, ChatState>(
      listener: (context, state) {
        // Auto-scroll cuando llega un mensaje nuevo
        if (state is ChatLoaded) {
          Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
        }
      },
      child: BlocBuilder<ChatBloc, ChatState>(
        builder: (context, state) {
          return _buildScaffold(context, state);
        },
      ),
    );
  }

  Widget _buildScaffold(BuildContext context, ChatState state) {
    final messages = state is ChatLoaded ? state.messages : <dynamic>[];
    final isTyping = state is ChatLoaded ? state.isTyping : false;

    return Scaffold(
      appBar: AppBar(
        title: const Text("OutfitAI Stylist"),
        actions: [
          IconButton(
            onPressed: () {
              context.push('/generate-outfit');
            },
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Generate Outfit',
          ),
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz)),
        ],
      ),
      body: Column(
        children: [
          // 1. Lista de Mensajes
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(top: 16, bottom: 16),
              itemCount: messages.length + (isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                // Si estamos al final y está escribiendo, mostrar indicador
                if (isTyping && index == messages.length) {
                  return const Padding(
                    padding: EdgeInsets.only(left: 24, top: 8),
                    child: Text(
                      "Stylist is thinking...",
                      style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  );
                }

                final msg = messages[index];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ChatBubble(message: msg),
                    // Si el mensaje tiene un Outfit adjunto, renderizar la tarjeta debajo
                    if (msg.outfit != null)
                      OutfitRecommendationCard(outfit: msg.outfit!),
                  ],
                );
              },
            ),
          ),

          // 2. Input Area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: (0.05)),
                  offset: const Offset(0, -2),
                  blurRadius: 10,
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: "Need an outfit for...",
                        filled: true,
                        fillColor: AppColors.background,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                    heroTag: 'stylist_send_button',
                    mini: true,
                    elevation: 0,
                    backgroundColor: AppColors.primary,
                    onPressed: _sendMessage,
                    child: const Icon(Icons.arrow_upward),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    final text = _controller.text;
    if (text.isNotEmpty) {
      context.read<ChatBloc>().add(ChatMessageSent(text));
      _controller.clear();
    }
  }
}
