import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Deterministic vertical identity collage (local only, no AI).
///
/// Layout (top → bottom):
/// 1. Front face
/// 2. 3/4 face
/// 3. Full body front
/// 4. Full body side
class IdentityPhotoCollage {
  IdentityPhotoCollage._();

  static const int canvasWidth = 1024;
  static const int rowHeight = 512;
  static const int rowCount = 4;
  static const int canvasHeight = rowHeight * rowCount;
  static const int rowSpacing = 8;
  static const int identityJpegQuality = 93;

  static final _background = img.ColorRgb8(245, 245, 245);

  /// Ordered slots: front face, 3/4 face, body front, body side.
  static Future<Uint8List> buildVertical({
    required List<File> facePhotos,
    required List<File> bodyPhotos,
  }) async {
    final slots = <File?>[
      facePhotos.isNotEmpty ? facePhotos[0] : null,
      facePhotos.length > 1 ? facePhotos[1] : facePhotos.firstOrNull,
      bodyPhotos.isNotEmpty ? bodyPhotos[0] : null,
      bodyPhotos.length > 1 ? bodyPhotos[1] : bodyPhotos.firstOrNull,
    ];

    final fallback = slots.firstWhere(
      (f) => f != null,
      orElse: () => null,
    );

    final canvas = img.Image(width: canvasWidth, height: canvasHeight);
    img.fill(canvas, color: _background);

    for (var i = 0; i < rowCount; i++) {
      final file = slots[i] ?? fallback;
      if (file == null) continue;

      final rowImage = await _fitToRow(file);
      img.compositeImage(canvas, rowImage, dstX: 0, dstY: i * rowHeight);
    }

    return Uint8List.fromList(
      img.encodeJpg(canvas, quality: identityJpegQuality),
    );
  }

  /// Legacy API — maps files in order to vertical slots when only one list given.
  static Future<Uint8List> buildFromFiles(List<File> files) async {
    if (files.isEmpty) {
      throw ArgumentError('At least one photo required for collage');
    }
    final face = files.take(2).toList();
    final body = files.length > 2 ? files.skip(2).take(2).toList() : <File>[];
    if (body.isEmpty && files.length >= 2) {
      return buildVertical(
        facePhotos: files.take((files.length / 2).ceil()).toList(),
        bodyPhotos: files.skip((files.length / 2).ceil()).toList(),
      );
    }
    return buildVertical(facePhotos: face, bodyPhotos: body.isNotEmpty ? body : face);
  }

  static Future<img.Image> _fitToRow(File file) async {
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Could not decode: ${file.path}');
    }

    final targetW = canvasWidth - 16;
    final targetH = rowHeight - 16;
    final scale = (targetW / decoded.width).clamp(0.0, 2.0);
    final scaleH = targetH / decoded.height;
    final factor = scale < scaleH ? scale : scaleH;

    var resized = img.copyResize(
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
