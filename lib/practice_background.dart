// Start a background isolate for executing drills.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';
import 'package:rxdart/rxdart.dart';

import 'drill_data.dart';
import 'duration_formatter.dart';

/// Methods to manage the practice background task.
class PracticeBackground {
  static final _log = Logger();
  static const _action = 'action';
  static const _shotCount = 'shotCount';
  static const _elapsed = 'elapsed';
  static const _drill = 'drill';

  /// Start practicing the provided drill.
  static Future<void> startPractice(DrillData drill) async {
    _log.i('PracticeBackground drill: ${drill.name}');
    await AudioService.start(
        backgroundTaskEntrypoint: _startBackgroundTask,
        androidNotificationChannelName: 'FoosTrainerNotificationChannel',
        androidNotificationIcon: 'drawable/ic_stat_ic_notification',
        androidNotificationColor: Colors.blueAccent.value);
    _log.i('AudioService running: ${AudioService.running}');
    if (AudioService.running) {
      var progress = PracticeProgress(
          drill: drill,
          state: PracticeState.paused,
          elapsed: DurationFormatter.zero,
          action: '',
          shotCount: 0);
      AudioService.playMediaItem(getMediaItemFromProgress(progress));
    } else {
      throw StateError('Failed to start AudioService.');
    }
  }

  // True if the audio service is running in the background.
  static get running => AudioService.running;

  /// Pause the drill.
  static pause() {
    AudioService.pause();
  }

  /// Play the drill.
  static play() {
    AudioService.play();
  }

  /// Get a stream of progress updates.
  static Stream<PracticeProgress> get progressStream =>
      Rx.combineLatest2<MediaItem, PlaybackState, PracticeProgress>(
          AudioService.currentMediaItemStream,
          AudioService.playbackStateStream,
          (mediaItem, playbackState) =>
              _transformBackgroundUpdate(mediaItem, playbackState));

  /// Stop practice.
  static Future<void> stopPractice() async {
    AudioService.stop();
    return true;
  }

  /// Get a progress report from a MediaItem update.
  static PracticeProgress _transformBackgroundUpdate(
      MediaItem mediaItem, PlaybackState playbackState) {
    var extras = mediaItem?.extras ?? {};
    String drillDataJson = extras[_drill];
    if (drillDataJson == null) {
      throw StateError('MediaItem missing drill: ${mediaItem?.id}');
    }
    PracticeState state = PracticeState.paused;
    if (playbackState?.playing ?? false) {
      state = PracticeState.playing;
    }
    return PracticeProgress(
        drill: DrillData.fromJson(jsonDecode(extras[_drill])),
        state: state,
        action: extras[_action],
        shotCount: extras[_shotCount],
        elapsed: extras[_elapsed]);
  }

  /// Get a media item from the specified progress.
  static MediaItem getMediaItemFromProgress(PracticeProgress progress) {
    return MediaItem(
        id: progress.drill.name,
        album: 'Time: ${progress.elapsed}, Reps: ${progress.shotCount}',
        title: progress.drill.name,
        displayDescription: progress.drill.name,
        displayTitle: 'Time: ${progress.elapsed}',
        displaySubtitle: 'Reps: ${progress.shotCount}',
        extras: {
          _action: progress.action,
          _shotCount: progress.shotCount,
          _elapsed: progress.elapsed,
          _drill: jsonEncode(progress.drill.toJson()),
        });
  }
}

void _startBackgroundTask() {
  Logger().i('_startBackgroundTask invoked');
  AudioServiceBackground.run(() => _BackgroundTask());
}

enum PracticeState {
  paused,
  playing,
  stopped,
}

/// Current state of practice.
class PracticeProgress {
  DrillData drill;
  PracticeState state;
  String action;
  int shotCount;
  String elapsed;

  PracticeProgress(
      {@required this.drill,
      @required this.state,
      @required this.action,
      @required this.shotCount,
      @required this.elapsed});

  factory PracticeProgress.empty() {
    return PracticeProgress(
        drill: null,
        state: PracticeState.stopped,
        action: 'Loading',
        shotCount: 0,
        elapsed: DurationFormatter.zero);
  }
}

const MediaControl _pauseControl = MediaControl(
  androidIcon: 'drawable/ic_stat_pause',
  label: 'Pause',
  action: MediaAction.pause,
);

const MediaControl _playControl = MediaControl(
  androidIcon: 'drawable/ic_stat_play_arrow',
  label: 'Play',
  action: MediaAction.play,
);

const MediaControl _stopControl = MediaControl(
  androidIcon: 'drawable/ic_stat_stop',
  label: 'Stop',
  action: MediaAction.stop,
);

class _BackgroundTask extends BackgroundAudioTask {
  static const _startEvent = 'ft_start_practice';
  static const _stopEvent = 'ft_stop_practice';
  static const _pauseEvent = 'ft_pause_practice';
  static const _playEvent = 'ft_play_practice';
  static const _elapsedSeconds = 'elapsed_seconds';
  static const _drillType = 'drill_type';
  static const _drillName = 'drill_name';

