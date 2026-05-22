import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import '../../../core/services/deepseek_service.dart';
import '../../wardrobe/domain/wardrobe_palette.dart';
import '../domain/outfit_intent_prompt.dart';
import '../domain/outfit_models.dart';

/// Fase 1: Analiza el prompt del usuario → [OutfitIntent] JSON estructurado.
///
/// Primario: DeepSeek (JSON mode + prompt con ejemplo completo).
/// Fallback: Gemini 2.5 Flash si DeepSeek falla.
class OutfitIntentAnalyzer {
  final DeepSeekService _deepSeek = DeepSeekService();
  late final GenerativeModel _geminiFallback;

  OutfitIntentAnalyzer() {
    _geminiFallback = FirebaseAI.vertexAI().generativeModel(
      model: 'gemini-2.5-flash',
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.2,
      ),
    );
  }

  Future<OutfitIntent> analyzeUserPrompt(String userPrompt) async {
    debugPrint('🔍 FASE 1 — Analyzing intent: "$userPrompt"');

    try {
      final jsonMap = await _analyzeWithDeepSeek(userPrompt);
      jsonMap['userPrompt'] = userPrompt;
      debugPrint('🧠 DeepSeek reasoning: ${jsonMap['reasoning']}');
      debugPrint('✅ Intent (DeepSeek): $jsonMap');
      return OutfitIntent.fromJson(jsonMap);
    } catch (e) {
      debugPrint('⚠️ DeepSeek failed ($e), trying Gemini fallback...');
      try {
        final jsonMap = await _analyzeWithGemini(userPrompt);
        jsonMap['userPrompt'] = userPrompt;
        return OutfitIntent.fromJson(jsonMap);
      } catch (e2) {
        debugPrint('❌ Gemini fallback failed: $e2');
        return _localFallbackAnalysis(userPrompt);
      }
    }
  }

  Future<Map<String, dynamic>> _analyzeWithDeepSeek(String userPrompt) async {
    return _deepSeek.chatJson(
      systemPrompt: OutfitIntentPrompt.systemRole,
      userPrompt: OutfitIntentPrompt.userPrompt(
        userPrompt,
        DateTime.now(),
      ),
    );
  }

  Future<Map<String, dynamic>> _analyzeWithGemini(String userPrompt) async {
    final promptText = OutfitIntentPrompt.userPrompt(userPrompt, DateTime.now());
    final response = await _geminiFallback.generateContent([
      Content.text('${OutfitIntentPrompt.systemRole}\n\n$promptText'),
    ]);
    final text = response.text;
    if (text == null || text.isEmpty) throw Exception('Empty Gemini response');
    return _parseJsonMap(text);
  }

  Map<String, dynamic> _parseJsonMap(String raw) {
    final clean = raw.replaceAll('```json', '').replaceAll('```', '').trim();
    return jsonDecode(clean) as Map<String, dynamic>;
  }

  OutfitIntent _localFallbackAnalysis(String prompt) {
    final lower = prompt.toLowerCase();
    String? occasion;
    final styleTags = <String>[];
    final preferredColors = <String>[];

    if (lower.contains('boda') ||
        lower.contains('wedding') ||
        lower.contains('formal')) {
      occasion = 'formal';
      styleTags.add('formal');
    } else if (lower.contains('gym') ||
        lower.contains('deporte') ||
        lower.contains('sport')) {
      occasion = 'sport';
      styleTags.add('sporty');
    } else if (lower.contains('trabajo') || lower.contains('work')) {
      occasion = 'work';
      styleTags.add('formal');
    } else {
      occasion = 'casual';
      styleTags.add('casual');
    }

    for (final color in WardrobePalette.standardColors) {
      if (lower.contains(color) ||
          lower.contains(WardrobePalette.labelColor(color).toLowerCase())) {
        preferredColors.add(color);
      }
    }
    for (final entry in {
      'negro': 'black',
      'blanco': 'white',
      'gris': 'gray',
      'azul': 'blue',
      'rojo': 'red',
      'verde': 'green',
      'beige': 'beige',
    }.entries) {
      if (lower.contains(entry.key)) {
        preferredColors.add(WardrobePalette.normalizeColor(entry.value));
      }
    }
    final normalizedColors =
        WardrobePalette.normalizeColors(preferredColors.toList());
    preferredColors
      ..clear()
      ..addAll(normalizedColors);

    return OutfitIntent(
      reasoning: 'Local fallback (AI unavailable)',
      userPrompt: prompt,
      occasion: occasion,
      styleTags: styleTags,
      preferredColors: preferredColors,
    );
  }
}
