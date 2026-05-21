/// Shared Gemini wardrobe analysis prompt (JSON-only, schema v2).
class WardrobeAnalysisPrompt {
  WardrobeAnalysisPrompt._();

  static const String fullAnalysis = '''
You are a professional fashion stylist, fabric/material analyst, silhouette expert, color theory expert, and luxury/streetwear aesthetic classifier.

Analyze this clothing item image carefully. Return ONLY valid JSON (no markdown, no commentary).

REQUIRED fields (always include):
- type: one of "top", "bottom", "shoes", "outerwear"
- subType: specific garment (e.g. "linen shirt", "slim jeans", "sneakers")
- colors: array of dominant color names
- styleTags: array of style descriptors (e.g. "casual", "minimalist")
- season: array of suitable seasons (spring, summer, fall, winter)

OPTIONAL field:
- brand: string if a visible brand can be inferred, else omit

HIDDEN semantic metadata (include all; use snake_case keys; scores 0.0-1.0):
- ai_schema_version: 2
- visual_weight: "light" | "medium" | "heavy"
- texture: { primary, secondary[], surface_feel, structure }
- silhouette: { fit, length, shape }
- fashion_aesthetic: { primary, secondary[], confidence }
- color_profile: { temperature, saturation, contrast }
- style_scores: { formality, streetwear, luxury, minimalist, sporty, vintage } (0.0-1.0 each)
- gender_expression: { primary, confidence }
- layering_compatibility: { works_with[], avoid_with[] }
- occasion_vectors: object of occasion_slug -> score (e.g. beach_dinner, office, formal_event)
- climate_compatibility: { hot_weather, humid_weather, cold_weather } (0.0-1.0)
- visual_attributes: { cleanliness, sharpness, casualness, elegance } (0.0-1.0)

Rules:
- Be concise and deterministic.
- Use lowercase snake_case for enum-like slugs (e.g. old_money, quiet_luxury).
- Infer fabric, silhouette, aesthetic, and layering from visible cues only.
- Output must be a single JSON object.
''';

  static const String colorsAndStyleOnly = '''
Analyze this clothing item for colors and style only.
Return ONLY valid JSON with:
- colors: array of dominant colors
- styleTags: array of styles (e.g. "casual", "formal")
''';
}
