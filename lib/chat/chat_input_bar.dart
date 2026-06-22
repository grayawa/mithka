//
//  chat_input_bar.dart
//
//  Reference-style composer: rounded text field + inline send, a gray icon
//  strip, and togglable panels (function grid + emoji + sticker + voice). Sends
//  text, emoji, stickers, photos/camera, files, location, polls and voice notes
//  through the view model. Port of the Swift `ChatInputBar`.
//

import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../components/toast.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../components/photo_avatar.dart';
import '../components/icon_grid.dart';
import '../components/sf_symbols.dart';
import '../theme/app_theme.dart';
import '../tdlib/td_models.dart';
import 'chat_view_model.dart';
import 'custom_emoji.dart';
import 'emoji_catalog.dart';
import 'emoji_store.dart';
import 'emoji_text_controller.dart';
import 'location_picker_view.dart';
import 'poll_composer_view.dart';
import 'sticker_store.dart';

enum _Panel { none, function, emoji, sticker, voice }

class ChatInputBar extends StatefulWidget {
  const ChatInputBar({super.key, required this.vm, required this.onStartCall});
  final ChatViewModel vm;
  final void Function(bool isVideo) onStartCall;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _controller = EmojiTextEditingController();
  final _focus = FocusNode();
  _Panel _panel = _Panel.none;
  String _emojiTab = 'standard'; // 'standard' or a custom-emoji pack id
  int? _stickerPack; // active sticker pack id

  // Voice recording (flutter_sound, Opus).
  FlutterSoundRecorder? _recorder;
  bool _recording = false;
  bool _recordCancelled = false;
  double _elapsed = 0;
  double _pressStartY = 0;
  Timer? _recTimer;
  String? _recPath;

  ChatViewModel get vm => widget.vm;

