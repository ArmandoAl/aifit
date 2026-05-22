import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../platform/app_image.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> _uploadBytes({
    required String path,
    required Uint8List bytes,
    required String contentType,
    required Map<String, String> customMetadata,
  }) async {
    final ref = _storage.ref().child(path);
    final snapshot = await ref.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        customMetadata: customMetadata,
      ),
    );
    return snapshot.ref.getDownloadURL();
  }

  void _assertAuthenticatedUpload(String userId) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated. Please log in again.');
    }
    if (userId.startsWith('mock_') || userId.contains('mock_user')) {
      throw Exception('Invalid user ID format. Please log in with Google.');
    }
    if (currentUser.uid != userId) {
      throw Exception('User ID mismatch');
    }
  }

  Future<String> uploadUserPhoto({
    required String userId,
    required AppImage image,
    required String photoType,
  }) async {
    try {
      _assertAuthenticatedUpload(userId);

      if (image.bytes.isEmpty) {
        throw Exception('Image is empty');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${photoType}_$timestamp.jpg';
      final path = 'users/$userId/photos/$fileName';

      debugPrint('📤 Uploading photo to: $path');

      return _uploadBytes(
        path: path,
        bytes: image.bytes,
        contentType: 'image/jpeg',
        customMetadata: {
          'userId': userId,
          'photoType': photoType,
          'uploadedAt': timestamp.toString(),
        },
      );
    } catch (e) {
      debugPrint('❌ Error uploading photo: $e');
      final errorString = e.toString();
      if (errorString.contains('-1017') ||
          errorString.contains('unavailable')) {
        throw Exception(
          'Storage service temporarily unavailable. Please log out and log in again.',
        );
      }
      if (errorString.contains('permission') ||
          errorString.contains('unauthorized')) {
        throw Exception('Permission denied. Please check your Storage rules.');
      }
      throw Exception('Failed to upload photo: $e');
    }
  }

  Future<List<String>> uploadMultiplePhotos({
    required String userId,
    required List<AppImage> images,
    required String photoType,
  }) async {
    final urls = <String>[];

    for (final image in images) {
      try {
        final url = await uploadUserPhoto(
          userId: userId,
          image: image,
          photoType: photoType,
        );
        urls.add(url);
      } catch (e) {
        debugPrint('Error uploading image: $e');
      }
    }

    return urls;
  }

  Future<String> uploadWardrobeItem({
    required String userId,
    required AppImage image,
  }) async {
    try {
      _assertAuthenticatedUpload(userId);

      if (image.bytes.isEmpty) {
        throw Exception('Image is empty');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'item_$timestamp.jpg';
      final path = 'users/$userId/wardrobe/$fileName';

      debugPrint('📤 Uploading wardrobe item to: $path');

      return _uploadBytes(
        path: path,
        bytes: image.bytes,
        contentType: 'image/jpeg',
        customMetadata: {
          'userId': userId,
          'itemType': 'wardrobe',
          'uploadedAt': timestamp.toString(),
        },
      );
    } catch (e) {
      debugPrint('❌ Error uploading wardrobe item: $e');
      final errorString = e.toString();
      if (errorString.contains('-1017') ||
          errorString.contains('unavailable')) {
        throw Exception(
          'Storage service temporarily unavailable. Please log out and log in again.',
        );
      }
      throw Exception('Failed to upload wardrobe item: $e');
    }
  }

  Future<String> uploadUserBaseImage({
    required String userId,
    required Uint8List bytes,
  }) async {
    _assertAuthenticatedUpload(userId);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'users/$userId/base_image_$timestamp.jpg';
    return _uploadBytes(
      path: path,
      bytes: bytes,
      contentType: 'image/jpeg',
      customMetadata: {
        'userId': userId,
        'type': 'base_image',
        'uploadedAt': timestamp.toString(),
      },
    );
  }

  Future<String> uploadOutfitTryOn({
    required String userId,
    required Uint8List bytes,
  }) async {
    _assertAuthenticatedUpload(userId);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'users/$userId/outfits/tryon_$timestamp.jpg';
    return _uploadBytes(
      path: path,
      bytes: bytes,
      contentType: 'image/jpeg',
      customMetadata: {
        'userId': userId,
        'type': 'tryon',
        'uploadedAt': timestamp.toString(),
      },
    );
  }

  Future<void> deletePhoto(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
    } catch (e) {
      throw Exception('Failed to delete photo: $e');
    }
  }

  Future<void> deleteMultiplePhotos(List<String> downloadUrls) async {
    for (final url in downloadUrls) {
      try {
        await deletePhoto(url);
      } catch (e) {
        debugPrint('Error deleting photo $url: $e');
      }
    }
  }
}
