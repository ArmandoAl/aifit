/// Textual biometric profiles for virtual try-on identity preservation.
library;

class AiFaceProfile {
  final String? skinTone;
  final String? faceShape;
  final String? hairColor;
  final String? hairStyle;
  final String? eyeShape;

  const AiFaceProfile({
    this.skinTone,
    this.faceShape,
    this.hairColor,
    this.hairStyle,
    this.eyeShape,
  });

  factory AiFaceProfile.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return const AiFaceProfile();
    return AiFaceProfile(
      skinTone: json['skin_tone']?.toString(),
      faceShape: json['face_shape']?.toString(),
      hairColor: json['hair_color']?.toString(),
      hairStyle: json['hair_style']?.toString(),
      eyeShape: json['eye_shape']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (skinTone != null) 'skin_tone': skinTone,
      if (faceShape != null) 'face_shape': faceShape,
      if (hairColor != null) 'hair_color': hairColor,
      if (hairStyle != null) 'hair_style': hairStyle,
      if (eyeShape != null) 'eye_shape': eyeShape,
    };
  }

  bool get isEmpty => toJson().isEmpty;
}

class AiBodyProfile {
  final String? bodyType;
  final String? heightEstimate;
  final String? shoulderWidth;
  final String? build;

  const AiBodyProfile({
    this.bodyType,
    this.heightEstimate,
    this.shoulderWidth,
    this.build,
  });

  factory AiBodyProfile.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return const AiBodyProfile();
    return AiBodyProfile(
      bodyType: json['body_type']?.toString(),
      heightEstimate: json['height_estimate']?.toString(),
      shoulderWidth: json['shoulder_width']?.toString(),
      build: json['build']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (bodyType != null) 'body_type': bodyType,
      if (heightEstimate != null) 'height_estimate': heightEstimate,
      if (shoulderWidth != null) 'shoulder_width': shoulderWidth,
      if (build != null) 'build': build,
    };
  }

  bool get isEmpty => toJson().isEmpty;
}
