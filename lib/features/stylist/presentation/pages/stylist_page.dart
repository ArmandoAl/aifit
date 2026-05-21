import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/chat_bloc.dart';
import '../bloc/chat_event.dart';
import '../bloc/chat_state.dart';
import '../../domain/chat_models.dart';
import '../widgets/stylist_chat_bubble.dart';
import '../widgets/stylist_generate_cta_card.dart';
import '../widgets/stylist_generation_loading_card.dart';
import '../widgets/stylist_outfit_preview_card.dart';
import '../widgets/stylist_typing_indicator.dart';

class StylistPage extends StatefulWidget {
  const StylistPage({super.key});

  @override
  State<StylistPage> createState() => _StylistPageState();
}

class _StylistPageState extends State<StylistPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bloc = context.read<ChatBloc>();
      if (bloc.state is ChatInitial) {
        bloc.add(const ChatSessionStarted());
      }
    });
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ChatBloc, ChatState>(
      listenWhen: (prev, curr) =>
          curr is ChatLoaded &&
          (prev is! ChatLoaded ||
              prev.messages.length != curr.messages.length ||
              prev.isTyping != curr.isTyping),
      listener: (_, __) => _scrollToBottom(),
      child: BlocBuilder<ChatBloc, ChatState>(
        builder: (context, state) {
          if (state is! ChatLoaded) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return _buildScaffold(context, state);
        },
      ),
    );
  }

  Widget _buildScaffold(BuildContext context, ChatLoaded state) {
    final itemCount =
        state.messages.length + (state.isTyping ? 1 : 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Stylist',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            Text(
              'Premium styling session',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/generate-outfit'),
            icon: const Icon(Icons.auto_awesome_outlined),
            tooltip: 'Quick generate (prompt)',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz),
            tooltip: 'More options',
            onSelected: (value) {
              switch (value) {
                case 'saved':
                  context.push('/saved-outfits');
                  break;
                case 'quick':
                  context.push('/generate-outfit');
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'saved',
                child: Row(
                  children: [
                    Icon(Icons.checkroom_outlined, size: 22),
                    SizedBox(width: 12),
                    Text('Saved outfits'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'quick',
                child: Row(
                  children: [
                    Icon(Icons.edit_note_outlined, size: 22),
                    SizedBox(width: 12),
                    Text('Quick generate'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(top: 12, bottom: 12),
              itemCount: itemCount,
              itemBuilder: (context, index) {
                if (state.isTyping && index == state.messages.length) {
                  return const StylistTypingIndicator();
                }
                final msg = state.messages[index];
                return _AnimatedMessage(
                  key: ValueKey(msg.id),
                  index: index,
                  child: _buildMessage(context, msg, state),
                );
              },
            ),
          ),
          _buildInput(context, state),
        ],
      ),
    );
  }

  Widget _buildMessage(
    BuildContext context,
    ChatMessage msg,
    ChatLoaded state,
  ) {
    switch (msg.type) {
      case ChatMessageType.text:
      case ChatMessageType.generationError:
        return StylistChatBubble(message: msg);
      case ChatMessageType.ctaGenerate:
        return StylistGenerateCtaCard(
          isLoading: state.isGenerating,
          onGenerate: () => context.read<ChatBloc>().add(
                const ChatGenerateOutfitRequested(generateTryOn: true),
              ),
        );
      case ChatMessageType.generationLoading:
        return StylistGenerationLoadingCard(phase: msg.generationPhase);
      case ChatMessageType.outfitPreview:
        if (msg.outfitPreview == null) return const SizedBox.shrink();
        return StylistOutfitPreviewCard(
          preview: msg.outfitPreview!,
          onTap: () => _showOutfitSheet(context, msg.outfitPreview!),
        );
      case ChatMessageType.typing:
        return const StylistTypingIndicator();
    }
  }

  void _showOutfitSheet(BuildContext context, ChatOutfitPreview preview) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              StylistOutfitPreviewCard(preview: preview),
              if (preview.explanation.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    preview.explanation,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput(BuildContext context, ChatLoaded state) {
    final disabled = state.isTyping || state.isGenerating;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !disabled,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Describe the occasion, vibe, or colors…',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
                onSubmitted: disabled ? null : (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 10),
            Material(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(28),
              child: InkWell(
                onTap: disabled ? null : _sendMessage,
                borderRadius: BorderRadius.circular(28),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.arrow_upward, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    context.read<ChatBloc>().add(ChatMessageSent(text));
    _controller.clear();
  }
}

class _AnimatedMessage extends StatelessWidget {
  final Widget child;
  final int index;

  const _AnimatedMessage({
    super.key,
    required this.child,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + (index % 3) * 40),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 12),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
