import '../../domain/outfit_models.dart';

/// Estados para el BLoC de generación de outfits

abstract class OutfitGenerationState {}

/// Estado inicial
class OutfitGenerationInitial extends OutfitGenerationState {}

/// Cargando (analizando intención, filtrando, generando)
class OutfitGenerationLoading extends OutfitGenerationState {
  final String? currentPhase; // "analyzing", "filtering", "generating", "creating_image"

  OutfitGenerationLoading({this.currentPhase});
}

/// Outfits generados exitosamente
class OutfitGenerationLoaded extends OutfitGenerationState {
  final List<GeneratedOutfit> outfits;
  final OutfitIntent intent;
  final String? tryOnImageUrl; // Deprecated: usar tryOnImageUrls
  final Map<String, String> tryOnImageUrls; // Map<outfitId, imageUrl>

  OutfitGenerationLoaded({
    required this.outfits,
    required this.intent,
    this.tryOnImageUrl,
    Map<String, String>? tryOnImageUrls,
  }) : tryOnImageUrls = tryOnImageUrls ?? {};

  /// Obtiene la URL de imagen para un outfit específico
  String? getImageUrlForOutfit(String outfitId) {
    return tryOnImageUrls[outfitId] ?? tryOnImageUrl;
  }
}

/// Error en la generación
class OutfitGenerationError extends OutfitGenerationState {
  final String message;

  OutfitGenerationError({required this.message});
}
