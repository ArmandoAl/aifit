import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../../core/theme/app_colors.dart';
import '../bloc/wardrobe_bloc.dart';
import '../bloc/wardrobe_event.dart';
import '../bloc/wardrobe_state.dart';
import '../../../../core/widgets/wardrobe_item_card.dart';
import '../../../generator/presentation/pages/quick_generator_page.dart';
import 'add_wardrobe_item_page.dart';

class WardrobePage extends StatelessWidget {
  const WardrobePage({super.key});

  Future<void> _showImageSourceDialog(BuildContext context) async {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Add Wardrobe Item',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.photo_library_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  title: const Text(
                    'Choose from Gallery',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Select one or multiple photos',
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: () async {
                    // Capture NavigatorState before popping the modal
                    final navigator = Navigator.of(context);
                    navigator.pop();

                    debugPrint('📸 Opening image picker...');
                    final picker = ImagePicker();
                    final List<XFile> images = await picker.pickMultiImage(
                      imageQuality: 85,
                    );

                    debugPrint('📸 Selected ${images.length} images');
                    if (images.isNotEmpty) {
                      debugPrint(
                        '📸 Navigating to AddWardrobeItemPage with ${images.length} images',
                      );
                      // Use the captured navigator instead of context
                      navigator.push(
                        MaterialPageRoute(
                          builder: (context) => AddWardrobeItemPage(
                            initialImages: images
                                .map((x) => File(x.path))
                                .toList(),
                          ),
                        ),
                      );
                    } else {
                      debugPrint('⚠️ No images selected');
                    }
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      color: AppColors.secondary,
                    ),
                  ),
                  title: const Text(
                    'Take a Photo',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Use camera to scan the item',
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: () async {
                    // Capture NavigatorState before popping the modal
                    final navigator = Navigator.of(context);
                    navigator.pop();

                    final picker = ImagePicker();
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 85,
                    );

                    if (image != null) {
                      // Use the captured navigator instead of context
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
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Lista de filtros para la UI
    final filters = ["All", "top", "bottom", "shoes", "outerwear"];

    return BlocBuilder<WardrobeBloc, WardrobeState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              "My Wardrobe",
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24),
            ),
            centerTitle: false,
            actions: [
              IconButton(
                onPressed: () {}, // Futuro: búsqueda
                icon: const Icon(Icons.search),
              ),
              // Botón circular pequeño para añadir (versión header)
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: CircleAvatar(
                  backgroundColor: AppColors.background,
                  child: IconButton(
                    icon: const Icon(Icons.add, color: AppColors.textPrimary),
                    onPressed: () => _showImageSourceDialog(context),
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              // 1. Estadísticas rápidas
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Row(
                  children: [
                    _StatCard(
                      label: "TOTAL ITEMS",
                      value: state is WardrobeLoaded
                          ? state.allItems.length.toString()
                          : "0",
                    ),
                    const SizedBox(width: 12),
                    const _StatCard(label: "OUTFITS", value: "15"),
                  ],
                ),
              ),

              // 2. Filtros (Chips horizontales)
              SizedBox(
                height: 60,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  scrollDirection: Axis.horizontal,
                  itemCount: filters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final category = filters[index];
                    final isSelected =
                        state is WardrobeLoaded &&
                        state.selectedCategory.toLowerCase() ==
                            category.toLowerCase();

                    // Mapeo visual de nombres (Top -> Tops)
                    final label = category == 'All'
                        ? 'All'
                        : '${category[0].toUpperCase()}${category.substring(1)}s';

                    return ChoiceChip(
                      label: Text(label),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textPrimary,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      onSelected: (_) => context.read<WardrobeBloc>().add(
                        WardrobeFilterChanged(category),
                      ),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      showCheckmark: false,
                    );
                  },
                ),
              ),

              // 3. Grid de Ropa
              Expanded(child: _buildGridContent(state)),
            ],
          ),
          // Botón flotante principal - Quick Generator
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'wardrobe_quick_generator_button',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const QuickGeneratorPage(),
                  fullscreenDialog: true,
                ),
              );
            },
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.auto_awesome),
            label: const Text("Quick Generate"),
          ),
        );
      },
    );
  }

  Widget _buildGridContent(WardrobeState state) {
    if (state is WardrobeLoading) {
      return const Center(child: CircularProgressIndicator());
    } else if (state is WardrobeError) {
      return Center(child: Text("Error: ${state.message}"));
    } else if (state is WardrobeLoaded) {
      if (state.filteredItems.isEmpty) {
        return const Center(child: Text("No items found"));
      }
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // 2 columnas
          childAspectRatio: 0.75, // Proporción vertical
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: state.filteredItems.length,
        itemBuilder: (context, index) {
          return WardrobeItemCard(item: state.filteredItems[index]);
        },
      );
    }
    return const Center(child: Text("No data available"));
  }
}

// Widget auxiliar interno para las estadísticas
class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
