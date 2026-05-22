import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../../../core/services/firestore_service.dart';
import '../domain/saved_outfit_model.dart';

/// Repository para outfits guardados (Firestore + fallback Storage).
class SavedOutfitsRepository {
  final FirebaseFirestore _firestore = FirestoreService.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Guarda un outfit en Firestore
  Future<void> saveOutfit(SavedOutfit savedOutfit) async {
    try {
      debugPrint('💾 Saving outfit to Firestore: ${savedOutfit.id}');

      await _firestore
          .collection('saved_outfits')
          .doc(savedOutfit.id)
          .set(savedOutfit.toJson());

      debugPrint('✅ Outfit saved successfully');
    } catch (e) {
      debugPrint('❌ Error saving outfit: $e');
      throw Exception('Failed to save outfit: $e');
    }
  }

  /// Guarda múltiples outfits en batch
  Future<void> saveOutfits(List<SavedOutfit> outfits) async {
    try {
      debugPrint('💾 Saving ${outfits.length} outfits to Firestore...');

      final batch = _firestore.batch();

      for (final outfit in outfits) {
        final ref = _firestore.collection('saved_outfits').doc(outfit.id);
        batch.set(ref, outfit.toJson());
      }

      await batch.commit();
      debugPrint('✅ ${outfits.length} outfits saved successfully');
    } catch (e) {
      debugPrint('❌ Error saving outfits: $e');
      throw Exception('Failed to save outfits: $e');
    }
  }

  /// Obtiene outfits: Firestore primero; completa con imágenes try-on en Storage.
  Future<List<SavedOutfit>> getSavedOutfits({
    String? filterByOccasion,
    String? filterBySeason,
    List<String>? filterByColors,
    List<String>? filterByStyleTags,
    bool? onlyFavorites,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      debugPrint('⚠️ No user logged in');
      return [];
    }

    debugPrint('📦 Loading saved outfits for user: $userId');

    try {
      var firestoreOutfits = await _loadFromFirestore(
        userId: userId,
        filterByOccasion: filterByOccasion,
        filterBySeason: filterBySeason,
        onlyFavorites: onlyFavorites,
      );

      firestoreOutfits = _applyClientFilters(
        firestoreOutfits,
        filterByColors: filterByColors,
        filterByStyleTags: filterByStyleTags,
      );

      debugPrint('📄 Firestore: ${firestoreOutfits.length} outfits');

      // Sin filtros de Firestore: incluir try-ons que solo existen en Storage
      final canMergeStorage = filterByOccasion == null &&
          filterBySeason == null &&
          onlyFavorites != true;

      if (!canMergeStorage) {
        debugPrint('✅ Loaded ${firestoreOutfits.length} saved outfits');
        return firestoreOutfits;
      }

      final storageOutfits = await _loadFromStorage(userId);
      debugPrint('🗄️ Storage try-ons: ${storageOutfits.length} images');

      final merged = _mergeFirestoreAndStorage(
        firestoreOutfits,
        storageOutfits,
      );

      await _backfillStorageOnlyToFirestore(merged);

      debugPrint('✅ Loaded ${merged.length} saved outfits (merged)');
      return merged;
    } catch (e, stack) {
      debugPrint('❌ Error loading saved outfits: $e');
      debugPrint('$stack');

      // Si Firestore falla, al menos mostrar lo que hay en Storage
      try {
        final storageOnly = await _loadFromStorage(userId);
        debugPrint(
          '⚠️ Fallback: returning ${storageOnly.length} outfits from Storage',
        );
        return _applyClientFilters(
          storageOnly,
          filterByColors: filterByColors,
          filterByStyleTags: filterByStyleTags,
        );
      } catch (storageError) {
        debugPrint('❌ Storage fallback failed: $storageError');
        rethrow;
      }
    }
  }

  Future<List<SavedOutfit>> _loadFromFirestore({
    required String userId,
    String? filterByOccasion,
    String? filterBySeason,
    bool? onlyFavorites,
  }) async {
    Query query = _firestore
        .collection('saved_outfits')
        .where('userId', isEqualTo: userId);

    if (filterByOccasion != null) {
      query = query.where('occasion', isEqualTo: filterByOccasion);
    }
    if (filterBySeason != null) {
      query = query.where('season', isEqualTo: filterBySeason);
    }
    if (onlyFavorites == true) {
      query = query.where('isFavorite', isEqualTo: true);
    }

    query = query.orderBy('createdAt', descending: true);

    final snapshot = await query.get();

    return snapshot.docs
        .map(
          (doc) => SavedOutfit.fromJson({
            ...doc.data() as Map<String, dynamic>,
            'id': doc.id,
          }),
        )
        .toList();
  }

  Future<List<SavedOutfit>> _loadFromStorage(String userId) async {
    try {
      final ref = _storage.ref('users/$userId/outfits');
      final listResult = await ref.listAll();
      final outfits = <SavedOutfit>[];

      for (final item in listResult.items) {
        if (!item.name.startsWith('tryon_')) continue;

        final url = await item.getDownloadURL();
        final createdAt = _parseTryOnCreatedAt(item.name);

        outfits.add(
          SavedOutfit.fromStorageTryOn(
            userId: userId,
            tryOnImageUrl: url,
            storageFileName: item.name,
            createdAt: createdAt,
          ),
        );
      }

      outfits.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return outfits;
    } catch (e) {
      debugPrint('⚠️ Could not list Storage outfits: $e');
      return [];
    }
  }

  DateTime _parseTryOnCreatedAt(String fileName) {
    final match = RegExp(r'tryon_(\d+)').firstMatch(fileName);
    if (match != null) {
      final ms = int.tryParse(match.group(1)!);
      if (ms != null) {
        return DateTime.fromMillisecondsSinceEpoch(ms);
      }
    }
    return DateTime.now();
  }

