import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

/// Fullscreen lightbox for chat images (bubble thumbnails and markdown
/// inline images route here): pinch zoom, horizontal swipe across every
/// image of the conversation, and drag-down dismiss while at base
/// scale.
///
/// PhotoViewGestureDetectorScope(axis: vertical) is photo_view's
/// documented pattern for PageView contexts: its recognizer only claims
/// vertical drags it can actually pan, so at base scale vertical goes
/// to this page's dismiss detector and horizontal goes to the PageView.
class ImageViewerPage extends StatefulWidget {
  const ImageViewerPage({super.key, required this.providers, this.initialIndex = 0});

  final List<ImageProvider> providers;
  final int initialIndex;

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  late final PageController _pages = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  /// Pages currently zoomed in — dismiss only follows drags on a
  /// base-scale page; zoomed pages keep their pan.
  final Set<int> _zoomed = {};
  double _dragDy = 0;

  bool get _canDismiss => !_zoomed.contains(_index);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          GestureDetector(
            onVerticalDragUpdate:
                _canDismiss ? (d) => setState(() => _dragDy += d.delta.dy) : null,
            onVerticalDragEnd: _canDismiss ? _onDragEnd : null,
            child: TweenAnimationBuilder<double>(
              // Follow the finger instantly while dragging; spring back
              // when released (the only case where _dragDy returns to 0
              // without a pop).
              tween: Tween(begin: 0, end: _dragDy),
              duration: _dragDy == 0
                  ? const Duration(milliseconds: 220)
                  : Duration.zero,
              curve: Curves.easeOutCubic,
              builder: (context, dy, child) =>
                  Transform.translate(offset: Offset(0, dy), child: child),
              child: PageView.builder(
                controller: _pages,
                itemCount: widget.providers.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => PhotoViewGestureDetectorScope(
                  axis: Axis.vertical,
                  child: PhotoView(
                    imageProvider: widget.providers[i],
                    backgroundDecoration: const BoxDecoration(color: Colors.black),
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.covered * 4,
                    scaleStateChangedCallback: (s) => setState(() {
                      final zoomed =
                          s != PhotoViewScaleState.initial && s != PhotoViewScaleState.zoomedOut;
                      zoomed ? _zoomed.add(i) : _zoomed.remove(i);
                    }),
                  ),
                ),
              ),
            ),
          ),
          if (widget.providers.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${_index + 1} / ${widget.providers.length}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _onDragEnd(DragEndDetails d) {
    final flung = d.velocity.pixelsPerSecond.dy.abs() > 700;
    if (_dragDy.abs() > 120 || flung) {
      Navigator.of(context).pop();
    } else {
      setState(() => _dragDy = 0);
    }
  }
}

void openImageViewer(BuildContext context, List<ImageProvider> providers,
    {int initialIndex = 0}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ImageViewerPage(providers: providers, initialIndex: initialIndex)),
  );
}
