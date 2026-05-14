import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Upload a user photo to Firebase Storage
  /// 
  /// [userId] - The user's unique ID
  /// [file] - The image file to upload
  /// [photoType] - Either 'body' or 'face'
  /// 
  /// Returns the download URL of the uploaded image
  Future<String> uploadUserPhoto({
    required String userId,
    required File file,
    required String photoType, // 'body' or 'face'
  }) async {
    try {
      // Verify user is authenticated
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('❌ No authenticated user - cannot upload to Storage');
        throw Exception('User not authenticated. Please log in again.');
      }
      
      // Validate that userId is not a mock ID
      if (userId.startsWith('mock_') || userId.contains('mock_user')) {
        debugPrint('❌ ERROR: Attempted to use mock user ID: $userId');
        debugPrint('   This should never happen with real authentication.');
        debugPrint('   Using real UID instead: ${currentUser.uid}');
        throw Exception('Invalid user ID format. Please log in with Google.');
      }
      
      if (currentUser.uid != userId) {
        debugPrint('❌ User ID mismatch: current=${currentUser.uid}, provided=$userId');
        throw Exception('User ID mismatch');
      }

      debugPrint('✅ User authenticated: ${currentUser.uid}');
      debugPrint('📁 Storage path: users/${currentUser.uid}/photos/...');

      // Verify file exists and is readable
      if (!await file.exists()) {
        throw Exception('File does not exist');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${photoType}_$timestamp.jpg';
      final path = 'users/$userId/photos/$fileName';

      debugPrint('📤 Uploading photo to: $path');

      final ref = _storage.ref().child(path);
      
      // Upload file with retry logic for transient errors
      UploadTask uploadTask;
      try {
        uploadTask = ref.putFile(
          file,
          SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {
              'userId': userId,
              'photoType': photoType,
              'uploadedAt': timestamp.toString(),
            },
          ),
        );
      } catch (e) {
        debugPrint('Error creating upload task: $e');
        // Retry once after a short delay
        await Future.delayed(const Duration(milliseconds: 500));
        uploadTask = ref.putFile(
          file,
          SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {
              'userId': userId,
              'photoType': photoType,
              'uploadedAt': timestamp.toString(),
            },
          ),
        );
      }

      // Wait for upload to complete
      final snapshot = await uploadTask;
      
      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('Photo uploaded successfully: $downloadUrl');

      return downloadUrl;
    } catch (e) {
      debugPrint('❌ Error uploading photo: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      debugPrint('❌ Current user: ${_auth.currentUser?.uid ?? "null"}');
      
      // Provide more specific error messages
      final errorString = e.toString();
      if (errorString.contains('-1017') || errorString.contains('unavailable')) {
        debugPrint('❌ Storage error -1017: This usually means authentication/permission issue');
        debugPrint('   - Check if user is logged in: ${_auth.currentUser != null}');
        debugPrint('   - Check Storage rules in Firebase Console');
        throw Exception('Storage service temporarily unavailable. Please log out and log in again.');
      }
      if (errorString.contains('permission') || errorString.contains('unauthorized')) {
        throw Exception('Permission denied. Please check your Storage rules.');
      }
      throw Exception('Failed to upload photo: $e');
    }
  }

  /// Upload multiple user photos
  /// 
  /// Returns a list of download URLs
  Future<List<String>> uploadMultiplePhotos({
    required String userId,
    required List<File> files,
    required String photoType,
  }) async {
    final List<String> urls = [];

    for (final file in files) {
      try {
        final url = await uploadUserPhoto(
          userId: userId,
          file: file,
          photoType: photoType,
        );
        urls.add(url);
      } catch (e) {
        debugPrint('Error uploading file: $e');
        // Continue with other files even if one fails
      }
    }

    return urls;
  }

  /// Upload a wardrobe item photo
  /// 
  /// Returns the download URL
  Future<String> uploadWardrobeItem({
    required String userId,
    required File file,
  }) async {
    try {
      // Verify user is authenticated
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('❌ No authenticated user - cannot upload to Storage');
        throw Exception('User not authenticated. Please log in again.');
      }
      
      // Validate that userId is not a mock ID
      if (userId.startsWith('mock_') || userId.contains('mock_user')) {
        debugPrint('❌ ERROR: Attempted to use mock user ID: $userId');
        debugPrint('   This should never happen with real authentication.');
        debugPrint('   Using real UID instead: ${currentUser.uid}');
        throw Exception('Invalid user ID format. Please log in with Google.');
      }
      
      if (currentUser.uid != userId) {
        debugPrint('❌ User ID mismatch: current=${currentUser.uid}, provided=$userId');
        throw Exception('User ID mismatch');
      }

      debugPrint('✅ User authenticated: ${currentUser.uid}');
      debugPrint('📁 Storage path: users/${currentUser.uid}/wardrobe/...');

      // Verify file exists
      if (!await file.exists()) {
        throw Exception('File does not exist');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'item_$timestamp.jpg';
      final path = 'users/$userId/wardrobe/$fileName';

      debugPrint('📤 Uploading wardrobe item to: $path');

      final ref = _storage.ref().child(path);
      
      final uploadTask = await ref.putFile(
        file,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'userId': userId,
            'itemType': 'wardrobe',
            'uploadedAt': timestamp.toString(),
          },
        ),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();
      debugPrint('Wardrobe item uploaded successfully: $downloadUrl');

      return downloadUrl;
    } catch (e) {
      debugPrint('❌ Error uploading wardrobe item: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      debugPrint('❌ Current user: ${_auth.currentUser?.uid ?? "null"}');
      
      final errorString = e.toString();
      if (errorString.contains('-1017') || errorString.contains('unavailable')) {
        debugPrint('❌ Storage error -1017: Authentication/permission issue');
        throw Exception('Storage service temporarily unavailable. Please log out and log in again.');
      }
      throw Exception('Failed to upload wardrobe item: $e');
    }
  }

  /// Delete a photo from Storage
  Future<void> deletePhoto(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
      debugPrint('Photo deleted successfully');
    } catch (e) {
      debugPrint('Error deleting photo: $e');
      throw Exception('Failed to delete photo: $e');
    }
  }

  /// Delete multiple photos
  Future<void> deleteMultiplePhotos(List<String> downloadUrls) async {
    for (final url in downloadUrls) {
      try {
        await deletePhoto(url);
      } catch (e) {
        debugPrint('Error deleting photo $url: $e');
        // Continue with other deletions
      }
    }
  }
}
