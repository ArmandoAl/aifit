/// Modelos de datos para el sistema de generación de outfits
library;

import 'package:aifit/paths.dart';
import '../../profile/domain/user_identity_profile.dart';

class OutfitIntent {
  final String?
  reasoning; // Explicación del razonamiento de la IA (Chain of Thought)
  final String? occasion; // 'casual', 'formal', 'sport', 'party', 'work', etc.
  final List<String> preferredColors;
  final List<String> styleTags; // ['casual', 'formal', 'minimalist', etc.]
  final String? season; // 'spring', 'summer', 'fall', 'winter'
  final String? weather; // 'sunny', 'rainy', 'cold', 'warm'
  final Map<String, dynamic>? constraints; // Restricciones adicionales
  final String? userPrompt; // Prompt original del usuario

  OutfitIntent({
    this.reasoning,
    this.occasion,
    this.preferredColors = const [],
    this.styleTags = const [],
    this.season,
    this.weather,
    this.constraints,
    this.userPrompt,
  });

  factory OutfitIntent.fromJson(Map<String, dynamic> json) {
    return OutfitIntent(
      reasoning: json['reasoning'],
      occasion: json['occasion'],
      preferredColors: json['preferredColors'] != null
          ? List<String>.from(json['preferredColors'])
          : [],
      styleTags: json['styleTags'] != null
          ? List<String>.from(json['styleTags'])
          : [],
      season: json['season'],
      weather: json['weather'],
      constraints: json['constraints'] as Map<String, dynamic>?,
      userPrompt: json['userPrompt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (reasoning != null) 'reasoning': reasoning,
      if (occasion != null) 'occasion': occasion,
      'preferredColors': preferredColors,
      'styleTags': styleTags,
      if (season != null) 'season': season,
      if (weather != null) 'weather': weather,
      if (constraints != null) 'constraints': constraints,
      if (userPrompt != null) 'userPrompt': userPrompt,
    };
  }
}

class FilteredWardrobe {
  final List<WardrobeItem> tops;
  final List<WardrobeItem> bottoms;
  final List<WardrobeItem> shoes;
  final List<WardrobeItem> outerwear;

  FilteredWardrobe({
    required this.tops,
    required this.bottoms,
    required this.shoes,
    required this.outerwear,
  });

  int get totalItems =>
      tops.length + bottoms.length + shoes.length + outerwear.length;

  bool get isEmpty =>
      tops.isEmpty && bottoms.isEmpty && shoes.isEmpty && outerwear.isEmpty;
}

class GeneratedOutfit {
  final String id;
  final String? topId;
  final String? bottomId;
  final String? shoesId;
  final String? outerwearId; // Optional
  final int matchPercentage; // 0-100
  final String explanation;
  final double compatibilityScore; // 0.0-1.0
  final Map<String, dynamic>? metadata; // Additional data

  GeneratedOutfit({
    required this.id,
    this.topId,
    this.bottomId,
    this.shoesId,
    this.outerwearId,
    required this.matchPercentage,
    required this.explanation,
    required this.compatibilityScore,
    this.metadata,
  });

  factory GeneratedOutfit.fromJson(Map<String, dynamic> json) {
    return GeneratedOutfit(
      id: json['id'] ?? json['outfitId'] ?? '',
      topId: json['topId'],
      bottomId: json['bottomId'],
      shoesId: json['shoesId'],
      outerwearId: json['outerwearId'],
      matchPercentage: json['matchPercentage'] ?? 0,
      explanation: json['explanation'] ?? json['text'] ?? '',
      compatibilityScore: (json['compatibilityScore'] ?? 0.0).toDouble(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (topId != null) 'topId': topId,
      if (bottomId != null) 'bottomId': bottomId,
      if (shoesId != null) 'shoesId': shoesId,
      if (outerwearId != null) 'outerwearId': outerwearId,
      'matchPercentage': matchPercentage,
      'explanation': explanation,
      'compatibilityScore': compatibilityScore,
      if (metadata != null) 'metadata': metadata,
    };
  }

  List<String> get itemIds {
    final ids = <String>[];
    if (topId != null) ids.add(topId!);
    if (bottomId != null) ids.add(bottomId!);
    if (shoesId != null) ids.add(shoesId!);
    if (outerwearId != null) ids.add(outerwearId!);
    return ids;
  }
}

class VirtualTryOnRequest {
  final GeneratedOutfit outfit;
  final List<String> itemImageUrls; // URLs de las imágenes de las prendas
  final String? userBodyPhotoUrl; // URL de foto de cuerpo del usuario
  final String? userFacePhotoUrl; // URL de foto de cara del usuario
  final IdentityProfile? identityProfile;
  final Map<String, dynamic>? generationOptions; // Opciones para la generación

  VirtualTryOnRequest({
    required this.outfit,
    required this.itemImageUrls,
    this.userBodyPhotoUrl,
    this.userFacePhotoUrl,
    this.identityProfile,
    this.generationOptions,
  });

  bool get hasUserPhotos =>
      userBodyPhotoUrl != null || userFacePhotoUrl != null;
}

class VirtualTryOnResult {
  final String outfitId;
  final String generatedImageUrl; // URL de la imagen generada
  final DateTime generatedAt;
  final Map<String, dynamic>? metadata;

  VirtualTryOnResult({
    required this.outfitId,
    required this.generatedImageUrl,
    required this.generatedAt,
    this.metadata,
  });

  factory VirtualTryOnResult.fromJson(Map<String, dynamic> json) {
    return VirtualTryOnResult(
      outfitId: json['outfitId'],
      generatedImageUrl: json['generatedImageUrl'] ?? json['imageUrl'],
      generatedAt: json['generatedAt'] != null
          ? DateTime.parse(json['generatedAt'])
          : DateTime.now(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'outfitId': outfitId,
      'generatedImageUrl': generatedImageUrl,
      'generatedAt': generatedAt.toIso8601String(),
      if (metadata != null) 'metadata': metadata,
    };
  }
}
