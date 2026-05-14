import 'package:cloud_firestore/cloud_firestore.dart';

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
  });

  // Legacy: category maps to type for backward compatibility
  String get category => type;

  factory WardrobeItem.fromJson(Map<String, dynamic> json) {
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
    };
  }

  @override
  String toString() {
    return 'WardrobeItem(id: $id, name: $name, type: $type, subType: $subType, imageUrl: $imageUrl, colors: $colors, brand: $brand)';
  }
}
