import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/platform/app_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/luxury_bottom_sheet.dart';
import '../../../../core/widgets/shell_bottom_insets.dart';
import '../../../../core/widgets/app_page_app_bar.dart';
import '../bloc/wardrobe_bloc.dart';
import '../bloc/wardrobe_event.dart';
import '../bloc/wardrobe_state.dart';
import '../../../../core/widgets/wardrobe_item_card.dart';
import '../../../../core/l10n/app_strings_es.dart';
import '../../../wardrobe/domain/wardrobe_palette.dart';
import 'add_wardrobe_item_page.dart';

class WardrobePage extends StatelessWidget {
  const WardrobePage({super.key});

  static const _filterKeys = ['All', 'top', 'bottom', 'shoes', 'outerwear'];

  static String _filterLabel(String key) {
    if (key == 'All') return AppStringsEs.filterAll;
    return WardrobePalette.labelType(key);
  }

  Future<void> _showImageSourceDialog(BuildContext context) async {
    await LuxuryBottomSheet.show(
      context: context,
      title: AppStringsEs.addToWardrobe,
      subtitle: AppStringsEs.addToWardrobeSubtitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LuxurySheetAction(
            animationIndex: 0,
            icon: Icons.photo_library_outlined,
            title: AppStringsEs.chooseGallery,
            subtitle: AppStringsEs.chooseGallerySubtitle,
            onTap: () async {
              final navigator = Navigator.of(context);
              navigator.pop();

              final picker = ImagePicker();
              final images = await picker.pickMultiImage(imageQuality: 85);

              if (images.isNotEmpty && context.mounted) {
                final initial = await AppImage.fromXFiles(images);
                if (!context.mounted) return;
                navigator.push(
                  MaterialPageRoute(
                    builder: (context) => AddWardrobeItemPage(
                      initialImages: initial,
                    ),
                  ),
                );
              }
            },
          ),
          LuxurySheetAction(
            animationIndex: 1,
            icon: Icons.camera_alt_outlined,
            title: AppStringsEs.takePhoto,
            subtitle: AppStringsEs.takePhotoSubtitle,
            onTap: () async {
              final navigator = Navigator.of(context);
              navigator.pop();

              final picker = ImagePicker();
              final image = await picker.pickImage(
                source: ImageSource.camera,
                imageQuality: 85,
              );

              if (image != null && context.mounted) {
                final initial = await AppImage.fromXFile(image);
                if (!context.mounted) return;
                navigator.push(
                  MaterialPageRoute(
                    builder: (context) => AddWardrobeItemPage(
                      initialImages: [initial],
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filters = _filterKeys;

    return BlocBuilder<WardrobeBloc, WardrobeState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppPageAppBar(
            title: AppStringsEs.myWardrobe,
            subtitle: AppStringsEs.curateCloset,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.search_outlined),
                tooltip: AppStringsEs.search,
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton.filledTonal(
                  onPressed: () => _showImageSourceDialog(context),
                  icon: const Icon(Icons.add, size: 22),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfaceContainerLow,
                    foregroundColor: AppColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    _StatCard(
                      label: AppStringsEs.totalItems,
                      value: state is WardrobeLoaded
                          ? state.allItems.length.toString()
                          : '0',
                    ),
                    const SizedBox(width: 12),
                    const _StatCard(label: AppStringsEs.outfitsStat, value: '—'),
                  ],
                ),
              ),
              SizedBox(
                height: 52,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: filters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final category = filters[index];
                    final isSelected = state is WardrobeLoaded &&
                        state.selectedCategory.toLowerCase() ==
                            category.toLowerCase();
                    final label = _filterLabel(category);

                    return FilterChip(
                      label: Text(label),
                      selected: isSelected,
                      showCheckmark: false,
                      onSelected: (_) => context.read<WardrobeBloc>().add(
                            WardrobeFilterChanged(category),
                          ),
                      selectedColor: AppColors.inverseSurface,
                      backgroundColor: AppColors.surface,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? AppColors.onInverseSurface
                            : AppColors.onSurface,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 13,
                      ),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.inverseSurface
                            : AppColors.border,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildGridContent(context, state)),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            heroTag: 'wardrobe_ai_fab',
            onPressed: () => context.push('/generate-outfit'),
            tooltip: AppStringsEs.generateOutfitAi,
            child: const Icon(Icons.auto_awesome),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.endFloat,
        );
      },
    );
  }

  Widget _buildGridContent(BuildContext context, WardrobeState state) {
    if (state is WardrobeLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is WardrobeError) {
      return Center(child: Text(AppStringsEs.errorWith(state.message)));
    }
    if (state is WardrobeLoaded) {
      if (state.filteredItems.isEmpty) {
        return const Center(child: Text(AppStringsEs.noItemsFound));
      }
      return LayoutBuilder(
        builder: (context, constraints) {
          const crossAxisCount = 2;
          const crossAxisSpacing = 12.0;
          const horizontalPadding = 16.0;
          final innerWidth =
              constraints.maxWidth - horizontalPadding * 2;
          final cellWidth =
              (innerWidth - crossAxisSpacing) / crossAxisCount;
          const childAspectRatio = 0.68;
          final cellHeight = cellWidth / childAspectRatio;

          final items = state.filteredItems;
          final bottomPad = ShellBottomInsets.withFab(context);

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              8,
              horizontalPadding,
              bottomPad,
            ),
            child: Column(
              children: [
                for (var row = 0; row < (items.length + 1) ~/ 2; row++) ...[
                  if (row > 0) const SizedBox(height: crossAxisSpacing),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: cellHeight,
                          child: WardrobeItemCard(item: items[row * 2]),
                        ),
                      ),
                      const SizedBox(width: crossAxisSpacing),
                      Expanded(
                        child: row * 2 + 1 < items.length
                            ? SizedBox(
                                height: cellHeight,
                                child: WardrobeItemCard(
                                  item: items[row * 2 + 1],
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      );
    }
    return const Center(child: Text('No data available'));
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppTheme.ambientCardShadow,
        ),
        child: Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.tertiary,
                      letterSpacing: 0.6,
                    ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
