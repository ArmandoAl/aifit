import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../platform/app_image.dart';

/// Payload tier for images sent to AI models.
enum AiImagePayload {
  garment,
  identity,
  raw,
}

/// Preprocesado local antes de enviar a modelos de IA.
class ImageCompressionUtil {
  ImageCompressionUtil._();

  static const int garmentMaxWidth = 768;
  static const int garmentJpegQuality = 82;

  static const int identityMinWidth = 1024;
  static const int identityJpegQuality = 93;

  static Future<Uint8List> compressGarment(AppImage image) {
    return compressBytes(image.bytes, payload: AiImagePayload.garment);
  }

  static Future<Uint8List> compressIdentity(AppImage image) {
    return compressBytes(image.bytes, payload: AiImagePayload.identity);
  }

  static Future<Uint8List> compressIdentityBytes(Uint8List bytes) async {
    if (bytes.isEmpty) return bytes;
    return _runEncode(bytes, payload: AiImagePayload.identity);
  }

  static Future<Uint8List> compressBytes(
    Uint8List bytes, {
    AiImagePayload payload = AiImagePayload.garment,
  }) async {
    if (payload == AiImagePayload.raw) return bytes;
    if (bytes.isEmpty) return bytes;
    return _runEncode(bytes, payload: payload);
  }

  /// Web: encode on UI isolate with a frame yield (avoid worker copy jank).
  /// Mobile/desktop: [compute] keeps decode/resize off the UI thread.
  static Future<Uint8List> _runEncode(
    Uint8List bytes, {
    required AiImagePayload payload,
  }) async {
    final params = _EncodeParams(bytes: bytes, payload: payload);

    if (kIsWeb) {
      await Future<void>.delayed(Duration.zero);
      return _encodeInIsolate(params);
    }

    return compute(_encodeInIsolate, params);
  }
}

class _EncodeParams {
  final Uint8List bytes;
  final AiImagePayload payload;

  const _EncodeParams({required this.bytes, required this.payload});
}

Uint8List _encodeInIsolate(_EncodeParams params) {
  try {
    final image = img.decodeImage(params.bytes);
    if (image == null) return params.bytes;

    switch (params.payload) {
      case AiImagePayload.garment:
        final resized = _resizeGarment(image);
        return Uint8List.fromList(
          img.encodeJpg(
            resized,
            quality: ImageCompressionUtil.garmentJpegQuality,
          ),
        );
      case AiImagePayload.identity:
        final resized = _resizeIdentity(image);
        return Uint8List.fromList(
          img.encodeJpg(
            resized,
            quality: ImageCompressionUtil.identityJpegQuality,
          ),
        );
      case AiImagePayload.raw:
        return params.bytes;
    }
  } catch (_) {
    return params.bytes;
  }
}

img.Image _resizeGarment(img.Image image) {
  if (image.width <= ImageCompressionUtil.garmentMaxWidth) {
    return image;
  }
  return img.copyResize(image, width: ImageCompressionUtil.garmentMaxWidth);
}

img.Image _resizeIdentity(img.Image image) {
  if (image.width >= ImageCompressionUtil.identityMinWidth) {
    return image;
  }
  return img.copyResize(image, width: ImageCompressionUtil.identityMinWidth);
}
