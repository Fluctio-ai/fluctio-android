import 'dart:async';

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
  StreamSubscription<Duration>? _audioPosSub;
  StreamSubscription<PlayerState>? _audioStateSub;

  /// video_player: position advances inside value.position WITHOUT
  /// notifyListeners (official VideoProgressIndicator polls with a
  /// Timer too), so the video path needs a periodic tick.
  Timer? _videoTick;
  double _speed = 1.0;

  /// While dragging the slider, stream position updates are ignored so the
  /// thumb doesn't snap back mid-drag.
  double? _dragValue;

  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0];

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
          // position/isPlaying live in controller.value; events rebuild,
          // and a timer keeps position moving during playback.
          c.addListener(_onTick);
          _videoTick = Timer.periodic(
              const Duration(milliseconds: 250), (_) => _onTick());
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
          _audioPosSub = p.positionStream.listen((_) => _onTick());
          _audioStateSub = p.playerStateStream.listen((_) => _onTick());
        }
      }).catchError((e) {
        if (mounted) setState(() => _error = '$e');
      });
    }
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _videoTick?.cancel();
    _audioPosSub?.cancel();
    _audioStateSub?.cancel();
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
                  value: _dragValue ??
                      position.inMilliseconds
                          .clamp(0, duration.inMilliseconds)
                          .toDouble(),
                  max: duration.inMilliseconds.toDouble(),
                  onChanged: (v) => setState(() => _dragValue = v),
                  onChangeEnd: (v) {
                    setState(() => _dragValue = null);
                    final target = Duration(milliseconds: v.toInt());
                    video?.seekTo(target);
                    audio?.seek(target);
                  },
                ),
              ),
              const SizedBox(width: 12),
              _speedButton(theme),
            ],
          ),
          Text('${_fmt(position)} / ${_fmt(duration)}',
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
        ],
      ),
    );
  }

  /// Speed pill next to the slider — popup with common rates.
  Widget _speedButton(ThemeData theme) {
    return PopupMenuButton<double>(
      initialValue: _speed,
      onSelected: _applySpeed,
      itemBuilder: (_) => [
        for (final s in _speeds) PopupMenuItem(value: s, child: Text(_fmtSpeed(s))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Text(_fmtSpeed(_speed),
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.onSurface)),
      ),
    );
  }

  void _applySpeed(double s) {
    setState(() => _speed = s);
    _video?.setPlaybackSpeed(s);
    _audio?.setSpeed(s);
  }

  String _fmtSpeed(double s) => '${s.toString().replaceAll(RegExp(r'\.0$'), '')}×';

  String _fmt(Duration d) =>
      d.inHours > 0 ? d.toString().split('.').first : d.toString().substring(2, 7);
}
