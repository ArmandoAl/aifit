import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../core/services/firestore_service.dart';
import '../../wardrobe/domain/wardrobe_item_model.dart';
import '../../wardrobe/data/wardrobe_repository_impl.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/domain/user_identity_profile.dart';
import '../domain/outfit_models.dart';
import '../domain/saved_outfit_model.dart';
import '../data/saved_outfits_repository.dart';
import 'outfit_intent_analyzer.dart';
import 'wardrobe_search_algorithm.dart';
import 'outfit_generator_service.dart';
import 'virtual_try_on_service.dart';
import 'user_base_image_service.dart';

/// Servicio principal que orquesta todo el flujo de generación de outfits
///
/// Coordina las 4 fases:
/// 1. Análisis de intención
/// 2. Búsqueda y filtrado
/// 3. Generación de outfits
/// 4. Virtual Try-On
class OutfitService {
  final FirebaseFirestore _firestore = FirestoreService.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final WardrobeRepositoryImpl _wardrobeRepository = WardrobeRepositoryImpl();
  final ProfileRepository _profileRepository = ProfileRepository();
  final OutfitIntentAnalyzer _intentAnalyzer = OutfitIntentAnalyzer();
  final OutfitGeneratorService _outfitGenerator = OutfitGeneratorService();
  final VirtualTryOnService _tryOnService = VirtualTryOnService();
  final UserBaseImageService _baseImageService = UserBaseImageService();
  final SavedOutfitsRepository _savedOutfitsRepository = SavedOutfitsRepository();

