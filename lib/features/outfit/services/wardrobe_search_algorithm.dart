import 'package:flutter/foundation.dart';
import '../../wardrobe/domain/wardrobe_item_model.dart';
import '../domain/outfit_models.dart';

/// Algoritmo de búsqueda y filtrado de prendas
/// 
/// Filtra el guardarropa del usuario basado en criterios de búsqueda
/// y calcula compatibilidad entre prendas para optimizar resultados.
class WardrobeSearchAlgorithm {
  /// Filtra prendas basado en intención del usuario
  /// 
  /// Retorna prendas separadas por tipo, ordenadas por relevancia
  static FilteredWardrobe filterWardrobe({
    required List<WardrobeItem> allItems,
    required OutfitIntent intent,
  }) {
    debugPrint('🔍 Filtering wardrobe with intent: ${intent.toJson()}');
    debugPrint('   Total items: ${allItems.length}');

    // Separar por tipo
    final tops = allItems.where((item) => item.type == 'top').toList();
    final bottoms = allItems.where((item) => item.type == 'bottom').toList();
    final shoes = allItems.where((item) => item.type == 'shoes').toList();
    final outerwear = allItems.where((item) => item.type == 'outerwear').toList();

    debugPrint('   By type: ${tops.length} tops, ${bottoms.length} bottoms, ${shoes.length} shoes, ${outerwear.length} outerwear');

    // Filtrar y rankear cada tipo
    final filteredTops = _filterAndRankItems(tops, intent);
    final filteredBottoms = _filterAndRankItems(bottoms, intent);
    final filteredShoes = _filterAndRankItems(shoes, intent);
    final filteredOuterwear = _filterAndRankItems(outerwear, intent);

    // Limitar a máximo 20-30 items por tipo para optimizar costos
    final maxItemsPerType = 10;
    
    return FilteredWardrobe(
      tops: filteredTops.take(maxItemsPerType).toList(),
      bottoms: filteredBottoms.take(maxItemsPerType).toList(),
      shoes: filteredShoes.take(maxItemsPerType).toList(),
      outerwear: filteredOuterwear.take(maxItemsPerType).toList(),
    );
  }

  /// Filtra y rankea items basado en criterios
  static List<WardrobeItem> _filterAndRankItems(
    List<WardrobeItem> items,
    OutfitIntent intent,
  ) {
    if (items.isEmpty) return [];

    // Calcular score para cada item
    final scoredItems = items.map((item) {
      final score = _calculateRelevanceScore(item, intent);
      return MapEntry(item, score);
    }).toList();

    // Filtrar items con score mínimo (más estricto si hay colores preferidos)
    // Si el usuario especificó colores, ser más estricto
    final minScore = intent.preferredColors.isNotEmpty ? 0.4 : 0.3;
    final filtered = scoredItems
        .where((entry) {
          final passes = entry.value >= minScore;
          if (!passes) {
            debugPrint('   ❌ Item ${entry.key.id} filtered out: score ${entry.value.toStringAsFixed(2)} < $minScore');
          }
          return passes;
        })
        .toList();

    // Ordenar por score descendente
    filtered.sort((a, b) => b.value.compareTo(a.value));

    debugPrint('   Filtered ${filtered.length} items (min score: $minScore)');

    return filtered.map((entry) => entry.key).toList();
  }

