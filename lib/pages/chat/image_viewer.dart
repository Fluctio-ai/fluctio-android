import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

/// Fullscreen zoomable viewer for chat images (bubble thumbnails and
/// markdown inline images route here).
class ImageViewerPage extends StatelessWidget {
  const ImageViewerPage({super.key, required this.provider});

  final ImageProvider provider;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: PhotoView(
        imageProvider: provider,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 4,
      ),
    );
  }
}

void openImageViewer(BuildContext context, ImageProvider provider) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => ImageViewerPage(provider: provider)),
  );
}
