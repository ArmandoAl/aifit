enum ChatRole { user, ai }

class GeneratedOutfit {
  final String id;
  final String imageUrl;
  final int matchPercentage;
  final List<String> itemIds;

  GeneratedOutfit({
    required this.id,
    required this.imageUrl,
    required this.matchPercentage,
    required this.itemIds,
  });

  factory GeneratedOutfit.fromJson(Map<String, dynamic> json) {
    return GeneratedOutfit(
      id: json['outfitId'],
      imageUrl: json['imageUrl'],
      matchPercentage: json['matchPercentage'],
      itemIds: List<String>.from(json['items']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imageUrl': imageUrl,
      'matchPercentage': matchPercentage,
      'itemIds': itemIds,
    };
  }

  @override
  String toString() {
    return 'GeneratedOutfit(id: $id, imageUrl: $imageUrl, matchPercentage: $matchPercentage, itemIds: $itemIds)';
  }
}

class ChatMessage {
  final String id;
  final ChatRole role;
  final String text;
  final GeneratedOutfit? outfit; // Opcional: solo si la IA generó uno
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    this.outfit,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      role: json['role'],
      text: json['text'],
      outfit: json['outfit'] != null
          ? GeneratedOutfit.fromJson(json['outfit'])
          : null,
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'text': text,
      'outfit': outfit?.toJson(),
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'ChatMessage(id: $id, role: $role, text: $text, outfit: $outfit, timestamp: $timestamp)';
  }
}
