import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/luxury_bottom_sheet.dart';
import '../../../../core/widgets/app_page_app_bar.dart';
import '../bloc/wardrobe_bloc.dart';
import '../bloc/wardrobe_event.dart';
import '../bloc/wardrobe_state.dart';
import '../../../../core/widgets/wardrobe_item_card.dart';
import 'add_wardrobe_item_page.dart';

class WardrobePage extends StatelessWidget {
  const WardrobePage({super.key});

  static const _filterLabels = {
    'All': 'All',
    'top': 'Tops',
    'bottom': 'Bottoms',
    'shoes': 'Shoes',
    'outerwear': 'Outerwear',
  };

  Future<void> _showImageSourceDialog(BuildContext context) async {
    await LuxuryBottomSheet.show(
      context: context,
      title: 'Add to wardrobe',
      subtitle: 'Import pieces into your closet',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LuxurySheetAction(
            animationIndex: 0,
            icon: Icons.photo_library_outlined,
            title: 'Choose from Gallery',
            subtitle: 'Select one or multiple photos',
            onTap: () async {
              final navigator = Navigator.of(context);
              navigator.pop();

              final picker = ImagePicker();
              final images = await picker.pickMultiImage(imageQuality: 85);

              if (images.isNotEmpty && context.mounted) {
                navigator.push(
                  MaterialPageRoute(
                    builder: (context) => AddWardrobeItemPage(
                      initialImages:
                          images.map((x) => File(x.path)).toList(),
                    ),
                  ),
                );
              }
            },
          ),
          LuxurySheetAction(
            animationIndex: 1,
            icon: Icons.camera_alt_outlined,
            title: 'Take a Photo',
            subtitle: 'Capture the item with your camera',
            onTap: () async {
              final navigator = Navigator.of(context);
              navigator.pop();

              final picker = ImagePicker();
              final image = await picker.pickImage(
                source: ImageSource.camera,
                imageQuality: 85,
              );

              if (image != null && context.mounted) {
                navigator.push(
                  MaterialPageRoute(
                    builder: (context) => AddWardrobeItemPage(
                      initialImages: [File(image.path)],
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
    final filters = _filterLabels.keys.toList();

    return BlocBuilder<WardrobeBloc, WardrobeState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppPageAppBar(
            title: 'My Wardrobe',
            subtitle: 'Curate your closet',
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.search_outlined),
                tooltip: 'Search',
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
                      label: 'TOTAL ITEMS',
                      value: state is WardrobeLoaded
                          ? state.allItems.length.toString()
                          : '0',
                    ),
                    const SizedBox(width: 12),
                    const _StatCard(label: 'OUTFITS', value: '—'),
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
                    final label = _filterLabels[category] ?? category;

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
              Expanded(child: _buildGridContent(state)),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            heroTag: 'wardrobe_ai_fab',
            onPressed: () => context.push('/generate-outfit'),
            tooltip: 'Generate outfit with AI',
            child: const Icon(Icons.auto_awesome),
          ),
        );
      },
    );
  }

  Widget _buildGridContent(WardrobeState state) {
    if (state is WardrobeLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is WardrobeError) {
      return Center(child: Text('Error: ${state.message}'));
    }
    if (state is WardrobeLoaded) {
      if (state.filteredItems.isEmpty) {
        return const Center(child: Text('No items found'));
      }
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.68,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: state.filteredItems.length,
        itemBuilder: (context, index) {
          return WardrobeItemCard(item: state.filteredItems[index]);
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
