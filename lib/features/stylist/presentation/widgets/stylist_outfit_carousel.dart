import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/chat_models.dart';
import 'stylist_outfit_preview_card.dart';

/// Carrusel horizontal de looks generados (altura fija para no colapsar el chat).
class StylistOutfitCarousel extends StatelessWidget {
  static const double carouselHeight = 272;
  static const double cardWidth = 196;

  final List<ChatOutfitPreview> previews;
  final void Function(ChatOutfitPreview preview) onPreviewTap;

  const StylistOutfitCarousel({
    super.key,
    required this.previews,
    required this.onPreviewTap,
  });

  @override
  Widget build(BuildContext context) {
    if (previews.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 16, 8),
          child: Row(
            children: [
              Icon(
                Icons.swipe,
                size: 16,
                color: AppColors.textSecondary.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 6),
              Text(
                previews.length == 1
                    ? 'Your look'
                    : '${previews.length} looks · swipe to explore',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: carouselHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: previews.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final preview = previews[index];
              return SizedBox(
                width: cardWidth,
                height: carouselHeight,
                child: StylistOutfitPreviewCard(
                  preview: preview,
                  compact: true,
                  onTap: () => onPreviewTap(preview),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}