  /// Flujo completo: Genera outfits y opcionalmente imagen de Virtual Try-On
  ///
  /// [userPrompt] - Prompt del usuario (ej: "outfit casual para el fin de semana")
  /// [generateImage] - Si true, genera imagen de Virtual Try-On (más costoso)
  ///
  /// Retorna lista de outfits generados y opcionalmente imagen de try-on
  Future<OutfitGenerationResult> generateCompleteOutfit({
    required String userPrompt,
    bool generateImage = false,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in");

    try {
      debugPrint('🚀 Starting complete outfit generation flow');
      debugPrint('   User prompt: "$userPrompt"');
      debugPrint('   Generate image: $generateImage');

      // FASE 1: Análisis de Intención
      debugPrint('\n📋 FASE 1: Analyzing user intent...');
      final intent = await _intentAnalyzer.analyzeUserPrompt(userPrompt);
      debugPrint('✅ Intent extracted: ${intent.toJson()}');

      // FASE 2: Búsqueda y Filtrado
      debugPrint('\n🔍 FASE 2: Filtering wardrobe...');
      final allItems = await _wardrobeRepository.getWardrobeItems();
      debugPrint('   Total items in wardrobe: ${allItems.length}');

      if (allItems.isEmpty) {
        throw Exception('Your wardrobe is empty. Please add some items first.');
      }

      final FilteredWardrobe filteredWardrobe =
          WardrobeSearchAlgorithm.filterWardrobe(
            allItems: allItems,
            intent: intent,
          );

      debugPrint('✅ Filtered wardrobe:');
      debugPrint('   - ${filteredWardrobe.tops.length} tops');
      debugPrint('   - ${filteredWardrobe.bottoms.length} bottoms');
      debugPrint('   - ${filteredWardrobe.shoes.length} shoes');
      debugPrint('   - ${filteredWardrobe.outerwear.length} outerwear');

      if (filteredWardrobe.isEmpty) {
        throw Exception('No items match your request. Try different criteria.');
      }

      // FASE 3: Generación de Outfits
      debugPrint('\n🎨 FASE 3: Generating outfits with AI...');
      final outfits = await _outfitGenerator.generateOutfits(
        filteredWardrobe: filteredWardrobe,
        intent: intent,
      );

      debugPrint('✅ Generated ${outfits.length} outfits');

      // Validar que los outfits tengan IDs válidos
      final validOutfits = outfits.where((outfit) {
        final hasTop = outfit.topId != null;
        final hasBottom = outfit.bottomId != null;
        final hasShoes = outfit.shoesId != null;
        return hasTop && hasBottom && hasShoes;
      }).toList();

      if (validOutfits.isEmpty) {
        throw Exception('Failed to generate valid outfits. Please try again.');
      }

      debugPrint('✅ ${validOutfits.length} valid outfits');

      // FASE 4: Virtual Try-On (Opcional) - Generar imágenes para los 3 outfits
      Map<String, String> tryOnImageUrls = {};
      if (generateImage && validOutfits.isNotEmpty) {
        debugPrint(
          '\n🖼️ FASE 4: Generating Virtual Try-On images for ${validOutfits.length} outfits...',
        );

        // Obtener fotos del usuario una sola vez (se reutilizan)
        final userContext = await _getUserTryOnContext(uid);

        // CICLO: Generar imagen para cada outfit (uno por uno para no sobrecargar)
        for (int i = 0; i < validOutfits.length; i++) {
          final outfit = validOutfits[i];
          debugPrint(
            '\n  📸 Generating image ${i + 1}/${validOutfits.length} for outfit: ${outfit.id}',
          );

          try {
            // Obtener URLs de imágenes de prendas para este outfit específico
            final itemImageUrls = await _getItemImageUrls(outfit);

            if (itemImageUrls.isEmpty) {
              debugPrint(
                '⚠️ No item images found for outfit ${outfit.id}, skipping...',
              );
              continue;
            }

            // Generar imagen (usa imagen base si existe, sino usa fotos individuales)
            final tryOnResult = await _tryOnService.generateTryOnImage(
              request: VirtualTryOnRequest(
                outfit: outfit,
                itemImageUrls: itemImageUrls,
                userBodyPhotoUrl: userContext.bodyPhotoUrl,
                userFacePhotoUrl: userContext.facePhotoUrl,
                aiFaceProfile: userContext.faceProfile,
                aiBodyProfile: userContext.bodyProfile,
              ),
              userId: uid,
            );

            if (tryOnResult.generatedImageUrl.isNotEmpty) {
              tryOnImageUrls[outfit.id] = tryOnResult.generatedImageUrl;
              debugPrint('  ✅ Image generated for outfit ${outfit.id}');
            } else {
              debugPrint(
                '  ⚠️ Failed to generate image for outfit ${outfit.id}',
              );
            }
          } catch (e) {
            debugPrint(
              '  ❌ Error generating image for outfit ${outfit.id}: $e',
            );
            // Continuar con el siguiente outfit aunque este falle
            continue;
          }
        }

        debugPrint(
          '✅ Virtual Try-On: ${tryOnImageUrls.length}/${validOutfits.length} images generated',
        );
      }

      // Guardar outfits en Firestore con etiquetas y metadata
      await _saveOutfitsToFirestore(
        uid,
        validOutfits,
        intent,
        tryOnImageUrls,
      );

      return OutfitGenerationResult(
        outfits: validOutfits,
        intent: intent,
        tryOnImageUrl: tryOnImageUrls.isNotEmpty
            ? tryOnImageUrls.values.first
            : null, // Backward compatibility
        tryOnImageUrls: tryOnImageUrls,
      );
    } catch (e) {
      if (e is FirebaseAIException) {
        debugPrint('❌ Firebase AI Error: ${e.message}');
        debugPrint('❌ Code: $e');
        throw Exception('AI Error: ${e.message}');
      } else {
        debugPrint('❌ Error generating outfits: $e');
        throw Exception('Failed to generate outfits: $e');
      }
    }
  }

  /// Obtiene URLs de imágenes de las prendas del outfit
  Future<List<String>> _getItemImageUrls(GeneratedOutfit outfit) async {
    final itemIds = outfit.itemIds;
    final urls = <String>[];

    for (final itemId in itemIds) {
      try {
        final doc = await _firestore
            .collection('wardrobe_items')
            .doc(itemId)
            .get();
        if (doc.exists) {
          final imageUrl = doc.data()?['imageUrl'] as String?;
          if (imageUrl != null && imageUrl.isNotEmpty) {
            urls.add(imageUrl);
          }
        }
      } catch (e) {
        debugPrint('⚠️ Failed to get image URL for item $itemId: $e');
      }
    }

    return urls;
  }

  Future<_UserTryOnContext> _getUserTryOnContext(String userId) async {
    try {
      final profileData = await _profileRepository.getUserProfile(userId);
      if (profileData == null) return const _UserTryOnContext();

      final faceProfile = profileData['aiFaceProfile'] is Map<String, dynamic>
          ? AiFaceProfile.fromJson(
              profileData['aiFaceProfile'] as Map<String, dynamic>,
            )
          : null;
      final bodyProfile = profileData['aiBodyProfile'] is Map<String, dynamic>
          ? AiBodyProfile.fromJson(
              profileData['aiBodyProfile'] as Map<String, dynamic>,
            )
          : null;

      final bodyPhoto = profileData['bodyPhotos'] != null
          ? (profileData['bodyPhotos'] as List<dynamic>).firstOrNull
                ?.toString()
          : null;

      final facePhoto = profileData['facePhotos'] != null
          ? (profileData['facePhotos'] as List<dynamic>).firstOrNull
                ?.toString()
          : null;

      return _UserTryOnContext(
        bodyPhotoUrl: bodyPhoto,
        facePhotoUrl: facePhoto,
        faceProfile: faceProfile?.isEmpty == false ? faceProfile : null,
        bodyProfile: bodyProfile?.isEmpty == false ? bodyProfile : null,
      );
    } catch (e) {
      debugPrint('⚠️ Failed to get user try-on context: $e');
      return const _UserTryOnContext();
    }
  }

  /// Guarda outfits generados en Firestore con etiquetas y metadata
  Future<void> _saveOutfitsToFirestore(
    String userId,
    List<GeneratedOutfit> outfits,
    OutfitIntent intent,
    Map<String, String> tryOnImageUrls,
  ) async {
    try {
      debugPrint('💾 Saving ${outfits.length} outfits to Firestore with tags...');

      final savedOutfits = <SavedOutfit>[];

      for (final outfit in outfits) {
        // Obtener URL de imagen para este outfit
        final imageUrl = tryOnImageUrls[outfit.id] ?? '';

        // Crear SavedOutfit con todas las etiquetas y metadata
        final savedOutfit = SavedOutfit.fromGeneratedOutfit(
          outfit: outfit,
          intent: intent,
          userId: userId,
          tryOnImageUrl: imageUrl,
        );

        savedOutfits.add(savedOutfit);
      }

      // Guardar en batch
      await _savedOutfitsRepository.saveOutfits(savedOutfits);

      debugPrint('✅ Saved ${savedOutfits.length} outfits to Firestore with tags');
    } catch (e) {
      debugPrint('⚠️ Failed to save outfits to Firestore: $e');
      // No lanzar error - es opcional, pero loguear para debugging
    }
  }
}

class _UserTryOnContext {
  final String? bodyPhotoUrl;
  final String? facePhotoUrl;
  final AiFaceProfile? faceProfile;
  final AiBodyProfile? bodyProfile;

  const _UserTryOnContext({
    this.bodyPhotoUrl,
    this.facePhotoUrl,
    this.faceProfile,
    this.bodyProfile,
  });
}

/// Resultado de la generación completa de outfit
class OutfitGenerationResult {
  final List<GeneratedOutfit> outfits;
  final OutfitIntent intent;
  final String? tryOnImageUrl; // Deprecated: usar tryOnImageUrls
  final Map<String, String> tryOnImageUrls; // Map<outfitId, imageUrl>

  OutfitGenerationResult({
    required this.outfits,
    required this.intent,
    this.tryOnImageUrl,
    Map<String, String>? tryOnImageUrls,
  }) : tryOnImageUrls = tryOnImageUrls ?? {};

  /// Obtiene la URL de imagen para un outfit específico
  String? getImageUrlForOutfit(String outfitId) {
    return tryOnImageUrls[outfitId] ?? tryOnImageUrl;
  }
}
