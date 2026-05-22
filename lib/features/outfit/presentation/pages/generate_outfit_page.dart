import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/keyboard_utils.dart';
import '../../../../core/widgets/app_page_app_bar.dart';
import '../bloc/outfit_generation_bloc.dart';
import '../bloc/outfit_generation_event.dart';
import '../bloc/outfit_generation_state.dart';
import '../../domain/outfit_models.dart';
import '../../../stylist/domain/chat_models.dart' as chat_models;

/// Página para generar outfits usando IA
class GenerateOutfitPage extends StatefulWidget {
  const GenerateOutfitPage({super.key});

  @override
  State<GenerateOutfitPage> createState() => _GenerateOutfitPageState();
}

class _GenerateOutfitPageState extends State<GenerateOutfitPage> {
  final TextEditingController _promptController = TextEditingController();
  bool _generateImage = false;

  @override
  void dispose() {
    hideKeyboard();
    _promptController.dispose();
    super.dispose();
  }

  void _generateOutfits() {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a description of the outfit you want'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    context.read<OutfitGenerationBloc>().add(
      GenerateOutfitsRequested(
        userPrompt: prompt,
        generateImage: _generateImage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppSubpageAppBar(
        title: 'Generate Outfit',
        subtitle: 'Prompt-based styling',
        actions: [
          IconButton(
            icon: const Icon(Icons.checkroom_outlined),
            tooltip: 'Saved outfits',
            onPressed: () => context.push('/saved-outfits'),
          ),
        ],
      ),
      body: BlocListener<OutfitGenerationBloc, OutfitGenerationState>(
        listener: (context, state) {
          if (state is OutfitGenerationError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${state.message}'),
                backgroundColor: AppColors.error,
                duration: const Duration(seconds: 4),
              ),
            );
          } else if (state is OutfitGenerationLoaded) {
            if (state.outfits.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'No outfits could be generated. Try a different description.',
                  ),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          }
        },
        child: BlocBuilder<OutfitGenerationBloc, OutfitGenerationState>(
          builder: (context, state) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  const Text(
                    'Describe the outfit you want',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tell us what kind of outfit you\'re looking for. For example: "casual outfit for the weekend" or "formal look for a wedding"',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),

                  // Prompt Input
                  TextField(
                    controller: _promptController,
                    decoration: InputDecoration(
                      labelText: 'Outfit description',
                      hintText: 'e.g., casual outfit for the weekend',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.auto_awesome),
                      suffixIcon: _promptController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _promptController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                    ),
                    maxLines: 3,
                    onChanged: (_) => setState(() {}),
                    enabled: state is! OutfitGenerationLoading,
                  ),
                  const SizedBox(height: 16),

                  // Generate Image Toggle
                  Card(
                    child: SwitchListTile(
                      title: const Text('Generate preview image'),
                      subtitle: const Text(
                        'Create a visual preview of the outfit (takes longer, uses more credits)',
                      ),
                      value: _generateImage,
                      onChanged: state is OutfitGenerationLoading
                          ? null
                          : (value) {
                              setState(() {
                                _generateImage = value;
                              });
                            },
                      activeThumbColor: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Generate Button
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: state is OutfitGenerationLoading
                          ? null
                          : _generateOutfits,
                      icon: state is OutfitGenerationLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(
                        state is OutfitGenerationLoading
                            ? _getLoadingText(state)
                            : 'Generate Outfits',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),

                  // Loading Indicator
                  if (state is OutfitGenerationLoading) ...[
                    const SizedBox(height: 32),
                    _buildLoadingIndicator(state),
                  ],

                  // Results
                  if (state is OutfitGenerationLoaded) ...[
                    const SizedBox(height: 32),
                    _buildResults(state),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _getLoadingText(OutfitGenerationLoading state) {
    switch (state.currentPhase) {
      case 'analyzing':
        return 'Analyzing your request...';
      case 'filtering':
        return 'Filtering your wardrobe...';
      case 'generating':
        return 'Generating outfits...';
      case 'creating_image':
        return 'Creating preview image...';
      default:
        return 'Processing...';
    }
  }

  Widget _buildLoadingIndicator(OutfitGenerationLoading state) {
    return Column(
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(
          _getLoadingText(state),
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildResults(OutfitGenerationLoaded state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Generated Outfits',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...state.outfits.asMap().entries.map((entry) {
          final index = entry.key;
          final outfit = entry.value;
          // Obtener la imagen específica para este outfit
          final imageUrl = state.getImageUrlForOutfit(outfit.id);
          return _buildOutfitCard(outfit, index + 1, imageUrl);
        }),
      ],
    );
  }

  Widget _buildOutfitCard(
    GeneratedOutfit outfit,
    int index,
    String? tryOnImageUrl,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Outfit $index',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        size: 16,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${outfit.matchPercentage}% match',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Try-On Image (si existe)
            if (tryOnImageUrl != null && tryOnImageUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  tryOnImageUrl,
                  width: double.infinity,
                  height: 300,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 300,
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 300,
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.error_outline, size: 48),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Explanation
            Text(outfit.explanation, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),

            // Items
            if (outfit.itemIds.isNotEmpty) ...[
              const Text(
                'Items:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: outfit.itemIds.map((itemId) {
                  return Chip(
                    label: Text(
                      itemId.substring(0, 8),
                      style: const TextStyle(fontSize: 10),
                    ),
                    backgroundColor: Colors.grey[200],
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Convertir GeneratedOutfit (outfit_models) a formato compatible con chat_models
                      final chatOutfit = chat_models.GeneratedOutfit(
                        id: outfit.id,
                        matchPercentage: outfit.matchPercentage,
                        itemIds: outfit.itemIds,
                        imageUrl: tryOnImageUrl ?? '',
                      );

                      context.push('/outfit-result', extra: chatOutfit);
                    },
                    icon: const Icon(Icons.visibility),
                    label: const Text('View Details'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Implementar generación de imagen para este outfit específico
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Try-on image generation coming soon!'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.image),
                    label: const Text('Try On'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
