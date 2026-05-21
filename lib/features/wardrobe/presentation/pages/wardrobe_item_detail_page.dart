import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/firebase_ai_service_impl.dart';
import '../../domain/wardrobe_ai_metadata.dart';
import '../../domain/wardrobe_analysis_prompt.dart';
import '../../domain/wardrobe_item_model.dart';
import '../../domain/wardrobe_palette.dart';
import '../../data/wardrobe_repository_impl.dart';
import '../bloc/wardrobe_bloc.dart';
import '../bloc/wardrobe_event.dart';
import '../../../stylist/domain/chat_models.dart';
import '../../../outfit/services/outfit_service.dart';
import '../../../simulation/presentation/pages/outfit_result_page.dart';

class WardrobeItemDetailPage extends StatefulWidget {
  final WardrobeItem item;

  const WardrobeItemDetailPage({super.key, required this.item});

  @override
  State<WardrobeItemDetailPage> createState() => _WardrobeItemDetailPageState();
}

class _WardrobeItemDetailPageState extends State<WardrobeItemDetailPage> {
  final WardrobeRepositoryImpl _repository = WardrobeRepositoryImpl();
  final OutfitService _outfitService = OutfitService();
  final FirebaseAIServiceImpl _aiService = FirebaseAIServiceImpl();
  final Dio _dio = Dio();

  late WardrobeItem _currentItem;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isGeneratingOutfit = false;
  bool _isAnalyzing = false;

  // Form controllers
  final _brandController = TextEditingController();
  final _outfitPromptController = TextEditingController();

