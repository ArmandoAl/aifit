import 'package:cloud_firestore/cloud_firestore.dart';
import 'wardrobe_ai_metadata.dart';

class WardrobeItem {
  final String id;
  final String name;
  final String type; // 'top', 'bottom', 'shoes', 'outerwear'
  final String subType; // e.g., 'jeans', 't-shirt', 'sweater', 'pants'
  final String imageUrl;
  final List<String> colors; // Array of colors
  final String? brand; // Optional
  final List<String> styleTags; // e.g., ['casual', 'formal']
  final List<String> season; // e.g., ['spring', 'summer']
  final DateTime? createdAt;
  final WardrobeAiMetadata? aiMetadata;

  WardrobeItem({
    required this.id,
    required this.name,
    required this.type,
    required this.subType,
    required this.imageUrl,
    required this.colors,
    this.brand,
    this.styleTags = const [],
    this.season = const [],
    this.createdAt,
    this.aiMetadata,
  });

  // Legacy: category maps to type for backward compatibility
  String get category => type;

  factory WardrobeItem.fromJson(Map<String, dynamic> json) {
    final aiMetadata = WardrobeAiMetadata.fromJson(json);

    return WardrobeItem(
      id: json['id'] ?? json['documentId'] ?? '',
      name: json['name'] ?? json['subType'] ?? 'Unknown',
      type: json['type'] ?? json['category'] ?? 'unknown',
      subType: json['subType'] ?? json['name'] ?? 'unknown',
      imageUrl: json['imageUrl'] ?? '',
      colors: json['colors'] != null
          ? List<String>.from(json['colors'])
          : (json['color'] != null ? [json['color'].toString()] : []),
      brand: json['brand'],
      styleTags: json['styleTags'] != null
          ? List<String>.from(json['styleTags'])
          : [],
      season: json['season'] != null
          ? List<String>.from(json['season'])
          : [],
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] is DateTime
              ? json['createdAt'] as DateTime
              : (json['createdAt'] as Timestamp).toDate())
          : null,
      aiMetadata: aiMetadata.isEmpty ? null : aiMetadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'subType': subType,
      'imageUrl': imageUrl,
      'colors': colors,
      if (brand != null) 'brand': brand,
      'styleTags': styleTags,
      'season': season,
      if (createdAt != null) 'createdAt': createdAt,
      ...?aiMetadata?.toJson().isEmpty == false ? aiMetadata!.toJson() : null,
    };
  }

  // For Firestore (without id, as it's the document ID)
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'type': type,
      'subType': subType,
      'imageUrl': imageUrl,
      'colors': colors,
      if (brand != null) 'brand': brand,
      'styleTags': styleTags,
      'season': season,
      ...?aiMetadata?.toJson().isEmpty == false ? aiMetadata!.toJson() : null,
    };
  }

  WardrobeItem copyWith({
    String? id,
    String? name,
    String? type,
    String? subType,
    String? imageUrl,
    List<String>? colors,
    String? brand,
    List<String>? styleTags,
    List<String>? season,
    DateTime? createdAt,
    WardrobeAiMetadata? aiMetadata,
    bool clearAiMetadata = false,
  }) {
    return WardrobeItem(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      subType: subType ?? this.subType,
      imageUrl: imageUrl ?? this.imageUrl,
      colors: colors ?? this.colors,
      brand: brand ?? this.brand,
      styleTags: styleTags ?? this.styleTags,
      season: season ?? this.season,
      createdAt: createdAt ?? this.createdAt,
      aiMetadata: clearAiMetadata ? null : (aiMetadata ?? this.aiMetadata),
    );
  }

  @override
  String toString() {
    return 'WardrobeItem(id: $id, name: $name, type: $type, subType: $subType, imageUrl: $imageUrl, colors: $colors, brand: $brand)';
  }
}
