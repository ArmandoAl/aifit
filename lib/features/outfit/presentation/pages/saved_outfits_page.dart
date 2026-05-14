import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/saved_outfits_bloc.dart';
import '../bloc/saved_outfits_event.dart';
import '../bloc/saved_outfits_state.dart';
import '../../domain/saved_outfit_model.dart';

/// Página para mostrar outfits guardados
class SavedOutfitsPage extends StatefulWidget {
  const SavedOutfitsPage({super.key});

  @override
  State<SavedOutfitsPage> createState() => _SavedOutfitsPageState();
}

class _SavedOutfitsPageState extends State<SavedOutfitsPage> {
  String? _selectedOccasion;
  String? _selectedSeason;
  bool _showFavoritesOnly = false;

  @override
  void initState() {
    super.initState();
    // Cargar outfits al iniciar
    context.read<SavedOutfitsBloc>().add(LoadSavedOutfits());
  }

  void _applyFilters() {
    context.read<SavedOutfitsBloc>().add(
          LoadSavedOutfits(
            filterByOccasion: _selectedOccasion,
            filterBySeason: _selectedSeason,
            onlyFavorites: _showFavoritesOnly ? true : null,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Outfits'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: BlocBuilder<SavedOutfitsBloc, SavedOutfitsState>(
        builder: (context, state) {
          if (state is SavedOutfitsLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is SavedOutfitsError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${state.message}',
                    style: const TextStyle(color: AppColors.error),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<SavedOutfitsBloc>().add(LoadSavedOutfits());
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is SavedOutfitsLoaded) {
            if (state.outfits.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.checkroom_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No saved outfits yet',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Generate some outfits to see them here!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                // Filtros activos
                if (state.filterSummary.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: AppColors.primary.withValues(alpha: 0.1),
                    child: Row(
                      children: [
                        const Icon(Icons.filter_alt, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Filters: ${state.filterSummary.values.join(', ')}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedOccasion = null;
                              _selectedSeason = null;
                              _showFavoritesOnly = false;
                            });
                            _applyFilters();
                          },
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  ),
                ],

                // Grid de outfits
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: state.outfits.length,
                    itemBuilder: (context, index) {
                      final outfit = state.outfits[index];
                      return _buildOutfitCard(outfit);
                    },
                  ),
                ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildOutfitCard(SavedOutfit outfit) {
    return GestureDetector(
      onTap: () {
        // Incrementar view count
        context.read<SavedOutfitsBloc>().add(ViewOutfit(outfitId: outfit.id));
        // TODO: Navegar a vista de detalle
        _showOutfitDetails(outfit);
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Imagen
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: outfit.tryOnImageUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.error_outline),
                      ),
                    ),
                  ),
                  // Favorito badge
                  if (outfit.isFavorite)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Match percentage
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${outfit.matchPercentage}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Favorito toggle
                      IconButton(
                        icon: Icon(
                          outfit.isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: outfit.isFavorite
                              ? AppColors.secondary
                              : Colors.grey,
                          size: 20,
                        ),
                        onPressed: () {
                          context.read<SavedOutfitsBloc>().add(
                                ToggleFavorite(
                                  outfitId: outfit.id,
                                  isFavorite: !outfit.isFavorite,
                                ),
                              );
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Tags
                  if (outfit.colors.isNotEmpty || outfit.styleTags.isNotEmpty)
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        ...outfit.colors.take(2).map(
                              (color) => Chip(
                                label: Text(
                                  color,
                                  style: const TextStyle(fontSize: 10),
                                ),
                                backgroundColor: AppColors.primary.withValues(
                                  alpha: 0.1,
                                ),
                                padding: EdgeInsets.zero,
                                labelPadding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                              ),
                            ),
                        ...outfit.styleTags.take(1).map(
                              (tag) => Chip(
                                label: Text(
                                  tag,
                                  style: const TextStyle(fontSize: 10),
                                ),
                                backgroundColor: AppColors.secondary.withValues(
                                  alpha: 0.1,
                                ),
                                padding: EdgeInsets.zero,
                                labelPadding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                              ),
                            ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Outfits'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Occasion
                DropdownButtonFormField<String>(
                  value: _selectedOccasion,
                  decoration: const InputDecoration(
                    labelText: 'Occasion',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    const DropdownMenuItem(
                      value: 'casual',
                      child: Text('Casual'),
                    ),
                    const DropdownMenuItem(
                      value: 'formal',
                      child: Text('Formal'),
                    ),
                    const DropdownMenuItem(
                      value: 'sport',
                      child: Text('Sport'),
                    ),
                    const DropdownMenuItem(
                      value: 'party',
                      child: Text('Party'),
                    ),
                    const DropdownMenuItem(
                      value: 'work',
                      child: Text('Work'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedOccasion = value;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Season
                DropdownButtonFormField<String>(
                  value: _selectedSeason,
                  decoration: const InputDecoration(
                    labelText: 'Season',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    const DropdownMenuItem(
                      value: 'spring',
                      child: Text('Spring'),
                    ),
                    const DropdownMenuItem(
                      value: 'summer',
                      child: Text('Summer'),
                    ),
                    const DropdownMenuItem(
                      value: 'fall',
                      child: Text('Fall'),
                    ),
                    const DropdownMenuItem(
                      value: 'winter',
                      child: Text('Winter'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedSeason = value;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Favorites only
                CheckboxListTile(
                  title: const Text('Favorites only'),
                  value: _showFavoritesOnly,
                  onChanged: (value) {
                    setState(() {
                      _showFavoritesOnly = value ?? false;
                    });
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _applyFilters();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showOutfitDetails(SavedOutfit outfit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Outfit Details',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${outfit.matchPercentage}% match • ${outfit.compatibilityScore.toStringAsFixed(1)} compatibility',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        outfit.isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: outfit.isFavorite
                            ? AppColors.secondary
                            : Colors.grey,
                      ),
                      onPressed: () {
                        context.read<SavedOutfitsBloc>().add(
                              ToggleFavorite(
                                outfitId: outfit.id,
                                isFavorite: !outfit.isFavorite,
                              ),
                            );
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),

              const Divider(),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Imagen grande
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: outfit.tryOnImageUrl,
                          width: double.infinity,
                          height: 400,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Explanation
                      if (outfit.outfit.explanation.isNotEmpty) ...[
                        const Text(
                          'Why this outfit works:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          outfit.outfit.explanation,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Tags
                      const Text(
                        'Tags:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (outfit.occasion != null)
                            Chip(
                              label: Text(outfit.occasion!),
                              backgroundColor: AppColors.primary.withValues(
                                alpha: 0.1,
                              ),
                            ),
                          ...outfit.colors.map(
                            (color) => Chip(
                              label: Text(color),
                              backgroundColor: AppColors.primary.withValues(
                                alpha: 0.1,
                              ),
                            ),
                          ),
                          ...outfit.styleTags.map(
                            (tag) => Chip(
                              label: Text(tag),
                              backgroundColor: AppColors.secondary.withValues(
                                alpha: 0.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Items
                      const Text(
                        'Items in this outfit:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...outfit.outfit.itemIds.map(
                        (itemId) => ListTile(
                          leading: const Icon(Icons.checkroom),
                          title: Text(itemId),
                          dense: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
