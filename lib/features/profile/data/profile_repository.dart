import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/storage_service.dart';

class ProfileRepository {
  final FirebaseFirestore _firestore = FirestoreService.instance;
  final StorageService _storageService = StorageService();

  /// Get user profile data from Firestore
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      throw Exception('Failed to get user profile: $e');
    }
  }

  /// Upload body photos and update Firestore
  Future<void> uploadBodyPhotos({
    required String userId,
    required List<File> photos,
  }) async {
    try {
      debugPrint('📸 Uploading ${photos.length} body photos...');

      // Try to upload photos to Storage
      List<String> urls = [];
      try {
        urls = await _storageService.uploadMultiplePhotos(
          userId: userId,
          files: photos,
          photoType: 'body',
        );
        debugPrint('✅ Photos uploaded to Storage');
      } catch (e) {
        debugPrint('⚠️ Storage upload failed (using mock URLs): $e');
        // Use mock URLs for offline development
        urls = photos.map((f) => 'mock://body_photo_${f.path.split('/').last}').toList();
      }

      // Try to update Firestore
      try {
        debugPrint('💾 Saving ${urls.length} body photo URLs to Firestore...');
        debugPrint('   URLs: $urls');
        
        await _firestore.collection('users').doc(userId).set({
          'bodyPhotos': FieldValue.arrayUnion(urls),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        debugPrint('✅ Firestore updated with body photos');
        
        // Verify the update
        final doc = await _firestore.collection('users').doc(userId).get();
        final savedPhotos = doc.data()?['bodyPhotos'] as List<dynamic>? ?? [];
        debugPrint('✅ Verified: ${savedPhotos.length} body photos in Firestore');
      } catch (e) {
        debugPrint('❌ Firestore update failed: $e');
        throw Exception('Failed to save body photos to Firestore: $e');
      }

      debugPrint('✅ Body photos process completed');
    } catch (e) {
      debugPrint('❌ Error uploading body photos: $e');
      throw Exception('Failed to upload body photos: $e');
    }
  }

  /// Upload face photos and update Firestore
  Future<void> uploadFacePhotos({
    required String userId,
    required List<File> photos,
  }) async {
    try {
      debugPrint('📸 Uploading ${photos.length} face photos...');

      // Try to upload photos to Storage
      List<String> urls = [];
      try {
        urls = await _storageService.uploadMultiplePhotos(
          userId: userId,
          files: photos,
          photoType: 'face',
        );
        debugPrint('✅ Photos uploaded to Storage');
      } catch (e) {
        debugPrint('⚠️ Storage upload failed (using mock URLs): $e');
        // Use mock URLs for offline development
        urls = photos.map((f) => 'mock://face_photo_${f.path.split('/').last}').toList();
      }

      // Try to update Firestore
      try {
        debugPrint('💾 Saving ${urls.length} face photo URLs to Firestore...');
        debugPrint('   URLs: $urls');
        
        await _firestore.collection('users').doc(userId).set({
          'facePhotos': FieldValue.arrayUnion(urls),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        debugPrint('✅ Firestore updated with face photos');
        
        // Verify the update
        final doc = await _firestore.collection('users').doc(userId).get();
        final savedPhotos = doc.data()?['facePhotos'] as List<dynamic>? ?? [];
        debugPrint('✅ Verified: ${savedPhotos.length} face photos in Firestore');
      } catch (e) {
        debugPrint('❌ Firestore update failed: $e');
        throw Exception('Failed to save face photos to Firestore: $e');
      }

      debugPrint('✅ Face photos process completed');
    } catch (e) {
      debugPrint('❌ Error uploading face photos: $e');
      throw Exception('Failed to upload face photos: $e');
    }
  }

  /// Remove a photo URL from Firestore and delete from Storage
  Future<void> removePhoto({
    required String userId,
    required String photoUrl,
    required String photoType, // 'body' or 'face'
  }) async {
    try {
      // Delete from Storage
      await _storageService.deletePhoto(photoUrl);

      // Remove from Firestore
      final field = photoType == 'body' ? 'bodyPhotos' : 'facePhotos';
      await _firestore.collection('users').doc(userId).set({
        field: FieldValue.arrayRemove([photoUrl]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('Photo removed successfully');
    } catch (e) {
      debugPrint('Error removing photo: $e');
      throw Exception('Failed to remove photo: $e');
    }
  }

  /// Mark onboarding as completed
  Future<void> completeOnboarding(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'onboardingCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('✅ Onboarding marked as completed');
    } catch (e) {
      debugPrint('⚠️ Onboarding completion skipped (offline mode): $e');
      // Continue without Firestore - it's optional for now
    }
  }

  /// Update user preferences
  Future<void> updatePreferences({
    required String userId,
    required Map<String, dynamic> preferences,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'preferences': preferences,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('Preferences updated');
    } catch (e) {
      debugPrint('Error updating preferences: $e');
      throw Exception('Failed to update preferences: $e');
    }
  }

  /// Delete user account and all associated data
  Future<void> deleteUserAccount(String userId) async {
    try {
      debugPrint('🗑️ Deleting user account: $userId');

      // 1. Get user profile to find all photo URLs
      final profileData = await getUserProfile(userId);
      
      // 2. Delete all photos from Storage
      if (profileData != null) {
        final bodyPhotos = profileData['bodyPhotos'] as List<dynamic>? ?? [];
        final facePhotos = profileData['facePhotos'] as List<dynamic>? ?? [];
        
        final allPhotoUrls = [
          ...bodyPhotos.map((url) => url.toString()),
          ...facePhotos.map((url) => url.toString()),
        ].where((url) => url.isNotEmpty && !url.startsWith('mock://')).toList();

        for (final url in allPhotoUrls) {
          try {
            await _storageService.deletePhoto(url);
          } catch (e) {
            debugPrint('⚠️ Error deleting photo $url: $e');
            // Continue with other deletions
          }
        }
      }

      // 3. Delete user document from Firestore
      await _firestore.collection('users').doc(userId).delete();
      
      // 4. Delete all wardrobe items (optional - you might want to keep them)
      // For now, we'll delete them too
      final wardrobeSnapshot = await _firestore
          .collection('wardrobe_items')
          .where('userId', isEqualTo: userId)
          .get();
      
      final batch = _firestore.batch();
      for (final doc in wardrobeSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      debugPrint('✅ User account deleted successfully');
    } catch (e) {
      debugPrint('❌ Error deleting user account: $e');
      throw Exception('Failed to delete user account: $e');
    }
  }
}
