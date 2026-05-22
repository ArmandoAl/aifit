import 'dart:io';

import 'package:flutter/material.dart';

import 'app_image.dart';

Widget buildImageSourcePreview(
  AppImage source, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
}) {
  if (source.localPath != null && source.localPath!.isNotEmpty) {
    return Image.file(
      File(source.localPath!),
      fit: fit,
      width: width,
      height: height,
    );
  }
  return Image.memory(
    source.bytes,
    fit: fit,
    width: width,
    height: height,
  );
}
