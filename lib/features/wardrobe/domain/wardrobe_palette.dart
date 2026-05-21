/// Canonical wardrobe UI palette + AI color/tag normalization.
class WardrobePalette {
  WardrobePalette._();

  static const List<String> standardColors = [
    'black',
    'white',
    'gray',
    'navy',
    'blue',
    'red',
    'green',
    'brown',
    'beige',
    'pink',
    'yellow',
    'orange',
    'purple',
  ];

  static const List<String> standardStyleTags = [
    'casual',
    'formal',
    'sporty',
    'elegant',
    'streetwear',
    'minimalist',
    'vintage',
    'bohemian',
  ];

  static const List<String> standardSeasons = [
    'spring',
    'summer',
    'fall',
    'winter',
  ];

  static final Map<String, String> _colorAliases = {
    'tan': 'beige',
    'khaki': 'beige',
    'camel': 'beige',
    'sand': 'beige',
    'cream': 'beige',
    'ivory': 'beige',
    'off_white': 'beige',
    'off-white': 'beige',
    'ecru': 'beige',
    'taupe': 'brown',
    'chocolate': 'brown',
    'coffee': 'brown',
    'maroon': 'red',
    'burgundy': 'red',
    'crimson': 'red',
    'charcoal': 'gray',
    'grey': 'gray',
    'silver': 'gray',
    'slate': 'gray',
    'denim': 'navy',
    'indigo': 'navy',
    'teal': 'green',
    'olive': 'green',
    'lime': 'green',
    'mint': 'green',
    'coral': 'orange',
    'peach': 'orange',
    'lavender': 'purple',
    'violet': 'purple',
    'magenta': 'pink',
    'rose': 'pink',
    'gold': 'yellow',
    'mustard': 'yellow',
    'sky_blue': 'blue',
    'light_blue': 'blue',
    'royal_blue': 'blue',
  };

  static final Map<String, String> _styleTagAliases = {
    'everyday': 'casual',
    'utilitarian': 'casual',
    'relaxed': 'casual',
    'smart_casual': 'casual',
    'business_casual': 'formal',
    'athletic': 'sporty',
    'active': 'sporty',
    'preppy': 'elegant',
    'classic': 'elegant',
    'edgy': 'streetwear',
    'urban': 'streetwear',
    'boho': 'bohemian',
    'retro': 'vintage',
  };

  static String normalizeColor(String raw) {
    final key = raw.trim().toLowerCase().replaceAll(' ', '_');
    if (standardColors.contains(key)) return key;
    return _colorAliases[key] ?? key;
  }

  static String normalizeStyleTag(String raw) {
    final key = raw.trim().toLowerCase().replaceAll(' ', '_');
    if (standardStyleTags.contains(key)) return key;
    return _styleTagAliases[key] ?? key;
  }

  static String normalizeSeason(String raw) {
    final key = raw.trim().toLowerCase();
    if (standardSeasons.contains(key)) return key;
    return key;
  }

  /// Maps AI colors to palette; keeps unknown only if no alias exists.
  static List<String> normalizeColors(List<String> raw) {
    final seen = <String>{};
    final result = <String>[];
    for (final c in raw) {
      final n = normalizeColor(c);
      if (n.isEmpty || seen.contains(n)) continue;
      seen.add(n);
      result.add(n);
    }
    return result;
  }

  static List<String> normalizeStyleTags(List<String> raw) {
    final seen = <String>{};
    final result = <String>[];
    for (final t in raw) {
      final n = normalizeStyleTag(t);
      if (n.isEmpty || seen.contains(n)) continue;
      seen.add(n);
      result.add(n);
    }
    return result;
  }

  static List<String> normalizeSeasons(List<String> raw) {
    final seen = <String>{};
    final result = <String>[];
    for (final s in raw) {
      final n = normalizeSeason(s);
      if (!standardSeasons.contains(n) || seen.contains(n)) continue;
      seen.add(n);
      result.add(n);
    }
    return result;
  }

  static List<String> customColors(List<String> colors) {
    return colors
        .where((c) => !standardColors.contains(c))
        .toList();
  }

  static List<String> customStyleTags(List<String> tags) {
    return tags
        .where((t) => !standardStyleTags.contains(t))
        .toList();
  }

  static String get colorsForPrompt =>
      standardColors.join(', ');

  static String get styleTagsForPrompt =>
      standardStyleTags.join(', ');
}
