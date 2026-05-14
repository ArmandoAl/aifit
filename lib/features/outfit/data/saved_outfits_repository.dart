import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../core/services/firestore_service.dart';
import '../domain/saved_outfit_model.dart';

/// Repository para gestionar outfits guardados en Firestore
class SavedOutfitsRepository {
  final FirebaseFirestore _firestore = FirestoreService.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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

  /// Obtiene todos los outfits del usuario
  Future<List<SavedOutfit>> getSavedOutfits({
    String? filterByOccasion,
    String? filterBySeason,
    List<String>? filterByColors,
    List<String>? filterByStyleTags,
    bool? onlyFavorites,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        debugPrint('⚠️ No user logged in');
        return [];
      }

      debugPrint('📦 Loading saved outfits for user: $userId');

      Query query = _firestore
          .collection('saved_outfits')
          .where('userId', isEqualTo: userId);

      // Aplicar filtros
      if (filterByOccasion != null) {
        query = query.where('occasion', isEqualTo: filterByOccasion);
      }

      if (filterBySeason != null) {
        query = query.where('season', isEqualTo: filterBySeason);
      }

      if (onlyFavorites == true) {
        query = query.where('isFavorite', isEqualTo: true);
      }

      // Ordenar por fecha de creación (más recientes primero)
      query = query.orderBy('createdAt', descending: true);

      final snapshot = await query.get();

      var outfits = snapshot.docs
          .map(
            (doc) => SavedOutfit.fromJson({
              ...doc.data() as Map<String, dynamic>,
              'id': doc.id,
            }),
          )
          .toList();

      // Filtros que no se pueden hacer en Firestore (arrays)
      if (filterByColors != null && filterByColors.isNotEmpty) {
        outfits = outfits.where((outfit) {
          return outfit.colors.any((color) => filterByColors.contains(color));
        }).toList();
      }

      if (filterByStyleTags != null && filterByStyleTags.isNotEmpty) {
        outfits = outfits.where((outfit) {
          return outfit.styleTags.any((tag) => filterByStyleTags.contains(tag));
        }).toList();
      }

      debugPrint('✅ Loaded ${outfits.length} saved outfits');
      return outfits;
    } catch (e) {
      debugPrint('❌ Error loading saved outfits: $e');
      return [];
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
      // No lanzar error, es opcional
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
