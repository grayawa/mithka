//
//  voice_audio.dart
//
//  Voice-note playback for the bubble's play/pause + draggable scrubber.
//  Telegram voice notes are Opus-in-OGG (flutter_sound bundles libopus so it
//  plays on iOS too). Resolves the file via TDFileCenter, plays it, exposes
//  position/duration for the seek bar, supports pause/resume and drag-to-seek.
//

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';

import '../tdlib/td_image_loader.dart';
import '../tdlib/td_models.dart';

class VoicePlayer extends ChangeNotifier {
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  bool isPlaying = false;
  bool isLoading = false;
  Duration position = Duration.zero;
  Duration total = Duration.zero;

  int? _fileId;
  String? _path;
  bool _opened = false;
  bool _disposed = false;
  StreamSubscription<PlaybackDisposition>? _progress;

  /// True when this player is the one bound to [file] (playing or paused).
  bool isActive(TdFileRef? file) => file != null && _fileId == file.id;

  Future<void> _ensureOpen() async {
    if (_opened) return;
    await _player.openPlayer();
    await _player.setSubscriptionDuration(const Duration(milliseconds: 60));
    _opened = true;
  }

  Future<void> toggle(TdFileRef? file) async {
    if (file == null) return;

    // Same note already loaded → pause / resume.
    if (_fileId == file.id && (_player.isPlaying || _player.isPaused)) {
      if (_player.isPlaying) {
        await _player.pausePlayer();
        isPlaying = false;
      } else {
        await _player.resumePlayer();
        isPlaying = true;
      }
      notifyListeners();
      return;
    }

    if (_player.isPlaying || _player.isPaused) {
      try {
        await _player.stopPlayer();
      } catch (_) {}
    }

    isLoading = true;
    notifyListeners();
    final path = await TdFileCenter.shared.path(file.id);
    isLoading = false;
    if (path == null || _disposed) {
      notifyListeners();
      return;
    }
    _fileId = file.id;
    _path = path;
    await _start(0);
  }

  Future<void> _start(int fromMs) async {
    try {
      await _ensureOpen();
      _progress?.cancel();
      _progress = _player.onProgress?.listen((e) {
        position = e.position;
        if (e.duration.inMilliseconds > 0) total = e.duration;
        notifyListeners();
      });
      isPlaying = true;
      position = Duration(milliseconds: fromMs);
      notifyListeners();
      await _player.startPlayer(
        fromURI: _path,
        codec: Codec.opusOGG,
        whenFinished: () {
          isPlaying = false;
          position = Duration.zero;
          notifyListeners();
        },
      );
      if (fromMs > 0) {
        await _player.seekToPlayer(Duration(milliseconds: fromMs));
      }
    } catch (_) {
      isPlaying = false;
      notifyListeners();
    }
  }

  /// Drag-to-seek. [fraction] in 0..1; [fallbackSeconds] is the note's known
  /// duration (used before playback has reported a duration).
  Future<void> seekFraction(double fraction, int fallbackSeconds) async {
    final f = fraction.clamp(0.0, 1.0);
    final dur = total.inMilliseconds > 0
        ? total
        : Duration(seconds: fallbackSeconds);
    final target = Duration(milliseconds: (dur.inMilliseconds * f).round());
    position = target;
    notifyListeners();
    if (_opened && (_player.isPlaying || _player.isPaused)) {
      try {
        await _player.seekToPlayer(target);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _progress?.cancel();
    if (_opened) _player.closePlayer();
    super.dispose();
  }
}