  /// Calcula score de relevancia (0.0 - 1.0)
  static double _calculateRelevanceScore(
    WardrobeItem item,
    OutfitIntent intent,
  ) {
    double score = 0.5; // Base score

    // CRÍTICO 1: Verificar mustInclude con colores específicos para tipo de prenda
    if (intent.constraints?['mustInclude'] != null) {
      final mustInclude = intent.constraints!['mustInclude'].toString().toLowerCase();
      
      // Extraer colores del mustInclude (ej: "white or beige pants" → ["white", "beige"])
      final colorKeywords = ['white', 'beige', 'black', 'blue', 'red', 'green', 'brown', 'gray', 'grey', 'navy', 'tan', 'khaki', 'cream', 'ivory', 'off-white'];
      final mentionedColors = colorKeywords.where((color) => mustInclude.contains(color)).toList();
      
      // Si mustInclude menciona un tipo de prenda específico
      final itemTypeKeywords = {
        'pants': ['bottom', 'pants', 'pantalon', 'pantalones'],
        'pant': ['bottom', 'pants', 'pantalon', 'pantalones'],
        'pantalon': ['bottom', 'pants', 'pantalon', 'pantalones'],
        'pantalones': ['bottom', 'pants', 'pantalon', 'pantalones'],
        'top': ['top', 'shirt', 'camisa', 'blusa'],
        'shirt': ['top', 'shirt', 'camisa'],
        'shoes': ['shoes', 'zapatos', 'zapato'],
        'shoe': ['shoes', 'zapatos', 'zapato'],
      };
      
      String? requiredType;
      for (final entry in itemTypeKeywords.entries) {
        if (mustInclude.contains(entry.key)) {
          requiredType = entry.key;
          break;
        }
      }
      
      // Verificar si este item es del tipo requerido
      bool isRelevantType = true;
      if (requiredType != null) {
        final typeKeywords = itemTypeKeywords[requiredType]!;
        isRelevantType = typeKeywords.any((keyword) => 
          item.type.toLowerCase().contains(keyword) || 
          item.subType.toLowerCase().contains(keyword) ||
          item.name.toLowerCase().contains(keyword)
        );
      }
      
      // Si mustInclude menciona colores Y un tipo de prenda específico
      if (mentionedColors.isNotEmpty && requiredType != null) {
        if (isRelevantType) {
          // Este item ES del tipo requerido, debe tener los colores
          final hasMentionedColor = item.colors.any((itemColor) => 
            mentionedColors.any((mentionedColor) => 
              _colorsMatch(itemColor, mentionedColor)
            )
          );
          
          if (!hasMentionedColor) {
            // Si no tiene ninguno de los colores mencionados, EXCLUIR completamente
            debugPrint('   ❌ Item ${item.id} (${item.type}) excluded: mustInclude requires ${mentionedColors.join(' or ')} ${requiredType} but item has colors: ${item.colors}');
            return 0.0;
          } else {
            // Si tiene el color, boost significativo
            score += 0.3;
            debugPrint('   ✅ Item ${item.id} matches mustInclude: has ${mentionedColors.join(' or ')}');
          }
        }
        // Si no es del tipo requerido, no aplicar restricción (puede ser otro tipo de prenda)
      } else if (mentionedColors.isNotEmpty && requiredType == null) {
        // Si menciona colores pero NO un tipo específico, aplicar a todos los items
        final hasMentionedColor = item.colors.any((itemColor) => 
          mentionedColors.any((mentionedColor) => 
            _colorsMatch(itemColor, mentionedColor)
          )
        );
        
        if (!hasMentionedColor) {
          // Penalizar fuertemente si no tiene los colores
          score -= 0.3;
        } else {
          score += 0.2;
        }
      } else if (isRelevantType && requiredType != null) {
        // Si menciona el tipo pero no colores específicos, solo boost
        score += 0.15;
      }
    }

    // CRÍTICO 2: Penalización fuerte por "mustAvoid"
    if (intent.constraints?['mustAvoid'] != null) {
      final avoid = intent.constraints!['mustAvoid'].toString().toLowerCase();
      // Si la prenda coincide con lo que se debe evitar, score = 0
      if (item.subType.toLowerCase().contains(avoid) || 
          item.name.toLowerCase().contains(avoid) ||
          item.colors.any((c) => avoid.contains(c.toLowerCase()))) {
        return 0.0; // Excluir completamente
      }
    }

    // MEJORA 2: Match difuso de Estilo con boost logarítmico
    if (intent.styleTags.isNotEmpty) {
      // Intersección de tags
      final styleTagSet = intent.styleTags.toSet();
      final itemStyleTagSet = item.styleTags.toSet();
      final matches = styleTagSet.intersection(itemStyleTagSet).length;
      
      if (matches > 0) {
        // Logarithmic boost: 1 match es bueno, 3 matches es excelente, pero no lineal
        score += 0.2 + (0.1 * matches.clamp(0, 3));
      } else {
        // Penalizar estilos opuestos
        final oppositeStyles = {
          'casual': ['formal'],
          'formal': ['casual', 'sporty'],
          'sporty': ['formal', 'elegant'],
        };
        
        for (final intentTag in intent.styleTags) {
          if (oppositeStyles[intentTag] != null) {
            for (final itemTag in item.styleTags) {
              if (oppositeStyles[intentTag]!.contains(itemTag)) {
                score -= 0.2; // Penalizar estilos opuestos
              }
            }
          }
        }
      }
    }

    // 3. Match de colores (30% del score) - MÁS ESTRICTO
    if (intent.preferredColors.isNotEmpty) {
      final colorMatches = item.colors
          .where((color) => intent.preferredColors
              .any((pref) => _colorsMatch(color, pref)))
          .length;
      if (colorMatches > 0) {
        score += 0.3 * (colorMatches / intent.preferredColors.length);
        debugPrint('   ✅ Item ${item.id} color match: ${colorMatches}/${intent.preferredColors.length} colors');
      } else {
        // Penalización más fuerte si no hay match de colores
        // Si el usuario especificó colores, es importante
        score -= 0.35; // Penalización significativa (pero no tan drástica)
        debugPrint('   ⚠️ Item ${item.id} penalized: no color match. Item colors: ${item.colors}, Preferred: ${intent.preferredColors}');
      }
    }

    // 4. Match de temporada (15% del score)
    if (intent.season != null && item.season.isNotEmpty) {
      if (item.season.contains(intent.season)) {
        score += 0.15;
      } else {
        score -= 0.05; // Penalizar si no coincide la temporada
      }
    }

    // 5. Bonus por tener brand (5% del score)
    if (item.brand != null && item.brand!.isNotEmpty) {
      score += 0.05;
    }

    // Nota: El manejo de mustInclude ya se hizo al inicio (CRÍTICO 1)
    // Este código ya no es necesario porque se maneja arriba con exclusión estricta

    // Normalizar a 0.0-1.0
    return score.clamp(0.0, 1.0);
  }

