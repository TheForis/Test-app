import 'dart:math';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/brand.dart';
import '../../core/file_category.dart';
import '../../core/file_entry.dart';
import '../../services/media/media_source.dart';
import '../../state/app_scope.dart';
import '../widgets/brand_logo.dart';
import '../widgets/file_actions.dart';

/// Built-in music player for the audio files in a folder: seek, skip ±10 s,
/// previous/next, and it moves on to the next track by itself.
class AudioPlayerScreen extends StatefulWidget {
  const AudioPlayerScreen({super.key, required this.tracks, this.initialIndex = 0});

  final List<FileEntry> tracks;
  final int initialIndex;

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> with SingleTickerProviderStateMixin {
  late int _index = widget.initialIndex;
  late final _spin = AnimationController(vsync: this, duration: const Duration(seconds: 12));
  MediaHandle? _media;
  bool _failed = false;
  bool _started = false;
  bool _advancing = false;
  double? _dragValue;

  FileEntry get _track => widget.tracks[_index];
  VideoPlayerValue? get _value => _media?.controller.value;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load(_index);
    }
  }

  Future<void> _load(int index) async {
    final backend = AppScope.of(context).backend;
    final old = _media;
    old?.controller.removeListener(_onTick);
    setState(() {
      _index = index;
      _media = null;
      _failed = false;
      _dragValue = null;
    });
    await old?.dispose();
    try {
      // Keeps playing when the screen turns off.
      final media = await openMedia(backend, widget.tracks[index], keepPlayingInBackground: true);
      if (!mounted || _index != index) {
        await media.dispose();
        return;
      }
      await media.controller.initialize();
      if (!mounted || _index != index) {
        await media.dispose();
        return;
      }
      media.controller.addListener(_onTick);
      setState(() => _media = media);
      _advancing = false;
      await media.controller.play();
    } catch (_) {
      if (mounted && _index == index) setState(() => _failed = true);
    }
  }

  void _onTick() {
    final value = _value;
    if (value == null || !mounted) return;
    if (value.isPlaying) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      _spin.stop();
    }
    if (value.isCompleted && !_advancing && _index < widget.tracks.length - 1) {
      _advancing = true;
      _load(_index + 1);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _media?.controller.removeListener(_onTick);
    _media?.dispose();
    _spin.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final c = _media?.controller;
    if (c == null) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      if (c.value.isCompleted) c.seekTo(Duration.zero);
      c.play();
    }
  }

  void _skip(int seconds) {
    final c = _media?.controller;
    if (c == null) return;
    final target = c.value.position + Duration(seconds: seconds);
    c.seekTo(target < Duration.zero ? Duration.zero : (target > c.value.duration ? c.value.duration : target));
  }

  void _previous() {
    // Like any music player: restart the track unless it has only just begun.
    if ((_value?.position ?? Duration.zero) > const Duration(seconds: 3) || _index == 0) {
      _media?.controller.seekTo(Duration.zero);
    } else {
      _load(_index - 1);
    }
  }

  /// "Artist - Title.mp3" -> ("Title", "Artist").
  static (String, String?) _titleOf(FileEntry e) {
    final base = e.extension.isEmpty ? e.name : e.name.substring(0, e.name.length - e.extension.length - 1);
    final dash = base.indexOf(' - ');
    if (dash <= 0) return (base, null);
    return (base.substring(dash + 3), base.substring(0, dash));
  }

  static String _time(Duration d) {
    final m = d.inMinutes, s = d.inSeconds % 60;
    final h = d.inHours;
    return h > 0
        ? '$h:${(m % 60).toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (title, artist) = _titleOf(_track);
    final value = _value;
    final duration = value?.duration ?? Duration.zero;
    final position = value?.position ?? Duration.zero;
    final max = duration.inMilliseconds.toDouble();
    final playing = value?.isPlaying ?? false;
    final white70 = Colors.white.withValues(alpha: 0.7);

    return Scaffold(
      backgroundColor: Brand.ink,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(
          widget.tracks.length > 1 ? '${_index + 1} of ${widget.tracks.length}' : 'Now playing',
          style: text.titleMedium?.copyWith(color: white70),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'More',
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () => showFileActions(context, _track),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.3),
            radius: 1,
            colors: [FileCategory.audio.color.withValues(alpha: 0.28), Brand.ink],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: LayoutBuilder(
                builder: (context, c) {
                  final disc = min(c.maxWidth * 0.72, c.maxHeight * 0.42).clamp(140.0, 340.0);
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
                    child: Column(
                      children: [
                        const Spacer(),
                        RotationTransition(
                          turns: _spin,
                          child: CustomPaint(size: Size.square(disc), painter: _DiscPainter()),
                        ),
                        const Spacer(),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          artist ?? _track.extension.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium?.copyWith(color: FileCategory.audio.gradient.last),
                        ),
                        const SizedBox(height: 24),
                        if (_failed)
                          Column(
                            children: [
                              Text("This file can't be played here", style: TextStyle(color: white70)),
                              TextButton(
                                onPressed: () => openExternally(context, _track),
                                child: const Text('Open with another app'),
                              ),
                            ],
                          )
                        else ...[
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 4,
                              activeTrackColor: Brand.ember,
                              inactiveTrackColor: Colors.white24,
                              thumbColor: Colors.white,
                              overlayColor: Brand.ember.withValues(alpha: 0.2),
                            ),
                            child: Slider(
                              value: (_dragValue ?? position.inMilliseconds.toDouble()).clamp(0, max <= 0 ? 1 : max),
                              max: max <= 0 ? 1 : max,
                              onChanged: max <= 0 ? null : (v) => setState(() => _dragValue = v),
                              onChangeEnd: max <= 0
                                  ? null
                                  : (v) {
                                      _media?.controller.seekTo(Duration(milliseconds: v.round()));
                                      setState(() => _dragValue = null);
                                    },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            child: Row(
                              children: [
                                Text(
                                  _time(Duration(milliseconds: (_dragValue ?? position.inMilliseconds).round())),
                                  style: TextStyle(color: white70, fontSize: 12.5),
                                ),
                                const Spacer(),
                                Text(_time(duration), style: TextStyle(color: white70, fontSize: 12.5)),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              tooltip: 'Previous',
                              iconSize: 32,
                              color: Colors.white,
                              onPressed: _media == null ? null : _previous,
                              icon: const Icon(Icons.skip_previous_rounded),
                            ),
                            IconButton(
                              tooltip: 'Back 10 seconds',
                              iconSize: 28,
                              color: Colors.white,
                              onPressed: _media == null ? null : () => _skip(-10),
                              icon: const Icon(Icons.replay_10_rounded),
                            ),
                            SizedBox.square(
                              dimension: 72,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Brand.ember,
                                  foregroundColor: Colors.white,
                                  shape: const CircleBorder(),
                                  padding: EdgeInsets.zero,
                                ),
                                onPressed: _media == null ? null : _togglePlay,
                                child: _media == null && !_failed
                                    ? const SizedBox.square(
                                        dimension: 26,
                                        child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
                                      )
                                    : Icon(
                                        playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                        size: 40,
                                        semanticLabel: playing ? 'Pause' : 'Play',
                                      ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Forward 10 seconds',
                              iconSize: 28,
                              color: Colors.white,
                              onPressed: _media == null ? null : () => _skip(10),
                              icon: const Icon(Icons.forward_10_rounded),
                            ),
                            IconButton(
                              tooltip: 'Next',
                              iconSize: 32,
                              color: Colors.white,
                              onPressed: _index < widget.tracks.length - 1 ? () => _load(_index + 1) : null,
                              icon: const Icon(Icons.skip_next_rounded),
                            ),
                          ],
                        ),
                        const Spacer(),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A vinyl record with the Burrow mark on its label.
class _DiscPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(
      c + const Offset(0, 10),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(colors: [Color(0xFF2A2533), Color(0xFF0E0C13)])
            .createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // Grooves.
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.05);
    for (var gr = r * 0.42; gr < r * 0.97; gr += r * 0.035) {
      canvas.drawCircle(c, gr, groove);
    }
    // Sheen across the vinyl, which makes the spin visible.
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.8),
      -pi * 0.85,
      pi * 0.35,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.3
        ..color = Colors.white.withValues(alpha: 0.05),
    );
    // Label.
    final label = r * 0.38;
    canvas.drawCircle(
      c,
      label,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: FileCategory.audio.gradient,
        ).createShader(Rect.fromCircle(center: c, radius: label)),
    );
    canvas.save();
    canvas.translate(c.dx - label * 0.6, c.dy - label * 0.6);
    const BurrowMarkPainter(background: false, monochrome: Colors.white).paint(canvas, Size.square(label * 1.2));
    canvas.restore();
    canvas.drawCircle(c, r * 0.035, Paint()..color = Brand.ink);
  }

  @override
  bool shouldRepaint(_DiscPainter old) => false;
}
