//
//  call_media_engine.dart
//
//  Abstraction over the real-time media transport for a 1:1 call. TDLib handles
//  signaling (call setup, key exchange, emoji verification) and hands us a
//  `callStateReady` payload; the media engine is what actually carries audio /
//  video over the negotiated relay servers using the agreed encryption key.
//
//  TDLib itself does NOT ship a media engine — that is the job of tgcalls (the
//  WebRTC-based library Telegram apps embed). Until a tgcalls library is
//  vendored into this project, `NoopCallMediaEngine` stands in: signaling works
//  end to end (you can ring, accept, see the verification emojis, hang up), but
//  no audio flows. Port of the Swift `CallMediaEngine`.
//

import 'package:flutter/foundation.dart';

/// Everything a media engine needs to bring up a call, distilled from TDLib's
/// `callStateReady`. Built by `CallManager` and passed to `engine.start`.
class CallReadyConfig {
  CallReadyConfig({
    required this.servers,
    required this.encryptionKey,
    required this.config,
    required this.customParameters,
    required this.libraryVersions,
    required this.isOutgoing,
    required this.isVideo,
  });
  final List<Map<String, dynamic>> servers;
  final Uint8List encryptionKey;
  final String config;
  final String customParameters;
  final List<String> libraryVersions;
  final bool isOutgoing;
  final bool isVideo;
}

/// The media transport for an active call. A real implementation owns the
/// audio session, the WebRTC peer connection, and the camera/mic capture.
abstract class CallMediaEngine {
  void start(CallReadyConfig config);
  void stop();
  void setMuted(bool muted);
  void setSpeaker(bool speaker);
  void setVideoEnabled(bool enabled);
}

/// A do-nothing media engine that only logs. Lets the call signaling flow run
/// end to end without any audio transport.
///
/// This is the single seam where a real tgcalls / WebRTC engine plugs in: once a
/// tgcalls binding exists, implement `CallMediaEngine` on top of it (consuming
/// the `CallReadyConfig` that `CallManager` builds from `callStateReady`) and
/// swap `NoopCallMediaEngine` for it as the default engine in `CallManager`.
class NoopCallMediaEngine implements CallMediaEngine {
  @override
  void start(CallReadyConfig config) {
    debugPrint(
      '📞 [media] start outgoing=${config.isOutgoing} '
      'video=${config.isVideo} servers=${config.servers.length} '
      'keyBytes=${config.encryptionKey.length} '
      'versions=${config.libraryVersions.join(",")}',
    );
  }

  @override
  void stop() => debugPrint('📞 [media] stop');

  @override
  void setMuted(bool muted) => debugPrint('📞 [media] setMuted $muted');

  @override
  void setSpeaker(bool speaker) => debugPrint('📞 [media] setSpeaker $speaker');

  @override
  void setVideoEnabled(bool enabled) =>
      debugPrint('📞 [media] setVideoEnabled $enabled');
}
