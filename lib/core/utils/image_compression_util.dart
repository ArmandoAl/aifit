import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Payload tier for images sent to AI models.
enum AiImagePayload {
  /// Wardrobe / outfit garment references — smaller payload.
  garment,

  /// Identity collage, base image, face/body — preserve detail.
  identity,

  /// No re-encoding (rare fallback).
  raw,
}

/// Local preprocessing before [InlineDataPart] — garment vs identity tiers.
class ImageCompressionUtil {
  ImageCompressionUtil._();

  static const int garmentMaxWidth = 768;
  static const int garmentJpegQuality = 82;

  static const int identityMinWidth = 1024;
  static const int identityJpegQuality = 93;

  static Future<Uint8List> compressGarment(File file) async {
    return compress(file, payload: AiImagePayload.garment);
  }

  static Future<Uint8List> compressIdentity(File file) async {
    return compress(file, payload: AiImagePayload.identity);
  }

  static Future<Uint8List> compressIdentityBytes(Uint8List bytes) async {
    if (bytes.isEmpty) return bytes;
    return compute(
      _encodeInIsolate,
      _EncodeParams(bytes: bytes, payload: AiImagePayload.identity),
    );
  }

  static Future<Uint8List> compress(
    File file, {
    AiImagePayload payload = AiImagePayload.garment,
  }) async {
    if (payload == AiImagePayload.raw) {
      return file.readAsBytes();
    }
    final bytes = await file.readAsBytes();
    return compute(
      _encodeInIsolate,
      _EncodeParams(bytes: bytes, payload: payload),
    );
  }
}

class _EncodeParams {
  final Uint8List bytes;
  final AiImagePayload payload;

  const _EncodeParams({required this.bytes, required this.payload});
}

/// Top-level for [compute] — decode, resize, JPEG encode.
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