  // Available options
  List<String> get _paletteColors => WardrobePalette.standardColors;
  List<String> get _paletteStyleTags => WardrobePalette.standardStyleTags;
  List<String> get _paletteSeasons => WardrobePalette.standardSeasons;

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item.copyWith(
      colors: WardrobePalette.normalizeColors(widget.item.colors),
      styleTags: WardrobePalette.normalizeStyleTags(widget.item.styleTags),
      season: WardrobePalette.normalizeSeasons(widget.item.season),
    );
    _brandController.text = _currentItem.brand ?? '';
  }

  List<String> get _extraColors =>
      WardrobePalette.customColors(_currentItem.colors);

  List<String> get _extraStyleTags =>
      WardrobePalette.customStyleTags(_currentItem.styleTags);

  @override
  void dispose() {
    _brandController.dispose();
    _outfitPromptController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() {
      _isSaving = true;
    });

    try {
      await _repository.updateWardrobeItem(_currentItem);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );

        // Reload wardrobe items
        context.read<WardrobeBloc>().add(const WardrobeLoadRequested());

        setState(() {
          _isEditing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating item: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _generateOutfit() async {
    if (_outfitPromptController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter instructions for the outfit'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isGeneratingOutfit = true;
    });

    try {
      final prompt =
          'Create an outfit that must include wardrobe item id ${_currentItem.id} '
          '(${_currentItem.subType}, ${_currentItem.type}). '
          '${_outfitPromptController.text.trim()}';

      final result = await _outfitService.generateCompleteOutfit(
        userPrompt: prompt,
        generateImage: true,
      );

      if (result.outfits.isEmpty) {
        throw Exception(
          'Could not build an outfit with your current wardrobe.',
        );
      }

      final pipelineOutfit = result.outfits.first;
      final imageUrl = result.getImageUrlForOutfit(pipelineOutfit.id) ?? '';

      if (mounted) {
        final outfit = GeneratedOutfit(
          id: pipelineOutfit.id,
          imageUrl: imageUrl,
          matchPercentage: pipelineOutfit.matchPercentage,
          itemIds: pipelineOutfit.itemIds,
        );
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => OutfitResultPage(outfit: outfit),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating outfit: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingOutfit = false;
        });
      }
    }
  }

  void _toggleStyleTag(String tag) {
    setState(() {
      final tags = List<String>.from(_currentItem.styleTags);
      if (tags.contains(tag)) {
        tags.remove(tag);
      } else {
        tags.add(tag);
      }
      _currentItem = _currentItem.copyWith(styleTags: tags);
    });
  }

  void _toggleSeason(String season) {
    setState(() {
      final seasons = List<String>.from(_currentItem.season);
      if (seasons.contains(season)) {
        seasons.remove(season);
      } else {
        seasons.add(season);
      }
      _currentItem = _currentItem.copyWith(season: seasons);
    });
  }

  void _toggleColor(String color) {
    setState(() {
      final colors = List<String>.from(_currentItem.colors);
      if (colors.contains(color)) {
        colors.remove(color);
      } else {
        colors.add(color);
      }
      _currentItem = _currentItem.copyWith(colors: colors);
    });
  }

  Future<void> _analyzeWithAI() async {
    setState(() {
      _isAnalyzing = true;
    });

    try {
      // 1. Download image from URL
      debugPrint('📥 Downloading image from: ${_currentItem.imageUrl}');
      final tempDir = await getTemporaryDirectory();
      final imageFile = File(
        '${tempDir.path}/analyze_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final response = await _dio.get(
        _currentItem.imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      await imageFile.writeAsBytes(response.data);
      debugPrint('✅ Image downloaded to: ${imageFile.path}');

      // 2. Analyze with AI
      debugPrint('🔍 Analyzing image with AI...');
      final aiData = await _aiService.analyzeImageToJson(
        image: imageFile,
        promptInstruction: WardrobeAnalysisPrompt.fullAnalysis,
      );

      debugPrint('✅ AI Analysis completed: $aiData');

      final metadata = WardrobeAiMetadata.fromAnalysisJson(aiData);

      setState(() {
        _currentItem = _currentItem.copyWith(
          name: aiData['subType']?.toString() ?? _currentItem.name,
          type: aiData['type']?.toString() ?? _currentItem.type,
          subType: aiData['subType']?.toString() ?? _currentItem.subType,
          colors: WardrobePalette.normalizeColors(
            (aiData['colors'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [],
          ),
          styleTags: WardrobePalette.normalizeStyleTags(
            (aiData['styleTags'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [],
          ),
          season: WardrobePalette.normalizeSeasons(
            (aiData['season'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [],
          ),
          aiMetadata: metadata.isEmpty ? null : metadata,
        );
      });

      // 4. Save to Firestore
      await _repository.updateWardrobeItem(_currentItem);

      // 5. Update brand controller
      _brandController.text = _currentItem.brand ?? '';

      // 6. Reload wardrobe
      if (mounted) {
        debugPrint('Reloading wardrobe');
        context.read<WardrobeBloc>().add(const WardrobeLoadRequested());
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✅ Análisis completo guardado (colores, tags, temporada y metadatos IA v2).',
            ),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 3),
          ),
        );
      }

      // Clean up temp file
      try {
        await imageFile.delete();
      } catch (_) {
        // Ignore cleanup errors
      }
    } catch (e) {
      debugPrint('❌ Error analyzing image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error analyzing image: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Item' : 'Item Details'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            ),
          if (_isEditing)
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              onPressed: _isSaving ? null : _saveChanges,
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                image: DecorationImage(
                  image: CachedNetworkImageProvider(_currentItem.imageUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Basic Info
                  Text(
                    _currentItem.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_currentItem.type} • ${_currentItem.subType}',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),

                  // Analyze with AI Button
                  if (!_isEditing) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.secondary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                color: AppColors.secondary,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'AI Analysis',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Analyze this item with AI to automatically detect colors, style tags, and season.',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isAnalyzing ? null : _analyzeWithAI,
                              icon: _isAnalyzing
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const Icon(Icons.auto_awesome),
                              label: Text(
                                _isAnalyzing
                                    ? 'Analyzing...'
                                    : 'Analyze with AI',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Brand Section
                  if (_isEditing) ...[
                    TextField(
                      controller: _brandController,
                      decoration: const InputDecoration(
                        labelText: 'Brand',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.label_outline),
                      ),
                      onChanged: (value) {
                        _currentItem = _currentItem.copyWith(
                          brand: value.isEmpty ? null : value,
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ] else ...[
                    if (_currentItem.brand != null &&
                        _currentItem.brand!.isNotEmpty)
                      _InfoRow(
                        icon: Icons.label_outline,
                        label: 'Brand',
                        value: _currentItem.brand!,
                      ),
                  ],

                  // Colors Section
                  _SectionTitle(title: 'Colors', isEditing: _isEditing),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ..._paletteColors.map((color) {
                        final isSelected = _currentItem.colors.contains(color);
                        return FilterChip(
                          label: Text(color),
                          selected: isSelected,
                          onSelected: _isEditing
                              ? (_) => _toggleColor(color)
                              : null,
                          selectedColor: AppColors.primary.withValues(
                            alpha: 0.2,
                          ),
                          checkmarkColor: AppColors.primary,
                          backgroundColor: Colors.white,
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.grey.shade300,
                          ),
                        );
                      }),
                      ..._extraColors.map((color) {
                        return FilterChip(
                          label: Text(color),
                          selected: true,
                          onSelected: _isEditing
                              ? (_) => _toggleColor(color)
                              : null,
                          selectedColor: AppColors.secondary.withValues(
                            alpha: 0.2,
                          ),
                          checkmarkColor: AppColors.secondary,
                          backgroundColor: Colors.white,
                          side: BorderSide(
                            color: AppColors.secondary.withValues(alpha: 0.5),
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Style Tags Section
                  _SectionTitle(title: 'Style Tags', isEditing: _isEditing),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ..._paletteStyleTags.map((tag) {
                        final isSelected = _currentItem.styleTags.contains(tag);
                        return FilterChip(
                          label: Text(tag),
                          selected: isSelected,
                          onSelected: _isEditing
                              ? (_) => _toggleStyleTag(tag)
                              : null,
                          selectedColor: AppColors.primary.withValues(
                            alpha: 0.2,
                          ),
                          checkmarkColor: AppColors.primary,
                          backgroundColor: Colors.white,
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.grey.shade300,
                          ),
                        );
                      }),
                      ..._extraStyleTags.map((tag) {
                        return FilterChip(
                          label: Text(tag),
                          selected: true,
                          onSelected: _isEditing
                              ? (_) => _toggleStyleTag(tag)
                              : null,
                          selectedColor: AppColors.secondary.withValues(
                            alpha: 0.2,
                          ),
                          checkmarkColor: AppColors.secondary,
                          backgroundColor: Colors.white,
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Season Section
                  _SectionTitle(title: 'Season', isEditing: _isEditing),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _paletteSeasons.map((season) {
                      final isSelected = _currentItem.season.contains(season);
                      return FilterChip(
                        label: Text(season),
                        selected: isSelected,
                        onSelected: _isEditing
                            ? (selected) {
                                _toggleSeason(season);
                              }
                            : null,
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        checkmarkColor: AppColors.primary,
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.grey.shade300,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),

                  // Generate Outfit Section
                  if (!_isEditing) ...[
                    const Divider(),
                    const SizedBox(height: 16),
                    const Text(
                      'Generate Outfit with AI',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _outfitPromptController,
                      decoration: InputDecoration(
                        labelText:
                            'Instructions (e.g., "casual day out", "formal event")',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.auto_awesome),
                        suffixIcon: IconButton(
                          icon: _isGeneratingOutfit
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send),
                          onPressed: _isGeneratingOutfit
                              ? null
                              : _generateOutfit,
                        ),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isGeneratingOutfit ? null : _generateOutfit,
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Generate Outfit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final bool isEditing;

  const _SectionTitle({required this.title, required this.isEditing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        if (isEditing) ...[
          const SizedBox(width: 8),
          Text(
            '(Tap to select)',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
