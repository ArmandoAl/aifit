import '../../domain/outfit_models.dart';
import '../../domain/try_on_status.dart';

abstract class OutfitGenerationState {}

class OutfitGenerationInitial extends OutfitGenerationState {}

class OutfitGenerationLoading extends OutfitGenerationState {
  final String? currentPhase;

  OutfitGenerationLoading({this.currentPhase});
}

class OutfitGenerationLoaded extends OutfitGenerationState {
  final List<GeneratedOutfit> outfits;
  final OutfitIntent intent;
  final String? tryOnImageUrl;
  final Map<String, String> tryOnImageUrls;
  final Map<String, TryOnStatus> tryOnStatuses;
  final Map<String, String> tryOnErrors;

  OutfitGenerationLoaded({
    required this.outfits,
    required this.intent,
    this.tryOnImageUrl,
    Map<String, String>? tryOnImageUrls,
    Map<String, TryOnStatus>? tryOnStatuses,
    Map<String, String>? tryOnErrors,
  })  : tryOnImageUrls = tryOnImageUrls ?? {},
        tryOnStatuses = tryOnStatuses ?? {},
        tryOnErrors = tryOnErrors ?? {};

  String? getImageUrlForOutfit(String outfitId) {
    return tryOnImageUrls[outfitId] ?? tryOnImageUrl;
  }

  TryOnStatus statusFor(String outfitId) {
    return tryOnStatuses[outfitId] ?? TryOnStatus.none;
  }

  OutfitGenerationLoaded copyWith({
    List<GeneratedOutfit>? outfits,
    OutfitIntent? intent,
    String? tryOnImageUrl,
    Map<String, String>? tryOnImageUrls,
    Map<String, TryOnStatus>? tryOnStatuses,
    Map<String, String>? tryOnErrors,
  }) {
    return OutfitGenerationLoaded(
      outfits: outfits ?? this.outfits,
      intent: intent ?? this.intent,
      tryOnImageUrl: tryOnImageUrl ?? this.tryOnImageUrl,
      tryOnImageUrls: tryOnImageUrls ?? this.tryOnImageUrls,
      tryOnStatuses: tryOnStatuses ?? this.tryOnStatuses,
      tryOnErrors: tryOnErrors ?? this.tryOnErrors,
    );
  }
}

class OutfitGenerationError extends OutfitGenerationState {
  final String message;

  OutfitGenerationError({required this.message});
}
