import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import '../../services/outfit_service.dart';
import 'outfit_generation_event.dart';
import 'outfit_generation_state.dart';

/// BLoC para manejar la generación de outfits
class OutfitGenerationBloc extends Bloc<OutfitGenerationEvent, OutfitGenerationState> {
  final OutfitService _outfitService = OutfitService();

  OutfitGenerationBloc() : super(OutfitGenerationInitial()) {
    on<GenerateOutfitsRequested>(_onGenerateOutfitsRequested);
    on<GenerateTryOnImageRequested>(_onGenerateTryOnImageRequested);
    on<OutfitGenerationReset>(_onReset);
  }

  Future<void> _onGenerateOutfitsRequested(
    GenerateOutfitsRequested event,
    Emitter<OutfitGenerationState> emit,
  ) async {
    try {
      debugPrint('🚀 Starting outfit generation: "${event.userPrompt}"');

      // Fase 1: Analizando intención
      emit(OutfitGenerationLoading(currentPhase: 'analyzing'));
      await Future.delayed(const Duration(milliseconds: 100)); // Pequeño delay para UI

      // Fase 2: Filtrando prendas
      emit(OutfitGenerationLoading(currentPhase: 'filtering'));
      await Future.delayed(const Duration(milliseconds: 100));

      // Fase 3: Generando outfits
      emit(OutfitGenerationLoading(currentPhase: 'generating'));

      // Si se solicita generar imágenes, mostrar fase de creación
      if (event.generateImage) {
        emit(OutfitGenerationLoading(currentPhase: 'creating_image'));
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Llamar al servicio
      final result = await _outfitService.generateCompleteOutfit(
        userPrompt: event.userPrompt,
        generateImage: event.generateImage,
      );

      // Éxito
      emit(OutfitGenerationLoaded(
        outfits: result.outfits,
        intent: result.intent,
        tryOnImageUrl: result.tryOnImageUrl, // Backward compatibility
        tryOnImageUrls: result.tryOnImageUrls,
      ));

      debugPrint('✅ Outfits generated successfully: ${result.outfits.length} outfits');
    } catch (e) {
      debugPrint('❌ Error generating outfits: $e');
      emit(OutfitGenerationError(message: e.toString()));
    }
  }

  Future<void> _onGenerateTryOnImageRequested(
    GenerateTryOnImageRequested event,
    Emitter<OutfitGenerationState> emit,
  ) async {
    // TODO: Implementar generación de imagen para outfit específico
    // Por ahora, esto se maneja en el flujo completo
    emit(OutfitGenerationError(
      message: 'Try-on image generation for specific outfit not yet implemented',
    ));
  }

  void _onReset(
    OutfitGenerationReset event,
    Emitter<OutfitGenerationState> emit,
  ) {
    emit(OutfitGenerationInitial());
  }
}
