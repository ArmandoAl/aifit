import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_page_app_bar.dart';
import '../bloc/chat_bloc.dart';
import '../bloc/chat_event.dart';
import '../bloc/chat_state.dart';
import '../../domain/chat_models.dart';
import '../widgets/stylist_chat_bubble.dart';
import '../widgets/stylist_generate_cta_card.dart';
import '../widgets/stylist_generation_loading_card.dart';
import '../widgets/stylist_outfit_carousel.dart';
import '../widgets/stylist_outfit_preview_card.dart';
import '../widgets/stylist_typing_indicator.dart';

/// Ítem normalizado para el ListView del chat (agrupa outfits en carrusel).
sealed class _ChatListEntry {}

class _ChatMessageEntry extends _ChatListEntry {
  final ChatMessage message;
  _ChatMessageEntry(this.message);
}

class _ChatOutfitCarouselEntry extends _ChatListEntry {
  final List<ChatOutfitPreview> previews;
  _ChatOutfitCarouselEntry(this.previews);
}

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

  List<_ChatListEntry> _normalizeMessages(List<ChatMessage> messages) {
    final entries = <_ChatListEntry>[];
    var i = 0;
    while (i < messages.length) {
      final msg = messages[i];
      if (msg.type == ChatMessageType.outfitPreview &&
          msg.outfitPreview != null) {
        final group = <ChatOutfitPreview>[];
        while (i < messages.length &&
            messages[i].type == ChatMessageType.outfitPreview &&
            messages[i].outfitPreview != null) {
          group.add(messages[i].outfitPreview!);
          i++;
        }
        entries.add(_ChatOutfitCarouselEntry(group));
      } else {
        entries.add(_ChatMessageEntry(msg));
        i++;
      }
    }
    return entries;
  }

  Widget _buildScaffold(BuildContext context, ChatLoaded state) {
    final entries = _normalizeMessages(state.messages);
    final itemCount = entries.length + (state.isTyping ? 1 : 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppPageAppBar(
        title: 'AI Stylist',
        subtitle: 'Premium styling session',
        automaticallyImplyLeading: false,
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
                if (state.isTyping && index == entries.length) {
                  return const StylistTypingIndicator();
                }
                final entry = entries[index];
                return _AnimatedMessage(
                  key: ValueKey(_entryKey(entry, index)),
                  index: index,
                  child: _buildEntry(context, entry, state),
                );
              },
            ),
          ),
          _buildInput(context, state),
        ],
      ),
    );
  }

  String _entryKey(_ChatListEntry entry, int index) {
    return switch (entry) {
      _ChatMessageEntry(:final message) => message.id,
      _ChatOutfitCarouselEntry(:final previews) =>
        'carousel_${previews.map((p) => p.outfit.id).join('_')}_$index',
    };
  }

  Widget _buildEntry(
    BuildContext context,
    _ChatListEntry entry,
    ChatLoaded state,
  ) {
    return switch (entry) {
      _ChatOutfitCarouselEntry(:final previews) => StylistOutfitCarousel(
          previews: previews,
          onPreviewTap: (p) => _showOutfitSheet(context, p),
        ),
      _ChatMessageEntry(:final message) => _buildMessage(context, message, state),
    };
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
        return StylistOutfitCarousel(
          previews: [msg.outfitPreview!],
          onPreviewTap: (p) => _showOutfitSheet(context, p),
        );
      case ChatMessageType.typing:
        return const StylistTypingIndicator();
    }
  }

  void _showOutfitSheet(BuildContext context, ChatOutfitPreview preview) {
    AppBottomSheet.showDraggable(
      context: context,
      title: 'Look details',
      subtitle: 'Curated for your wardrobe',
      builder: (scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
        children: [
          StylistOutfitPreviewCard(
            preview: preview,
            compact: false,
          ),
          if (preview.explanation.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                preview.explanation,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.5,
                      color: AppColors.secondary,
                    ),
              ),
            ),
        ],
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