  static final _analytics = FirebaseAnalytics();
  static final _log = Logger();
  static final _rand = Random.secure();

  final _player = AudioPlayer();
  final _completer = Completer();
  final _stopwatch = Stopwatch();

  PracticeProgress _progress = PracticeProgress.empty();
  Timer _actionTimer;
  Timer _elapsedTimeUpdater;

  _BackgroundTask();

  void _logEvent(String name) {
    _analytics.logEvent(name: name, parameters: {
      _drillType: _progress?.drill?.type ?? '',
      _drillName: _progress?.drill?.name ?? '',
      _elapsedSeconds: _stopwatch.elapsed.inSeconds,
    });
  }

  @override
  Future<void> onStart(Map<String, dynamic> params) {
    _log.i('_BackgroundTask onStart');
    return _completer.future;
  }

  @override
  void onPlayMediaItem(MediaItem mediaItem) {
    _progress = PracticeBackground._transformBackgroundUpdate(mediaItem, null);
    _log.i('_BackgroundTask onPlayMediaItem: ${_progress.drill.name}');
    _stopwatch.reset();
    _logEvent(_startEvent);
    onPlay();
  }

  @override
  void onPlay() async {
    _logEvent(_playEvent);
    _log.i('_BackgroundTask onPlay: ${_progress.drill.name}');
    _progress.state = PracticeState.playing;
    await AudioServiceBackground.setState(
        controls: [_pauseControl, _stopControl],
        playing: true,
        processingState: AudioProcessingState.ready);
    _stopwatch.start();
    _actionTimer = Timer(Duration(seconds: 0), _waitForSetup);
    _elapsedTimeUpdater =
        Timer.periodic(Duration(milliseconds: 200), _updateElapsed);
  }

  @override
  void onPause() async {
    _logEvent(_pauseEvent);
    _log.i('_BackgroundTask onPause: ${_progress.drill.name}');
    _progress.state = PracticeState.paused;
    _stopwatch.stop();
    _actionTimer.cancel();
    _elapsedTimeUpdater.cancel();
    _progress.action = 'Paused';
    _updateMediaItem();
    await AudioServiceBackground.setState(
        controls: [_playControl, _stopControl],
        playing: false,
        processingState: AudioProcessingState.ready);
  }

  @override
  Future<void> onStop() async {
    _logEvent(_stopEvent);
    _log.i('_BackgroundTask onStop: ${_progress?.drill?.name}');
    _progress.state = PracticeState.stopped;
    _stopwatch?.reset();
    _actionTimer?.cancel();
    _elapsedTimeUpdater?.cancel();
    if (_player?.playbackState == AudioPlaybackState.playing) {
      _log.i('Telling audio player to stop.');
      await _player.stop();
    }
    _log.i('Setting playback state to none');
    await AudioServiceBackground.setState(
        controls: [],
        playing: false,
        processingState: AudioProcessingState.none);
    // This closes the notification.
    _log.i('Completing the AudioBackgroundTask');
    _completer?.complete();
    await super.onStop();
  }

  void _waitForSetup() {
    if (_progress.state != PracticeState.playing) {
      return;
    }
    _progress.action = 'Setup';
    _updateMediaItem();
    _actionTimer = Timer(Duration(seconds: 3), _waitForAction);
  }

  void _waitForAction() {
    if (_progress.state != PracticeState.playing) {
      return;
    }
    _progress.action = 'Wait';
    _updateMediaItem();
    var waitTime = Duration(
        milliseconds: _rand.nextInt(_progress.drill.maxSeconds * 1000));
    _actionTimer = Timer(waitTime, _playAction);
  }

  void _playAction() async {
    if (_progress.state != PracticeState.playing) {
      return;
    }
    ++_progress.shotCount;
    int actionIndex = _rand.nextInt(_progress.drill.actions.length);
    ActionData actionData = _progress.drill.actions[actionIndex];
    _progress.action = actionData.label;
    _updateMediaItem();
    await _player.setAsset(actionData.audioAsset);
    await _player.play();
    _actionTimer = Timer(Duration(seconds: 1), _waitForSetup);
  }

  // Calling this too frequently makes the notifications UI unresponsive, so
  // throttle to only cases where there is a visible change.
  void _updateElapsed(Timer timer) async {
    if (_progress.state != PracticeState.playing) {
      return;
    }
    String elapsed = DurationFormatter.format(_stopwatch.elapsed);
    if (elapsed == _progress.elapsed) {
      return;
    }
    _updateMediaItem();
  }

  Future<void> _updateMediaItem() async {
    _progress.elapsed = DurationFormatter.format(_stopwatch.elapsed);
    await AudioServiceBackground.setMediaItem(
        PracticeBackground.getMediaItemFromProgress(_progress));
  }
}