  List<SavedOutfit> _mergeFirestoreAndStorage(
    List<SavedOutfit> firestore,
    List<SavedOutfit> storage,
  ) {
    final knownUrls = firestore.map((o) => o.tryOnImageUrl).toSet();
    final merged = List<SavedOutfit>.from(firestore);

    for (final item in storage) {
      if (item.tryOnImageUrl.isEmpty) continue;
      if (knownUrls.contains(item.tryOnImageUrl)) continue;
      merged.add(item);
      knownUrls.add(item.tryOnImageUrl);
    }

    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }

  List<SavedOutfit> _applyClientFilters(
    List<SavedOutfit> outfits, {
    List<String>? filterByColors,
    List<String>? filterByStyleTags,
  }) {
    var result = outfits;
    if (filterByColors != null && filterByColors.isNotEmpty) {
      result = result
          .where(
            (o) => o.colors.any((c) => filterByColors.contains(c)),
          )
          .toList();
    }
    if (filterByStyleTags != null && filterByStyleTags.isNotEmpty) {
      result = result
          .where(
            (o) => o.styleTags.any((t) => filterByStyleTags.contains(t)),
          )
          .toList();
    }
    return result;
  }

  /// Migra try-ons de Storage que aún no tienen documento en Firestore.
  Future<void> _backfillStorageOnlyToFirestore(List<SavedOutfit> merged) async {
    final toBackfill =
        merged.where((o) => o.id.startsWith('storage_')).toList();
    if (toBackfill.isEmpty) return;

    debugPrint('🔄 Backfilling ${toBackfill.length} outfits to Firestore...');
    try {
      await saveOutfits(toBackfill);
    } catch (e) {
      debugPrint('⚠️ Backfill skipped: $e');
    }
  }

  /// Obtiene un outfit por ID
  Future<SavedOutfit?> getOutfitById(String outfitId) async {
    try {
      final doc = await _firestore
          .collection('saved_outfits')
          .doc(outfitId)
          .get();

      if (doc.exists) {
        return SavedOutfit.fromJson({...doc.data()!, 'id': doc.id});
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error loading outfit: $e');
      return null;
    }
  }

  /// Actualiza solo la URL de try-on (flujo progresivo P1).
  Future<void> updateTryOnImageUrl(String outfitId, String tryOnImageUrl) async {
    try {
      await _firestore.collection('saved_outfits').doc(outfitId).update({
        'tryOnImageUrl': tryOnImageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Try-on URL updated for outfit $outfitId');
    } catch (e) {
      debugPrint('❌ Error updating try-on URL: $e');
      throw Exception('Failed to update try-on image: $e');
    }
  }

  /// Actualiza un outfit (favoritos, tags, notas, etc.)
  Future<void> updateOutfit(SavedOutfit outfit) async {
    try {
      debugPrint('📝 Updating outfit: ${outfit.id}');

      await _firestore
          .collection('saved_outfits')
          .doc(outfit.id)
          .update(outfit.toJson());

      debugPrint('✅ Outfit updated successfully');
    } catch (e) {
      debugPrint('❌ Error updating outfit: $e');
      throw Exception('Failed to update outfit: $e');
    }
  }

  /// Marca/unmarca como favorito
  Future<void> toggleFavorite(String outfitId, bool isFavorite) async {
    try {
      await _firestore.collection('saved_outfits').doc(outfitId).update({
        'isFavorite': isFavorite,
      });
      debugPrint('✅ Favorite toggled: $isFavorite');
    } catch (e) {
      debugPrint('❌ Error toggling favorite: $e');
      throw Exception('Failed to toggle favorite: $e');
    }
  }

  /// Incrementa el contador de vistas
  Future<void> incrementViewCount(String outfitId) async {
    try {
      final doc = await _firestore
          .collection('saved_outfits')
          .doc(outfitId)
          .get();

      if (doc.exists) {
        final currentCount = doc.data()?['viewCount'] ?? 0;
        await _firestore.collection('saved_outfits').doc(outfitId).update({
          'viewCount': currentCount + 1,
          'lastViewedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error incrementing view count: $e');
    }
  }

  /// Agrega tags personalizados
  Future<void> addCustomTags(String outfitId, List<String> tags) async {
    try {
      final doc = await _firestore
          .collection('saved_outfits')
          .doc(outfitId)
          .get();

      if (doc.exists) {
        final currentTags = List<String>.from(doc.data()?['customTags'] ?? []);
        final newTags = {...currentTags, ...tags}.toList();

        await _firestore.collection('saved_outfits').doc(outfitId).update({
          'customTags': newTags,
        });
      }
    } catch (e) {
      debugPrint('❌ Error adding custom tags: $e');
      throw Exception('Failed to add custom tags: $e');
    }
  }

  /// Actualiza las notas del usuario
  Future<void> updateNotes(String outfitId, String? notes) async {
    try {
      await _firestore.collection('saved_outfits').doc(outfitId).update({
        'notes': notes,
      });
      debugPrint('✅ Notes updated');
    } catch (e) {
      debugPrint('❌ Error updating notes: $e');
      throw Exception('Failed to update notes: $e');
    }
  }

  /// Elimina un outfit
  Future<void> deleteOutfit(String outfitId) async {
    try {
      debugPrint('🗑️ Deleting outfit: $outfitId');

      await _firestore.collection('saved_outfits').doc(outfitId).delete();

      debugPrint('✅ Outfit deleted successfully');
    } catch (e) {
      debugPrint('❌ Error deleting outfit: $e');
      throw Exception('Failed to delete outfit: $e');
    }
  }
}
