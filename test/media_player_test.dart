import 'dart:async';
import 'dart:typed_data';

import 'package:chewie/chewie.dart';
import 'package:file_manager/core/file_entry.dart';
import 'package:file_manager/services/storage/memory_backend.dart';
import 'package:file_manager/state/app_scope.dart';
import 'package:file_manager/state/file_index.dart';
import 'package:file_manager/state/settings_controller.dart';
import 'package:file_manager/ui/viewers/audio_player_screen.dart';
import 'package:file_manager/ui/viewers/video_player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// Stands in for the native players: every file "loads" as 3:20 long and
/// calls are recorded.
class _FakePlayers extends VideoPlayerPlatform {
  final calls = <String>[];
  final _events = <int, StreamController<VideoEvent>>{};
  var _nextId = 0;

  void finish(int id) => _events[id]!.add(VideoEvent(eventType: VideoEventType.completed));
  int get lastId => _nextId - 1;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = _nextId++;
    calls.add('open ${options.dataSource.uri?.split('/').last}');
    late final StreamController<VideoEvent> events;
    events = StreamController<VideoEvent>(
      // Like the real players: report "initialized" once the app listens.
      onListen: () => events.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(seconds: 200),
          size: const Size(1280, 720),
        ),
      ),
      onCancel: () {},
    );
    _events[id] = events;
    return id;
  }

  @override
  Future<int?> create(DataSource dataSource) =>
      createWithOptions(VideoCreationOptions(dataSource: dataSource, viewType: VideoViewType.textureView));

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events[playerId]!.stream;

  @override
  Future<void> play(int playerId) async => calls.add('play $playerId');

  @override
  Future<void> pause(int playerId) async => calls.add('pause $playerId');

  @override
  Future<void> dispose(int playerId) async => calls.add('dispose $playerId');

  @override
  Future<void> seekTo(int playerId, Duration position) async => calls.add('seek $playerId ${position.inSeconds}');

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
  @override
  Future<void> setAllowBackgroundPlayback(bool allowBackgroundPlayback) async {}
  @override
  Widget buildView(int playerId) => const SizedBox();
  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox();
}

/// Player disposal awaits a future from Dart's root zone, which the test
/// clock doesn't run; let real time pass so it completes.
Future<void> _releasePlayers(WidgetTester tester) =>
    tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));

void main() {
  late _FakePlayers players;
  late MemoryStorageBackend fs;

  setUp(() {
    players = _FakePlayers();
    VideoPlayerPlatform.instance = players;
    fs = MemoryStorageBackend();
  });

  Future<List<FileEntry>> addFiles(List<String> paths) async {
    for (final path in paths) {
      await fs.writeBytes(path, Uint8List.fromList([1, 2, 3]));
    }
    return [for (final path in paths) (await fs.stat(path))!];
  }

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsController.load();
    await tester.pumpWidget(
      AppScope(
        settings: settings,
        index: FileIndex(fs),
        child: MaterialApp(home: screen),
      ),
    );
    // Let the fake player "load" (no pumpAndSettle: the disc spins while playing).
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  test('only formats the built-in players handle are routed to them', () {
    FileEntry f(String name) =>
        FileEntry(path: '/$name', name: name, isDirectory: false, size: 1, modified: DateTime(2026));
    expect(f('clip.mp4').isPlayableVideo, isTrue);
    expect(f('clip.MKV').isPlayableVideo, isTrue);
    expect(f('old.avi').isPlayableVideo, isFalse);
    expect(f('song.flac').isPlayableAudio, isTrue);
    expect(f('song.wma').isPlayableAudio, isFalse);
  });

  testWidgets('audio player shows the track, plays, pauses and moves to the next track', (tester) async {
    final tracks = await addFiles(['/Music/Mila Rose - Golden Hour.mp3', '/Music/Echo Park - Neon Rain.mp3']);
    await pumpScreen(tester, AudioPlayerScreen(tracks: tracks));

    expect(find.text('Golden Hour'), findsOneWidget);
    expect(find.text('Mila Rose'), findsOneWidget);
    expect(find.text('1 of 2'), findsOneWidget);
    expect(players.calls, contains('play 0'));

    // Turning the screen off doesn't stop the music.
    final before = players.calls.length;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(players.calls.skip(before), isNot(contains('pause 0')));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    await tester.tap(find.byTooltip('Forward 10 seconds'));
    await tester.pump();
    expect(players.calls.last, 'seek 0 10');

    await tester.tap(find.bySemanticsLabel('Pause'));
    await tester.pump();
    expect(players.calls.last, 'pause 0');

    // The track ends: the next one starts by itself.
    await tester.tap(find.bySemanticsLabel('Play'));
    players.finish(0);
    await tester.pump();
    await _releasePlayers(tester);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Neon Rain'), findsOneWidget);
    expect(find.text('2 of 2'), findsOneWidget);
    expect(players.calls, containsAllInOrder(['dispose 0', 'play 1']));

    await tester.pumpWidget(const SizedBox());
    await _releasePlayers(tester);
    expect(players.calls, contains('dispose 1'));
  });

  testWidgets('video player opens the file in the player and starts playing', (tester) async {
    final video = (await addFiles(['/Videos/Weekend trip.mp4'])).single;
    await pumpScreen(tester, VideoPlayerScreen(entry: video));

    expect(find.byType(Chewie), findsOneWidget);
    expect(find.text('Weekend trip.mp4'), findsOneWidget);
    expect(players.calls.first, 'open Weekend%20trip.mp4');
    expect(players.calls, contains('play 0'));

    await tester.pumpWidget(const SizedBox());
    await _releasePlayers(tester);
    expect(players.calls, contains('dispose 0'));
  });
}
