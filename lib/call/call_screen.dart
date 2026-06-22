//
//  call_screen.dart
//
//  Full-screen 1:1 call HUD driven by a `CallManager`. A dark backdrop with the
//  peer's avatar, name, a phase-dependent status line (ringing / connecting /
//  mm:ss timer), the secure-connection emoji row once the call is active, and a
//  phase-appropriate control row. Port of the Swift `CallScreen`.
//

import 'dart:async';

import 'package:flutter/material.dart';

import '../components/photo_avatar.dart';
import '../components/sf_symbols.dart';
import 'call_manager.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key, required this.manager});
  final CallManager manager;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final call = widget.manager.call;
    return Material(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1C2530), Color(0xFF0B0F14)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: call == null
            ? const SizedBox.shrink()
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      const SizedBox(height: 60),
                      _peerHeader(call),
                      if (call.phase == CallPhase.active &&
                          call.emojis.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 28),
                          child: _secureRow(call.emojis),
                        ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 48),
                        child: _controls(call),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _peerHeader(ActiveCall call) {
    return Column(
      children: [
        PhotoAvatar(title: call.peerName, photo: call.peerPhoto, size: 110),
        const SizedBox(height: 16),
        Text(
          call.peerName.isEmpty ? ' ' : call.peerName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _statusLine(call),
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  String _statusLine(ActiveCall call) {
    switch (call.phase) {
      case CallPhase.requesting:
      case CallPhase.ringingOutgoing:
        return '正在呼叫…';
      case CallPhase.ringingIncoming:
        return '邀请你进行${call.isVideo ? "视频" : "语音"}通话';
      case CallPhase.exchangingKeys:
        return '连接中…';
      case CallPhase.active:
        return _durationText(call.startedAt);
      case CallPhase.ending:
        return '通话结束';
    }
  }

  String _durationText(DateTime? startedAt) {
    if (startedAt == null) return '00:00';
    final elapsed = DateTime.now().difference(startedAt).inSeconds;
    final e = elapsed < 0 ? 0 : elapsed;
    return '${(e ~/ 60).toString().padLeft(2, '0')}:${(e % 60).toString().padLeft(2, '0')}';
  }

  Widget _secureRow(List<String> emojis) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final e in emojis.take(4))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Text(e, style: const TextStyle(fontSize: 30)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '此通话已端到端加密',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controls(ActiveCall call) {
    if (call.phase == CallPhase.ringingIncoming) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _CallButton(
            icon: 'phone.down.fill',
            label: '挂断',
            background: const Color(0xFFFF3B30),
            onTap: widget.manager.end,
          ),
          const SizedBox(width: 80),
          _CallButton(
            icon: 'phone.fill',
            label: '接听',
            background: const Color(0xFF34C759),
            onTap: widget.manager.accept,
          ),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CallToggle(
          icon: 'mic.slash.fill',
          label: '静音',
          isOn: widget.manager.isMuted,
          onTap: widget.manager.toggleMute,
        ),
        const SizedBox(width: 28),
        _CallToggle(
          icon: 'speaker.wave.2.fill',
          label: '免提',
          isOn: widget.manager.isSpeaker,
          onTap: widget.manager.toggleSpeaker,
        ),
        if (call.isVideo) ...[
          const SizedBox(width: 28),
          _CallToggle(
            icon: 'video.fill',
            label: '摄像头',
            isOn: widget.manager.isVideoEnabled,
            onTap: widget.manager.toggleVideo,
          ),
        ],
        const SizedBox(width: 28),
        _CallButton(
          icon: 'phone.down.fill',
          label: '挂断',
          background: const Color(0xFFFF3B30),
          size: 64,
          onTap: widget.manager.end,
        ),
      ],
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({
    required this.icon,
    required this.label,
    required this.background,
    this.size = 70,
    required this.onTap,
  });
  final String icon;
  final String label;
  final Color background;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
            ),
            child: Icon(sfIcon(icon), size: size * 0.4, color: Colors.white),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

class _CallToggle extends StatelessWidget {
  const _CallToggle({
    required this.icon,
    required this.label,
    required this.isOn,
    required this.onTap,
  });
  final String icon;
  final String label;
  final bool isOn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isOn ? Colors.white : Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(
              sfIcon(icon),
              size: 24,
              color: isOn ? Colors.black : Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}
