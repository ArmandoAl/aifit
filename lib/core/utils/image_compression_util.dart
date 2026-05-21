import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Compression tiers for try-on payloads.
class ImageCompressionUtil {
  ImageCompressionUtil._();

  /// Garment references — smaller payload.
  static const int garmentMaxWidth = 768;
  static const int garmentJpegQuality = 82;

  /// Identity / base images — preserve detail.
  static const int identityMinWidth = 1024;
  static const int identityJpegQuality = 93;

  static Future<Uint8List> compressGarment(File file) async {
    return _compress(file, maxWidth: garmentMaxWidth, quality: garmentJpegQuality);
  }

  static Future<Uint8List> compressIdentity(File file) async {
    return _compress(
      file,
      maxWidth: identityMinWidth,
      quality: identityJpegQuality,
      minWidth: identityMinWidth,
    );
  }

  static Future<Uint8List> compressIdentityBytes(Uint8List bytes) async {
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;
    final resized = _resize(image, identityMinWidth, identityMinWidth);
    return Uint8List.fromList(
      img.encodeJpg(resized, quality: identityJpegQuality),
    );
  }

  static Future<Uint8List> _compress(
    File file, {
    required int maxWidth,
    required int quality,
    int? minWidth,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return bytes;
      final resized = _resize(image, maxWidth, minWidth);
      return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
    } catch (_) {
      return file.readAsBytes();
    }
  }

  static img.Image _resize(img.Image image, int maxWidth, int? minWidth) {
    if (image.width <= maxWidth) {
      if (minWidth != null && image.width < minWidth) {
        return img.copyResize(image, width: minWidth);
      }
      return image;
    }
    return img.copyResize(image, width: maxWidth);
  }
}