  /// Verifica si dos colores son compatibles
  static bool _colorsMatch(String color1, String color2) {
    // Normalizar colores
    final c1 = color1.toLowerCase().trim();
    final c2 = color2.toLowerCase().trim();

    // Match exacto
    if (c1 == c2) return true;

    // Matches comunes
    final colorGroups = {
      'white': ['white', 'off-white', 'cream', 'beige', 'ivory'],
      'black': ['black', 'navy', 'dark'],
      'blue': ['blue', 'navy', 'denim', 'indigo'],
      'red': ['red', 'burgundy', 'maroon'],
      'green': ['green', 'olive', 'emerald'],
      'brown': ['brown', 'tan', 'khaki', 'beige'],
      'gray': ['gray', 'grey', 'charcoal', 'silver'],
    };

    for (final group in colorGroups.values) {
      if (group.contains(c1) && group.contains(c2)) {
        return true;
      }
    }

    return false;
  }

  /// Calcula compatibilidad entre dos prendas
  /// 
  /// Retorna score de 0.0-1.0 indicando qué tan bien combinan
  static double calculateCompatibility(
    WardrobeItem item1,
    WardrobeItem item2,
  ) {
    double score = 0.5; // Base

    // 1. Compatibilidad de colores (40%)
    final colorCompatibility = _calculateColorCompatibility(
      item1.colors,
      item2.colors,
    );
    score += 0.4 * colorCompatibility;

    // 2. Compatibilidad de estilo (30%)
    final styleCompatibility = _calculateStyleCompatibility(
      item1.styleTags,
      item2.styleTags,
    );
    score += 0.3 * styleCompatibility;

    // 3. Compatibilidad de temporada (20%)
    final seasonCompatibility = _calculateSeasonCompatibility(
      item1.season,
      item2.season,
    );
    score += 0.2 * seasonCompatibility;

    // 4. Bonus si tienen brand (10%)
    if (item1.brand != null && item2.brand != null) {
      if (item1.brand == item2.brand) {
        score += 0.1; // Mismo brand = más compatible
      }
    }

    return score.clamp(0.0, 1.0);
  }

  static double _calculateColorCompatibility(
    List<String> colors1,
    List<String> colors2,
  ) {
    if (colors1.isEmpty || colors2.isEmpty) return 0.5;

    // Verificar si hay colores complementarios o que combinen bien
    final complementaryPairs = [
      ['black', 'white'],
      ['blue', 'brown'],
      ['red', 'blue'],
      ['green', 'brown'],
      ['navy', 'beige'],
    ];

    for (final c1 in colors1) {
      for (final c2 in colors2) {
        // Match exacto
        if (_colorsMatch(c1, c2)) return 0.8;

        // Colores complementarios
        for (final pair in complementaryPairs) {
          if ((pair.contains(c1.toLowerCase()) && pair.contains(c2.toLowerCase()))) {
            return 0.9; // Colores complementarios combinan muy bien
          }
        }
      }
    }

    // Si no hay match, penalizar ligeramente
    return 0.4;
  }

  static double _calculateStyleCompatibility(
    List<String> styles1,
    List<String> styles2,
  ) {
    if (styles1.isEmpty || styles2.isEmpty) return 0.5;

    final matches = styles1.where((s) => styles2.contains(s)).length;
    if (matches > 0) {
      return 0.5 + (0.5 * matches / styles1.length);
    }

    // Estilos opuestos no combinan bien
    final oppositeStyles = {
      'casual': ['formal'],
      'formal': ['casual', 'sporty'],
      'sporty': ['formal', 'elegant'],
    };

    for (final s1 in styles1) {
      for (final s2 in styles2) {
        if (oppositeStyles[s1]?.contains(s2) ?? false) {
          return 0.2; // Penalizar estilos opuestos
        }
      }
    }

    return 0.5; // Neutral
  }

  static double _calculateSeasonCompatibility(
    List<String> seasons1,
    List<String> seasons2,
  ) {
    if (seasons1.isEmpty || seasons2.isEmpty) return 0.5;

    final matches = seasons1.where((s) => seasons2.contains(s)).length;
    if (matches > 0) {
      return 0.5 + (0.5 * matches / seasons1.length);
    }

    return 0.3; // Penalizar si no hay overlap de temporadas
  }
}
