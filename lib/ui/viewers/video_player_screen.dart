import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';

import '../../core/brand.dart';
import '../../core/file_entry.dart';
import '../../services/media/media_source.dart';
import '../../state/app_scope.dart';
import '../widgets/file_actions.dart';

/// Built-in video player: seek, pause, playback speed and fullscreen.
class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key, required this.entry});

  final FileEntry entry;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  MediaHandle? _media;
  ChewieController? _chewie;
  bool _failed = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _open();
    }
  }

  Future<void> _open() async {
    try {
      final media = await openMedia(AppScope.of(context).backend, widget.entry);
      if (!mounted) {
        await media.dispose();
        return;
      }
      _media = media;
      await media.controller.initialize();
      if (!mounted) return;
      setState(() {
        _chewie = ChewieController(
          videoPlayerController: media.controller,
          autoPlay: true,
          allowFullScreen: true,
          allowPlaybackSpeedChanging: true,
          materialProgressColors: ChewieProgressColors(
            playedColor: Brand.ember,
            handleColor: Brand.ember,
            bufferedColor: Colors.white38,
            backgroundColor: Colors.white24,
          ),
          errorBuilder: (context, _) => _error(),
        );
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _media?.dispose();
    super.dispose();
  }

  Widget _error() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 64),
        const SizedBox(height: 12),
        const Text("This video can't be played here", style: TextStyle(color: Colors.white70)),
        TextButton(onPressed: () => openExternally(context, widget.entry), child: const Text('Open with another app')),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'More',
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () => showFileActions(context, widget.entry),
          ),
        ],
      ),
      body: SafeArea(
        child: _failed
            ? _error()
            : _chewie == null
            ? const Center(child: CircularProgressIndicator(color: Brand.ember))
            : Chewie(controller: _chewie!),
      ),
    );
  }
}
