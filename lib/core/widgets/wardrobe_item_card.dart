import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../../features/wardrobe/domain/wardrobe_item_model.dart';
import '../../features/wardrobe/presentation/pages/wardrobe_item_detail_page.dart';

class WardrobeItemCard extends StatelessWidget {
  final WardrobeItem item;

  const WardrobeItemCard({super.key, required this.item});

  String get _categoryLabel {
    if (item.type.isEmpty) return '';
    final t = item.type.toLowerCase();
    switch (t) {
      case 'top':
        return 'Tops';
      case 'bottom':
        return 'Bottoms';
      case 'shoes':
        return 'Shoes';
      case 'outerwear':
        return 'Outerwear';
      default:
        return '${t[0].toUpperCase()}${t.substring(1)}';
    }
  }

  String? get _brandLine {
    final brand = item.brand?.trim();
    if (brand != null && brand.isNotEmpty) return brand;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.ambientCardShadow,
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        elevation: 0,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => WardrobeItemDetailPage(item: item),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: CachedNetworkImage(
                  imageUrl: item.imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (_, __) => Container(
                    color: AppColors.surfaceContainer,
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: AppColors.surfaceContainer,
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      color: AppColors.tertiary,
                    ),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  border: Border(
                    top: BorderSide(color: AppColors.border, width: 1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_categoryLabel.isNotEmpty)
                      Text(
                        _categoryLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.tertiary,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      item.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_brandLine != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _brandLine!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.secondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
