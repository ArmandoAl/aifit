import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_ai/firebase_ai.dart';
import '../../../core/services/firestore_service.dart';

class StylistRepositoryImpl {
  final FirebaseFirestore _firestore = FirestoreService.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Map<String, dynamic>> generateOutfitResponse(String userPrompt) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in");

    // 1. RAG Lite: Obtener el armario del usuario como JSON string
    final wardrobeSnapshot = await _firestore
        .collection('wardrobe_items')
        .where('userId', isEqualTo: uid)
        .get();

    // Convertimos el armario a un texto que Gemini entienda
    final wardrobeContext = wardrobeSnapshot.docs
        .map((doc) {
          final data = doc.data();
          return "- Item ID: ${doc.id}, Type: ${data['type']}, SubType: ${data['subType']}, Color: ${data['colors']}, Style: ${data['styleTags']}";
        })
        .join("\n");

    // 2. Construir el Prompt de Sistema
    final systemPrompt =
        """
    You are an expert AI Stylist. 
    The user asks: "$userPrompt".
    
    Here is the user's AVAILABLE WARDROBE (Use ONLY these items):
    $wardrobeContext
    
    Task:
    1. Select the best combination of items (Top + Bottom + Shoes).
    2. Explain why it looks good.
    3. Return a JSON structure exactly like this (no markdown):
    {
      "text": "Your explanation here...",
      "matchPercentage": 95,
      "items": ["itemId1", "itemId2", "itemId3"]
    }
    """;

    // 3. Llamar a Gemini mediante Firebase AI
    final model = FirebaseAI.vertexAI().generativeModel(
      model: 'gemini-2.5-flash', // Modelo rápido para chat
    );

    final content = [Content.text(systemPrompt)];
    final response = await model.generateContent(content);

    // ignore: unused_local_variable
    final responseText = response.text ?? "{}";

    // TODO: Implementar jsonDecode(responseText) cuando la IA esté devolviendo JSON válido
    // TODO: Guardar resultado en Firestore collection 'generated_outfits'

    // Retorno mock para la UI (reemplazar con datos reales de la IA)
    return {
      "text":
          "I've created a look using your Blue Jeans and White Tee. It's perfect for a casual day.",
      "outfitId": "temp_id",
      "matchPercentage": 85,
      "items": [], // IDs reales aquí
      "imageUrl":
          "https://via.placeholder.com/400", // Placeholder hasta tener VTON real
    };
  }

  /// Generate outfit with a specific item
  Future<Map<String, dynamic>> generateOutfitWithItem({
    required String itemId,
    required String userPrompt,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in");

    // 1. Get the specific item
    final itemDoc = await _firestore.collection('wardrobe_items').doc(itemId).get();
    if (!itemDoc.exists) {
      throw Exception("Item not found");
    }
    
    final itemData = itemDoc.data()!;
    if (itemData['userId'] != uid) {
      throw Exception("Unauthorized: This item doesn't belong to you");
    }

    // 2. Get all wardrobe items for context
    final wardrobeSnapshot = await _firestore
        .collection('wardrobe_items')
        .where('userId', isEqualTo: uid)
        .get();

    // 3. Build context with the specific item highlighted
    final wardrobeContext = wardrobeSnapshot.docs
        .map((doc) {
          final data = doc.data();
          final isMainItem = doc.id == itemId;
          return "${isMainItem ? '⭐ MAIN ITEM: ' : ''}Item ID: ${doc.id}, Type: ${data['type']}, SubType: ${data['subType']}, Color: ${data['colors']}, Style: ${data['styleTags']}";
        })
        .join("\n");

    // 4. Build prompt
    final systemPrompt = """
    You are an expert AI Stylist. 
    The user wants to create an outfit using a specific item and has given these instructions: "$userPrompt"
    
    MAIN ITEM TO USE (marked with ⭐):
    - Type: ${itemData['type']}
    - SubType: ${itemData['subType']}
    - Colors: ${itemData['colors']}
    - Style: ${itemData['styleTags']}
    - Brand: ${itemData['brand'] ?? 'Unknown'}
    
    Here is the user's COMPLETE WARDROBE (Use items from here to complete the outfit):
    $wardrobeContext
    
    Task:
    1. Create a complete outfit that INCLUDES the main item (marked with ⭐)
    2. Select complementary items from the wardrobe (Top + Bottom + Shoes, or appropriate combination)
    3. Explain why this combination works well
    4. Return a JSON structure exactly like this (no markdown):
    {
      "text": "Your explanation here...",
      "matchPercentage": 95,
      "items": ["$itemId", "itemId2", "itemId3"]
    }
    """;

    // 5. Call Gemini
    final model = FirebaseAI.vertexAI().generativeModel(
      model: 'gemini-2.5-flash',
    );

    final content = [Content.text(systemPrompt)];
    final response = await model.generateContent(content);

    // TODO: Parse JSON response when IA returns valid JSON
    // final responseText = response.text ?? "{}";
    // For now, return mock data with the item included
    return {
      "text":
          "I've created a perfect outfit using your ${itemData['subType']}. ${userPrompt.isNotEmpty ? 'Following your instructions: $userPrompt. ' : ''}This combination works great together!",
      "outfitId": "temp_id_${DateTime.now().millisecondsSinceEpoch}",
      "matchPercentage": 90,
      "items": [itemId], // Include the main item
      "imageUrl": "https://via.placeholder.com/400",
    };
  }
}
