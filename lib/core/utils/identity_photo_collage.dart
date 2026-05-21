import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Builds a single composite reference image from multiple identity photos.
///
/// Layout: up to 4 slots in a 2x2 grid (face/body refs). Sends one image to
/// the model instead of multiple separate InlineDataPart payloads.
class IdentityPhotoCollage {
  IdentityPhotoCollage._();

  static const int cellSize = 512;
  static const int gridSize = cellSize * 2;

  /// [labeledFiles] optional keys: frontal, profile, smile, full_body (order preserved).
  static Future<Uint8List> buildFromFiles(List<File> files) async {
    if (files.isEmpty) {
      throw ArgumentError('At least one photo required for collage');
    }
    if (files.length == 1) {
      return _encodeCell(await _loadAndFit(files.first));
    }

    final slots = files.take(4).map(_loadAndFit).toList();
    final images = await Future.wait(slots);

    final canvas = img.Image(width: gridSize, height: gridSize);
    img.fill(canvas, color: img.ColorRgb8(240, 240, 240));

    final positions = [
      (0, 0),
      (cellSize, 0),
      (0, cellSize),
      (cellSize, cellSize),
    ];

    for (var i = 0; i < images.length && i < positions.length; i++) {
      final (x, y) = positions[i];
      img.compositeImage(canvas, images[i], dstX: x, dstY: y);
    }

    return Uint8List.fromList(img.encodeJpg(canvas, quality: 85));
  }

  static Future<img.Image> _loadAndFit(File file) async {
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Could not decode image: ${file.path}');
    }
    return img.copyResizeCropSquare(decoded, size: cellSize);
  }

  static Future<Uint8List> _encodeCell(img.Image image) async {
    final resized = img.copyResize(image, width: 1024);
    return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
  }
}
