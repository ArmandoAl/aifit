import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../core/services/firestore_service.dart';
import '../../wardrobe/data/wardrobe_repository_impl.dart';
import '../../wardrobe/domain/wardrobe_item_model.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/domain/user_identity_profile.dart';
import '../domain/outfit_models.dart';
import '../domain/saved_outfit_model.dart';
import '../data/saved_outfits_repository.dart';
import 'outfit_intent_analyzer.dart';
import 'wardrobe_search_algorithm.dart';
import 'outfit_generator_service.dart';
import 'virtual_try_on_service.dart';

/// Servicio principal que orquesta todo el flujo de generación de outfits
///
/// Fases 1–3: intención → filtro → outfits (rápido, muestra UI).
/// Fase 4: try-on bajo demanda o solo el primer look (P1 progresivo).
class OutfitService {
  final FirebaseFirestore _firestore = FirestoreService.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final WardrobeRepositoryImpl _wardrobeRepository = WardrobeRepositoryImpl();
  final ProfileRepository _profileRepository = ProfileRepository();
  final OutfitIntentAnalyzer _intentAnalyzer = OutfitIntentAnalyzer();
  final OutfitGeneratorService _outfitGenerator = OutfitGeneratorService();
  final VirtualTryOnService _tryOnService = VirtualTryOnService();
  final SavedOutfitsRepository _savedOutfitsRepository =
      SavedOutfitsRepository();

  _UserTryOnContext? _cachedTryOnContext;
  String? _cachedTryOnUserId;

