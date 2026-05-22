import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// URLs de Firebase Storage (download URL o bucket .app).
bool isFirebaseStorageUrl(String url) {
  return url.contains('firebasestorage.googleapis.com') ||
      url.contains('.firebasestorage.app');
}

/// Imagen remota: en web + Firebase usa [Reference.getData] (evita CORS con WASM).
class AppNetworkImage extends StatefulWidget {
  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.maxBytes = 20 * 1024 * 1024,
  });

  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;
  final int maxBytes;

  @override
  State<AppNetworkImage> createState() => _AppNetworkImageState();
}

class _AppNetworkImageState extends State<AppNetworkImage> {
  Uint8List? _bytes;
  bool _loading = false;
  bool _useCachedNetwork = false;

  @override
  void initState() {
    super.initState();
    _startLoad();
  }

  @override
  void didUpdateWidget(AppNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _bytes = null;
      _useCachedNetwork = false;
      _startLoad();
    }
  }

  void _startLoad() {
    final url = widget.imageUrl.trim();
    if (url.isEmpty) {
      setState(() => _useCachedNetwork = true);
      return;
    }

    if (kIsWeb && isFirebaseStorageUrl(url)) {
      _loadFromFirebaseStorage(url);
      return;
    }

    setState(() => _useCachedNetwork = true);
  }

  Future<void> _loadFromFirebaseStorage(String url) async {
    setState(() => _loading = true);
    try {
      final ref = FirebaseStorage.instance.refFromURL(url);
      final data = await ref.getData(widget.maxBytes);
      if (!mounted) return;
      if (data != null && data.isNotEmpty) {
        setState(() {
          _bytes = data;
          _loading = false;
        });
        return;
      }
      debugPrint('⚠️ AppNetworkImage: getData vacío para $url');
    } catch (e) {
      debugPrint('⚠️ AppNetworkImage getData: $e');
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _useCachedNetwork = true;
    });
  }

  Widget _defaultPlaceholder() {
    return Container(
      color: AppColors.surfaceContainer,
      alignment: Alignment.center,
      child: const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _defaultError() {
    return Container(
      color: AppColors.surfaceContainer,
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: AppColors.tertiary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.imageUrl.trim();
    if (url.isEmpty) {
      return widget.errorWidget ?? _defaultError();
    }

    if (_bytes != null) {
      return Image.memory(
        _bytes!,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        gaplessPlayback: true,
      );
    }

    if (_loading) {
      return widget.placeholder ?? _defaultPlaceholder();
    }

    if (!_useCachedNetwork && kIsWeb && isFirebaseStorageUrl(url)) {
      return widget.placeholder ?? _defaultPlaceholder();
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      placeholder: (_, __) => widget.placeholder ?? _defaultPlaceholder(),
      errorWidget: (_, __, ___) => widget.errorWidget ?? _defaultError(),
    );
  }
}
