import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/platform/app_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../core/interfaces/ai_service.dart';
import '../../../core/services/firebase_ai_service_impl.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/storage_service.dart';
import '../domain/wardrobe_analysis_prompt.dart';
import '../domain/wardrobe_ai_metadata.dart';
import '../domain/wardrobe_item_model.dart';
import 'wardrobe_repository.dart';

class WardrobeRepositoryImpl implements WardrobeRepository {
  final AIService _aiService;
  final FirebaseFirestore _firestore = FirestoreService.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final StorageService _storageService = StorageService();

  WardrobeRepositoryImpl({AIService? aiService})
    : _aiService = aiService ?? FirebaseAIServiceImpl();

  @override
  Future<List<WardrobeItem>> getWardrobeItems() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      debugPrint('⚠️ No user logged in, returning empty wardrobe');
      return [];
    }

    try {
      debugPrint('📦 Loading wardrobe items for user: $uid');

      final snapshot = await _firestore
          .collection('wardrobe_items')
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .get();

      final items = snapshot.docs.map((doc) {
        final data = doc.data();
        return WardrobeItem.fromJson({
          ...data,
          'id': doc.id, // Use Firestore document ID
          'documentId': doc.id, // Also include for compatibility
        });
      }).toList();

      debugPrint('✅ Loaded ${items.length} wardrobe items');
      return items;
    } catch (e) {
      debugPrint('❌ Error loading wardrobe items: $e');
      // Return empty list instead of throwing to prevent UI crashes
      return [];
    }
  }

  Future<void> addWardrobeItem(AppImage image) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in");

    // 1. Subir imagen a Storage
    final imageUrl = await _storageService.uploadWardrobeItem(
      userId: uid,
      image: image,
    );

    final aiData = await _aiService.analyzeImageToJson(
      image: image,
      promptInstruction: WardrobeAnalysisPrompt.fullAnalysis,
    );

    await _firestore.collection('wardrobe_items').add({
      'userId': uid,
      'imageUrl': imageUrl,
      ...wardrobeFieldsFromAiJson(aiData),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Add wardrobe item with user-provided data (from form)
  Future<void> addWardrobeItemWithData({
    required AppImage image,
    required String type,
    required String subType,
    String? brand,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in");

    debugPrint('📦 Adding wardrobe item:');
    debugPrint('   - User ID: $uid');
    debugPrint('   - Type: $type');
    debugPrint('   - SubType: $subType');
    debugPrint('   - Brand: ${brand ?? "none"}');

    // 1. Upload image to Storage
    debugPrint('📤 Uploading image to Storage...');
    final imageUrl = await _storageService.uploadWardrobeItem(
      userId: uid,
      image: image,
    );
    debugPrint('✅ Image uploaded: $imageUrl');

    List<String> colors = [];
    List<String> styleTags = [];
    try {
      final aiData = await _aiService.analyzeImageToJson(
        image: image,
        promptInstruction: WardrobeAnalysisPrompt.colorsAndStyleOnly,
      );

      colors =
          (aiData['colors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      styleTags =
          (aiData['styleTags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
    } catch (e) {
      // AI analysis failed - continue with user data only
      debugPrint('⚠️ AI analysis failed (non-critical): $e');
    }

    // 3. Save to Firestore with user-provided data
    debugPrint('💾 Saving to Firestore...');
    final docRef = await _firestore.collection('wardrobe_items').add({
      'userId': uid,
      'imageUrl': imageUrl,
      'name': subType,
      'type': type,
      'subType': subType,
      'colors': colors,
      if (brand != null && brand.isNotEmpty) 'brand': brand,
      'styleTags': styleTags,
      'season': [], // Can be added later
      'createdAt': FieldValue.serverTimestamp(),
    });
    debugPrint('✅ Wardrobe item saved to Firestore: ${docRef.id}');
  }

  @override
  Future<void> updateWardrobeItem(WardrobeItem item) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in");

    debugPrint('📝 Updating wardrobe item: ${item.id}');

    try {
      await _firestore.collection('wardrobe_items').doc(item.id).update({
        ...item.toFirestore(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Wardrobe item updated successfully');
    } catch (e) {
      debugPrint('❌ Error updating wardrobe item: $e');
      throw Exception('Failed to update wardrobe item: $e');
    }
  }
}
