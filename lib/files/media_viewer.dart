import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

import '../l10n/app_localizations.dart';

/// Minimal audio/video viewer. [url] is a LOCAL streaming-proxy URL
/// (media_proxy.dart) — the gateway is cookie-gated and players can't
/// attach headers, so the proxy authenticates upstream and streams
/// (Range passthrough → seeking works, no full download).
class MediaViewerPage extends StatefulWidget {
  const MediaViewerPage({super.key, required this.title, required this.url, required this.kind});

  final String title;
  final String url;

  /// 'video' | 'audio'
  final String kind;

  @override
  State<MediaViewerPage> createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends State<MediaViewerPage> {
  VideoPlayerController? _video;
  AudioPlayer? _audio;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.kind == 'video') {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      _video = c;
      c.initialize().then((_) {
        // Block body — play() returns a Future; an arrow closure would
        // return it and trip setState's assertion (same class of bug as
        // the files-sheet crash).
        if (mounted) {
          setState(() {
            c.play();
          });
        }
      }).catchError((e) {
        if (mounted) setState(() => _error = '$e');
      });
    } else {
      final p = AudioPlayer();
      _audio = p;
      p.setUrl(widget.url).then((_) {
        if (mounted) {
          setState(() {
            p.play();
          });
        }
      }).catchError((e) {
        if (mounted) setState(() => _error = '$e');
      });
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    _audio?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(AppLocalizations.of(context)!.mediaPlayFailed,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.error)),
                    const SizedBox(height: 8),
                    SelectableText('$_error\n${widget.url}',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.outline)),
                  ],
                ),
              ),
            )
          : widget.kind == 'video'
              ? _videoBody(theme)
              : _audioBody(theme),
    );
  }

  Widget _videoBody(ThemeData theme) {
    final c = _video;
    if (c == null || !c.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c)),
          ),
        ),
        _controls(theme),
      ],
    );
  }

  Widget _audioBody(ThemeData theme) {
    return Column(
      children: [
        const Spacer(),
        Icon(Icons.music_note, size: 64, color: theme.colorScheme.outline),
        const SizedBox(height: 12),
        _controls(theme),
        const Spacer(flex: 2),
      ],
    );
  }

  /// Shared play/pause + position/seek strip.
  Widget _controls(ThemeData theme) {
    final video = _video;
    final audio = _audio;
    final playing = video?.value.isPlaying ?? audio?.playing ?? false;
    final duration = video?.value.duration ?? audio?.duration ?? Duration.zero;
    final position = video?.value.position ?? audio?.position ?? Duration.zero;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton.filled(
                onPressed: () {
                  if (playing) {
                    video?.pause();
                    audio?.pause();
                  } else {
                    video?.play();
                    audio?.play();
                  }
                },
                icon: Icon(playing ? Icons.pause : Icons.play_arrow),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Slider(
                  value: position.inMilliseconds
                      .clamp(0, duration.inMilliseconds)
                      .toDouble(),
                  max: duration.inMilliseconds.toDouble(),
                  onChanged: (v) {
                    final target = Duration(milliseconds: v.toInt());
                    video?.seekTo(target);
                    audio?.seek(target);
                  },
                ),
              ),
            ],
          ),
          Text('${_fmt(position)} / ${_fmt(duration)}',
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
        ],
      ),
    );
  }

  String _fmt(Duration d) =>
      d.inHours > 0 ? d.toString().split('.').first : d.toString().substring(2, 7);
}
