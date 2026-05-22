import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../platform/app_image.dart';

/// Collage vertical de identidad (solo bytes, sin disco).
class IdentityPhotoCollage {
  IdentityPhotoCollage._();

  static const int canvasWidth = 1024;
  static const int rowHeight = 512;
  static const int rowCount = 4;
  static const int canvasHeight = rowHeight * rowCount;
  static const int identityJpegQuality = 93;

  static final _background = img.ColorRgb8(245, 245, 245);

  static Future<Uint8List> buildVertical({
    required List<Uint8List> facePhotos,
    required List<Uint8List> bodyPhotos,
  }) async {
    final slots = <Uint8List?>[
      facePhotos.isNotEmpty ? facePhotos[0] : null,
      facePhotos.length > 1 ? facePhotos[1] : facePhotos.firstOrNull,
      bodyPhotos.isNotEmpty ? bodyPhotos[0] : null,
      bodyPhotos.length > 1 ? bodyPhotos[1] : bodyPhotos.firstOrNull,
    ];

    final fallback = slots.firstWhere((b) => b != null, orElse: () => null);

    final canvas = img.Image(width: canvasWidth, height: canvasHeight);
    img.fill(canvas, color: _background);

    for (var i = 0; i < rowCount; i++) {
      final bytes = slots[i] ?? fallback;
      if (bytes == null) continue;

      final rowImage = _fitToRow(bytes);
      img.compositeImage(canvas, rowImage, dstX: 0, dstY: i * rowHeight);
    }

    return Uint8List.fromList(
      img.encodeJpg(canvas, quality: identityJpegQuality),
    );
  }

  static Future<Uint8List> buildFromSources(List<AppImage> sources) async {
    if (sources.isEmpty) {
      throw ArgumentError('At least one photo required for collage');
    }
    final face = sources.take(2).map((s) => s.bytes).toList();
    final body = sources.length > 2
        ? sources.skip(2).take(2).map((s) => s.bytes).toList()
        : <Uint8List>[];
    if (body.isEmpty && sources.length >= 2) {
      final half = (sources.length / 2).ceil();
      return buildVertical(
        facePhotos: sources.take(half).map((s) => s.bytes).toList(),
        bodyPhotos: sources.skip(half).map((s) => s.bytes).toList(),
      );
    }
    return buildVertical(
      facePhotos: face,
      bodyPhotos: body.isNotEmpty ? body : face,
    );
  }

  static img.Image _fitToRow(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Could not decode image bytes');
    }

    const targetW = canvasWidth - 16;
    const targetH = rowHeight - 16;
    final scale = (targetW / decoded.width).clamp(0.0, 2.0);
    final scaleH = targetH / decoded.height;
    final factor = scale < scaleH ? scale : scaleH;

    final resized = img.copyResize(
      decoded,
      width: (decoded.width * factor).round().clamp(1, targetW),
      height: (decoded.height * factor).round().clamp(1, targetH),
    );

    final row = img.Image(width: canvasWidth, height: rowHeight);
    img.fill(row, color: _background);
    final offsetX = (canvasWidth - resized.width) ~/ 2;
    final offsetY = (rowHeight - resized.height) ~/ 2;
    img.compositeImage(row, resized, dstX: offsetX, dstY: offsetY);
    return row;
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