  @override
  void initState() {
    super.initState();
    _controller.text = vm.draft;
    _controller.addListener(_onTextChanged);
    _focus.addListener(() {
      if (_focus.hasFocus && _panel != _Panel.none) {
        setState(() => _panel = _Panel.none);
      }
    });
    vm.addListener(_syncFromVm);
    EmojiStore.shared.addListener(_onStore);
    StickerStore.shared.addListener(_onStore);
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  DateTime? _lastTyping;
  void _onTextChanged() {
    vm.setDraft(_controller.text);
    final now = DateTime.now();
    if (_controller.text.isNotEmpty &&
        (_lastTyping == null || now.difference(_lastTyping!).inSeconds >= 4)) {
      _lastTyping = now;
      vm.sendTyping();
    }
  }

  void _syncFromVm() {
    if (vm.draft != _controller.text) {
      _controller.value = TextEditingValue(
        text: vm.draft,
        selection: TextSelection.collapsed(offset: vm.draft.length),
      );
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    vm.removeListener(_syncFromVm);
    EmojiStore.shared.removeListener(_onStore);
    StickerStore.shared.removeListener(_onStore);
    _controller.dispose();
    _focus.dispose();
    _recTimer?.cancel();
    _recorder?.closeRecorder();
    super.dispose();
  }

  // MARK: - Voice recording

  void _toggleVoice() {
    _focus.unfocus();
    setState(
      () => _panel = _panel == _Panel.voice ? _Panel.none : _Panel.voice,
    );
    if (_panel == _Panel.voice) _prepareRecorder();
  }

  Future<void> _prepareRecorder() async {
    if (_recorder != null) return;
    final status = await Permission.microphone.request();
    if (!status.isGranted) return;
    final r = FlutterSoundRecorder();
    await r.openRecorder();
    _recorder = r;
  }

  Future<void> _startRec() async {
    final r = _recorder;
    if (r == null || _recording) return;
    final dir = await getTemporaryDirectory();
    _recPath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.ogg';
    _recordCancelled = false;
    _elapsed = 0;
    await r.startRecorder(
      toFile: _recPath,
      codec: Codec.opusOGG,
      sampleRate: 48000,
      numChannels: 1,
    );
    if (!mounted) return;
    setState(() => _recording = true);
    _recTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() => _elapsed += 0.1);
    });
  }

  Future<void> _stopRec() async {
    final r = _recorder;
    _recTimer?.cancel();
    _recTimer = null;
    if (r == null || !_recording) return;
    final secs = _elapsed.round();
    final cancelled = _recordCancelled;
    String? url;
    try {
      url = await r.stopRecorder();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _recording = false);
    if (cancelled || secs < 1 || url == null) return;
    vm.sendVoice(url, secs);
    setState(() => _panel = _Panel.none);
  }

  static String _recTime(double seconds) {
    final s = seconds.floor();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  void _toggle(_Panel panel) {
    _focus.unfocus();
    setState(() => _panel = _panel == panel ? _Panel.none : panel);
  }

  void _pickFailed(String what) {
    setState(() => _panel = _Panel.none);
    showToast(context, '无法打开$what');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // When no panel is open, lift the bar above the keyboard by its inset; when
    // a panel IS open the keyboard is dismissed, so pin to the bottom (no gap).
    final keyboardInset = _panel == _Panel.none
        ? MediaQuery.of(context).viewInsets.bottom
        : 0.0;
    return Container(
      color: c.inputBarBackground,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (vm.replyTo != null) _replyBanner(vm.replyTo!),
            _inputRow(),
            _iconStrip(),
            if (_panel == _Panel.function) _functionPanel(),
            if (_panel == _Panel.emoji) _emojiPanel(),
            if (_panel == _Panel.sticker) _stickerPanel(),
            if (_panel == _Panel.voice) _voicePanel(),
          ],
        ),
      ),
    );
  }

  // MARK: - Reply banner

  Widget _replyBanner(ChatMessage m) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 8),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: c.searchFill,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _replyLine(m),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: c.textSecondary),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => vm.setReply(null),
              child: Icon(Icons.cancel, size: 18, color: c.textTertiary),
            ),
          ],
        ),
      ),
    );
  }

  String _replyLine(ChatMessage m) {
    final name = m.isOutgoing
        ? vm.meName
        : (m.senderName?.isNotEmpty ?? false)
        ? m.senderName!
        : vm.peerTitle;
    return '$name:${_replyPreview(m)}';
  }

  String _replyPreview(ChatMessage m) {
    if (m.document != null) return '[文件]${m.document!.fileName}';
    if (m.voice != null) return '[语音]';
    if (m.location != null) return '[位置]';
    if (m.animatedSticker != null) return '[动画表情]';
    if (m.image != null) return m.text.isEmpty ? '[图片]' : m.text;
    return m.text;
  }

  // MARK: - Input row

  Widget _inputRow() {
    final c = context.colors;
    final hasText = _controller.text.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: c.searchFill,
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                minLines: 1,
                maxLines: 4,
                style: TextStyle(fontSize: 16, color: c.textPrimary),
                decoration: const InputDecoration(
                  hintText: '发送消息…',
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
              ),
            ),
          ),
          if (hasText) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                final (text, entities) = _controller.toFormatted();
                vm.sendFormatted(text, entities);
                _controller.clear();
              },
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.brand,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  sfIcon('paperplane.fill'),
                  size: 17,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // MARK: - Icon strip

  Widget _iconStrip() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          _icon('mic.fill', _panel == _Panel.voice, _toggleVoice),
          _icon('photo', false, _pickPhotos),
          _icon('camera.fill', false, _takePhoto),
          _icon('square.grid.2x2.fill', _panel == _Panel.sticker, () {
            _toggle(_Panel.sticker);
            if (_panel == _Panel.sticker) StickerStore.shared.loadIfNeeded();
          }),
          _icon('face.smiling', _panel == _Panel.emoji, () {
            _toggle(_Panel.emoji);
            if (_panel == _Panel.emoji) EmojiStore.shared.loadIfNeeded();
          }),
          _icon(
            _panel != _Panel.none ? 'xmark' : 'plus.circle',
            _panel == _Panel.function,
            () => _toggle(_Panel.function),
          ),
        ],
      ),
    );
  }

  Widget _icon(String name, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Icon(
          sfIcon(name),
          size: 24,
          color: active ? AppTheme.brand : context.colors.textSecondary,
        ),
      ),
    );
  }

  // MARK: - Media pickers

  /// 图片: pick one or more photos/videos from the library and send each.
  Future<void> _pickPhotos() async {
    try {
      final media = await ImagePicker().pickMultipleMedia();
      for (final x in media) {
        final lower = x.name.toLowerCase();
        final isVideo =
            lower.endsWith('.mp4') ||
            lower.endsWith('.mov') ||
            lower.endsWith('.m4v');
        if (isVideo) {
          widget.vm.sendVideo(x.path);
        } else {
          widget.vm.sendPhoto(x.path);
        }
      }
    } catch (_) {
      _pickFailed('图片');
    }
  }

  /// 相机: capture a photo and send it.
  Future<void> _takePhoto() async {
    try {
      final shot = await ImagePicker().pickImage(source: ImageSource.camera);
      if (shot != null) widget.vm.sendPhoto(shot.path);
    } catch (_) {
      _pickFailed('相机');
    }
  }

  /// 文件: pick an arbitrary document and send it.
  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      final path = result?.files.single.path;
      if (path != null) widget.vm.sendDocument(path);
    } catch (_) {
      _pickFailed('文件');
    }
  }

  /// 位置: open a map picker centred on the GPS fix; send the chosen point.
  Future<void> _sendLocation() async {
    // Fallback centre when location is unavailable — user can pan to choose.
    var start = const LatLng(39.9087, 116.3975);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm != LocationPermission.denied &&
          perm != LocationPermission.deniedForever) {
        final pos = await Geolocator.getCurrentPosition();
        start = LatLng(pos.latitude, pos.longitude);
      }
    } catch (_) {}
    if (!mounted) return;
    final picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(builder: (_) => LocationPickerView(initial: start)),
    );
    if (picked != null) {
      widget.vm.sendLocation(picked.latitude, picked.longitude);
    }
  }

  /// 投票: collect a question + options and send a poll.
  Future<void> _createPoll() async {
    final result = await Navigator.of(context).push<(String, List<String>)>(
      MaterialPageRoute(builder: (_) => const PollComposerView()),
    );
    if (result == null) return;
    final (question, options) = result;
    if (question.isEmpty || options.length < 2) return;
    widget.vm.sendPoll(question, options);
  }

  // MARK: - Function panel

  Widget _functionPanel() {
    final items = [
      ('phone.fill', '语音通话', () => widget.onStartCall(false)),
      ('video.fill', '视频通话', () => widget.onStartCall(true)),
      ('location.fill', '位置', _sendLocation),
      ('folder.fill', '文件', _pickFile),
      ('square.grid.2x2.fill', '投票', _createPoll),
    ];
    final c = context.colors;
    return Container(
      width: double.infinity,
      color: c.panelBackground,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      child: IconGrid(
        perRow: 5,
        runSpacing: 14,
        children: [
          for (final item in items)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() => _panel = _Panel.none);
                item.$3();
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: c.card,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      sfIcon(item.$1),
                      size: 22,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: c.textSecondary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // MARK: - Emoji panel (standard catalog → inserts into the field)

  Widget _emojiPanel() {
    final c = context.colors;
    return Container(
      height: 286,
      color: c.panelBackground,
      child: Column(
        children: [
          Expanded(child: _emojiContent()),
          _emojiTabStrip(),
        ],
      ),
    );
  }

  Widget _emojiContent() {
    final store = EmojiStore.shared;
    if (_emojiTab != 'standard') {
      final id = int.tryParse(_emojiTab);
      CustomEmojiPack? pack;
      for (final p in store.customPacks) {
        if (p.id == id) {
          pack = p;
          break;
        }
      }
      if (pack != null) {
        return GridView.count(
          crossAxisCount: 8,
          padding: const EdgeInsets.all(12),
          children: [
            for (final item in pack.emoji)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _controller.insertCustomEmoji(
                  item.customEmojiId,
                  item.emoji,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: item.customEmojiId != 0
                      ? CustomEmojiView(
                          id: item.customEmojiId,
                          size: 34,
                          color: context.colors.textPrimary,
                        )
                      : const SizedBox(),
                ),
              ),
          ],
        );
      }
    }
    return ListView(
      padding: const EdgeInsets.only(top: 8),
      children: [
        for (final category in EmojiCatalog.categories) ...[
          Padding(
            padding: const EdgeInsets.only(left: 14, top: 6, bottom: 2),
            child: Text(
              category.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: context.colors.textSecondary,
              ),
            ),
          ),
          GridView.count(
            crossAxisCount: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final emoji in category.emojis)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _controller.insertText(emoji),
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 26)),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _emojiTabStrip() {
    final c = context.colors;
    final packs = EmojiStore.shared.customPacks;
    return Container(
      decoration: BoxDecoration(
        color: c.inputBarBackground,
        border: Border(top: BorderSide(color: c.divider, width: 0.5)),
      ),
      child: SizedBox(
        height: 50,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          children: [
            _emojiTabButton(
              selected: _emojiTab == 'standard',
              onTap: () => setState(() => _emojiTab = 'standard'),
              child: Icon(
                sfIcon('face.smiling'),
                size: 20,
                color: _emojiTab == 'standard'
                    ? AppTheme.brand
                    : c.textSecondary,
              ),
            ),
            for (final pack in packs)
              _emojiTabButton(
                selected: _emojiTab == pack.id.toString(),
                onTap: () => setState(() => _emojiTab = pack.id.toString()),
                child:
                    pack.emoji.isNotEmpty && pack.emoji.first.customEmojiId != 0
                    ? CustomEmojiView(
                        id: pack.emoji.first.customEmojiId,
                        size: 28,
                        color: c.textPrimary,
                      )
                    : (pack.cover != null
                          ? TDImage(photo: pack.cover, cornerRadius: 4)
                          : Text(
                              pack.title.isEmpty
                                  ? ''
                                  : pack.title.characters.first,
                              style: TextStyle(color: c.textPrimary),
                            )),
              ),
          ],
        ),
      ),
    );
  }

  Widget _emojiTabButton({
    required bool selected,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: selected ? context.colors.searchFill : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: SizedBox(width: 28, height: 28, child: Center(child: child)),
      ),
    );
  }

  Widget _voicePanel() {
    final c = context.colors;
    final granted = _recorder != null;
    final label = !granted
        ? '需要麦克风权限'
        : !_recording
        ? '按住说话'
        : (_recordCancelled ? '松开手指，取消发送' : '松开发送，上滑取消');
    return Container(
      height: 240,
      width: double.infinity,
      color: c.panelBackground,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: _recordCancelled ? AppTheme.tagRed : c.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Opacity(
            opacity: _recording ? 1 : 0.3,
            child: Text(
              _recTime(_elapsed),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: c.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Listener(
            onPointerDown: (e) {
              _pressStartY = e.position.dy;
              if (granted) _startRec();
            },
            onPointerMove: (e) {
              if (!_recording) return;
              final cancel = e.position.dy - _pressStartY < -70;
              if (cancel != _recordCancelled) {
                setState(() => _recordCancelled = cancel);
              }
            },
            onPointerUp: (_) {
              if (granted) {
                _stopRec();
              } else {
                _prepareRecorder();
              }
            },
            child: AnimatedScale(
              scale: _recording ? 1.12 : 1,
              duration: const Duration(milliseconds: 150),
              child: Container(
                width: 84,
                height: 84,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _recordCancelled ? AppTheme.tagRed : AppTheme.brand,
                  shape: BoxShape.circle,
                ),
                child: Icon(sfIcon('mic.fill'), size: 32, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stickerPanel() {
    final c = context.colors;
    return Container(
      height: 286,
      color: c.panelBackground,
      child: Column(
        children: [
          Expanded(child: _stickerContent()),
          _stickerTabStrip(),
        ],
      ),
    );
  }

  Widget _stickerContent() {
    final store = StickerStore.shared;
    final packs = store.packs;
    if (packs.isEmpty) {
      return Center(
        child: Text(
          store.loading ? '正在加载表情…' : '暂无表情',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
      );
    }
    final activeId = _stickerPack ?? packs.first.id;
    StickerPack? pack;
    for (final p in packs) {
      if (p.id == activeId) {
        pack = p;
        break;
      }
    }
    pack ??= packs.first;
    if (!pack.loaded && pack.stickers.isEmpty) {
      store.loadPack(pack.id);
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator.adaptive(strokeWidth: 2),
        ),
      );
    }
    return GridView.count(
      crossAxisCount: 4,
      padding: const EdgeInsets.all(12),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        for (final item in pack.stickers)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              widget.vm.sendSticker(item);
              setState(() => _panel = _Panel.none);
            },
            child: item.isAnimated && item.thumb == null
                ? Center(
                    child: Text(
                      item.emoji.isEmpty ? '🎴' : item.emoji,
                      style: const TextStyle(fontSize: 30),
                    ),
                  )
                : (item.thumb != null
                      ? TDImage(photo: item.thumb, cornerRadius: 6)
                      : Center(
                          child: Text(
                            item.emoji.isEmpty ? '🎴' : item.emoji,
                            style: const TextStyle(fontSize: 30),
                          ),
                        )),
          ),
      ],
    );
  }

  Widget _stickerTabStrip() {
    final c = context.colors;
    final packs = StickerStore.shared.packs;
    final activeId = _stickerPack ?? (packs.isNotEmpty ? packs.first.id : null);
    return Container(
      decoration: BoxDecoration(
        color: c.inputBarBackground,
        border: Border(top: BorderSide(color: c.divider, width: 0.5)),
      ),
      child: SizedBox(
        height: 50,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          children: [
            for (final pack in packs)
              _emojiTabButton(
                selected: pack.id == activeId,
                onTap: () {
                  setState(() => _stickerPack = pack.id);
                  StickerStore.shared.loadPack(pack.id);
                },
                child: pack.id == StickerStore.recentPackId
                    ? Icon(
                        sfIcon('clock'),
                        size: 20,
                        color: pack.id == activeId
                            ? AppTheme.brand
                            : c.textSecondary,
                      )
                    : (pack.cover != null
                          ? TDImage(photo: pack.cover, cornerRadius: 4)
                          : Text(
                              pack.title.isEmpty
                                  ? ''
                                  : pack.title.characters.first,
                              style: TextStyle(color: c.textPrimary),
                            )),
              ),
          ],
        ),
      ),
    );
  }
}