  /// Fases 1–3: genera outfits; persistencia Firestore en segundo plano.
  ///
  /// Si [precomputedIntent] viene del chat, se omite DeepSeek.
  Future<OutfitGenerationResult> generateOutfitSuggestions({
    required String userPrompt,
    OutfitIntent? precomputedIntent,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not logged in');

    try {
      debugPrint('🚀 Outfit suggestions (phases 1–3)');
      debugPrint('   Prompt: "$userPrompt"');

      final intent = precomputedIntent ??
          await _intentAnalyzer.analyzeUserPrompt(userPrompt);

      if (precomputedIntent != null) {
        debugPrint('✅ Using precomputed intent from stylist chat (DeepSeek skipped)');
      }

      final allItems = await _wardrobeRepository.getWardrobeItems();

      if (allItems.isEmpty) {
        throw Exception('Your wardrobe is empty. Please add some items first.');
      }

      final wardrobeImageUrlsByItemId = _imageUrlsByItemId(allItems);

      final filteredWardrobe = WardrobeSearchAlgorithm.filterWardrobe(
        allItems: allItems,
        intent: intent,
      );

      if (filteredWardrobe.isEmpty) {
        throw Exception('No items match your request. Try different criteria.');
      }

      if (filteredWardrobe.tops.isEmpty ||
          filteredWardrobe.bottoms.isEmpty ||
          filteredWardrobe.shoes.isEmpty) {
        final missing = <String>[
          if (filteredWardrobe.tops.isEmpty) 'superior',
          if (filteredWardrobe.bottoms.isEmpty) 'inferior (pantalón/falda)',
          if (filteredWardrobe.shoes.isEmpty) 'calzado',
        ];
        throw Exception(
          'Con este pedido no hay suficientes prendas en el armario filtrado. '
          'Falta: ${missing.join(', ')}. Por ejemplo pidiste negro pero quizá '
          'no tienes pantalón/falda negro etiquetado, o el filtro lo excluyó. '
          'Prueba otros colores, quita algún matiz o súbe más prendas.',
        );
      }

      final outfits = await _outfitGenerator.generateOutfits(
        filteredWardrobe: filteredWardrobe,
        intent: intent,
      );

      final validOutfits =
          outfits.where((outfit) => outfit.hasCompleteLook).toList();

      if (validOutfits.isEmpty) {
        if (outfits.isEmpty) {
          throw Exception(
            'La IA no devolvió ningún outfit. Intenta de nuevo o reformula '
            'el pedido.',
          );
        }
        final perOutfit = outfits
            .map(
              (o) =>
                  '[${o.id.isEmpty ? "sin_id" : o.id}] falta(n): '
                  '${o.missingFieldsSummary} '
                  '(top="${o.topId ?? "—"}", bottom="${o.bottomId ?? "—"}", '
                  'shoes="${o.shoesId ?? "—"}")',
            )
            .join(' | ');
        debugPrint(
          '❌ Ningún outfit con top+bottom+zapatos válidos. $perOutfit',
        );
        throw Exception(
          'La IA armó propuestas pero sin IDs válidos para armar el look '
          '(hacen falta prenda superior, inferior y calzado). '
          'Detalle: $perOutfit '
          'Suele pasar cuando el modelo envía otros nombres de campo '
          '(p. ej. top_id); si persiste, intenta con menos filtros (colores).',
        );
      }

      unawaited(
        _saveOutfitsToFirestore(uid, validOutfits, intent, {}),
      );

      return OutfitGenerationResult(
        outfits: validOutfits,
        intent: intent,
        wardrobeImageUrlsByItemId: wardrobeImageUrlsByItemId,
      );
    } catch (e) {
      if (e is FirebaseAIException) {
        throw Exception('AI Error: ${e.message}');
      }
      if (e is Exception) rethrow;
      throw Exception('Failed to generate outfits: $e');
    }
  }

  /// Try-on de un solo outfit (fase 4 bajo demanda).
  Future<String?> generateTryOnForOutfit({
    required GeneratedOutfit outfit,
    required OutfitIntent intent,
    Map<String, String>? wardrobeImageUrlsByItemId,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not logged in');

    try {
      debugPrint('🖼️ Try-on for outfit ${outfit.id}');

      final itemImageUrls = wardrobeImageUrlsByItemId != null
          ? _resolveItemImageUrls(outfit, wardrobeImageUrlsByItemId)
          : await _getItemImageUrls(outfit);

      if (itemImageUrls.isEmpty) {
        debugPrint('⚠️ No garment images for outfit ${outfit.id}');
        return null;
      }

      final userContext = await _getUserTryOnContext(uid);

      final tryOnResult = await _tryOnService.generateTryOnImage(
        request: VirtualTryOnRequest(
          outfit: outfit,
          itemImageUrls: itemImageUrls,
          userBodyPhotoUrl: userContext.bodyPhotoUrl,
          userFacePhotoUrl: userContext.facePhotoUrl,
          identityProfile: userContext.identityProfile,
        ),
        userId: uid,
      );

      final url = tryOnResult.generatedImageUrl;
      if (url.isEmpty) return null;

      unawaited(
        _savedOutfitsRepository.updateTryOnImageUrl(outfit.id, url),
      );
      debugPrint('✅ Try-on ready for ${outfit.id}');

      return url;
    } catch (e) {
      debugPrint('❌ Try-on failed for ${outfit.id}: $e');
      rethrow;
    }
  }

  /// Compatibilidad: sugerencias + try-on solo del primer look si [generateImage].
  Future<OutfitGenerationResult> generateCompleteOutfit({
    required String userPrompt,
    bool generateImage = false,
    OutfitIntent? precomputedIntent,
  }) async {
    final base = await generateOutfitSuggestions(
      userPrompt: userPrompt,
      precomputedIntent: precomputedIntent,
    );

    if (!generateImage || base.outfits.isEmpty) {
      return base;
    }

    final first = base.outfits.first;
    try {
      final url = await generateTryOnForOutfit(
        outfit: first,
        intent: base.intent,
        wardrobeImageUrlsByItemId: base.wardrobeImageUrlsByItemId,
      );
      if (url == null || url.isEmpty) return base;

      return OutfitGenerationResult(
        outfits: base.outfits,
        intent: base.intent,
        tryOnImageUrl: url,
        tryOnImageUrls: {first.id: url},
        wardrobeImageUrlsByItemId: base.wardrobeImageUrlsByItemId,
      );
    } catch (e) {
      debugPrint('⚠️ First try-on failed, returning outfits without image: $e');
      return base;
    }
  }

  static Map<String, String> _imageUrlsByItemId(List<WardrobeItem> items) {
    return {
      for (final item in items)
        if (item.id.isNotEmpty && item.imageUrl.isNotEmpty)
          item.id: item.imageUrl,
    };
  }

  static List<String> _resolveItemImageUrls(
    GeneratedOutfit outfit,
    Map<String, String> wardrobeImageUrlsByItemId,
  ) {
    final urls = <String>[];
    for (final itemId in outfit.itemIds) {
      final url = wardrobeImageUrlsByItemId[itemId];
      if (url != null && url.isNotEmpty) {
        urls.add(url);
      }
    }
    return urls;
  }

  Future<List<String>> _getItemImageUrls(GeneratedOutfit outfit) async {
    final urls = <String>[];

    for (final itemId in outfit.itemIds) {
      try {
        final doc =
            await _firestore.collection('wardrobe_items').doc(itemId).get();
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
    if (_cachedTryOnUserId == userId && _cachedTryOnContext != null) {
      return _cachedTryOnContext!;
    }

    try {
      final profileData = await _profileRepository.getUserProfile(userId);
      if (profileData == null) {
        _cachedTryOnContext = const _UserTryOnContext();
        _cachedTryOnUserId = userId;
        return _cachedTryOnContext!;
      }

      final identityProfile = IdentityProfile.fromFirestoreUser(profileData);

      final bodyPhoto = profileData['bodyPhotos'] != null
          ? (profileData['bodyPhotos'] as List<dynamic>).firstOrNull?.toString()
          : null;

      final facePhoto = profileData['facePhotos'] != null
          ? (profileData['facePhotos'] as List<dynamic>).firstOrNull?.toString()
          : null;

      _cachedTryOnContext = _UserTryOnContext(
        bodyPhotoUrl: bodyPhoto,
        facePhotoUrl: facePhoto,
        identityProfile: identityProfile.isEmpty ? null : identityProfile,
      );
      _cachedTryOnUserId = userId;
      return _cachedTryOnContext!;
    } catch (e) {
      debugPrint('⚠️ Failed to get user try-on context: $e');
      return const _UserTryOnContext();
    }
  }

  Future<void> _saveOutfitsToFirestore(
    String userId,
    List<GeneratedOutfit> outfits,
    OutfitIntent intent,
    Map<String, String> tryOnImageUrls,
  ) async {
    try {
      final savedOutfits = outfits
          .map(
            (outfit) => SavedOutfit.fromGeneratedOutfit(
              outfit: outfit,
              intent: intent,
              userId: userId,
              tryOnImageUrl: tryOnImageUrls[outfit.id] ?? '',
            ),
          )
          .toList();

      await _savedOutfitsRepository.saveOutfits(savedOutfits);
      debugPrint('✅ Saved ${savedOutfits.length} outfits to Firestore');
    } catch (e) {
      debugPrint('⚠️ Failed to save outfits to Firestore: $e');
    }
  }
}

class _UserTryOnContext {
  final String? bodyPhotoUrl;
  final String? facePhotoUrl;
  final IdentityProfile? identityProfile;

  const _UserTryOnContext({
    this.bodyPhotoUrl,
    this.facePhotoUrl,
    this.identityProfile,
  });
}

/// Resultado de la generación de outfits
class OutfitGenerationResult {
  final List<GeneratedOutfit> outfits;
  final OutfitIntent intent;
  final String? tryOnImageUrl;
  final Map<String, String> tryOnImageUrls;
  final Map<String, String> wardrobeImageUrlsByItemId;

  OutfitGenerationResult({
    required this.outfits,
    required this.intent,
    this.tryOnImageUrl,
    Map<String, String>? tryOnImageUrls,
    Map<String, String>? wardrobeImageUrlsByItemId,
  })  : tryOnImageUrls = tryOnImageUrls ?? {},
        wardrobeImageUrlsByItemId = wardrobeImageUrlsByItemId ?? {};

  String? getImageUrlForOutfit(String outfitId) {
    return tryOnImageUrls[outfitId] ?? tryOnImageUrl;
  }
}
