//
//  profile_detail_view.dart
//
//  A user's profile page (个人资料), reached by tapping a contact — QQ-style: a
//  blurred profile-photo cover with the avatar overlapping the bottom-left, name
//  beside it, secondary action tiles, info rows (个性签名 / 电话), and a fixed
//  bottom bar (音视频通话 / 发消息). Backed by TDLib.
//

import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../components/toast.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../call/call_manager.dart';
import '../chat/chat_search_view.dart';
import '../chat/chat_view.dart';
import '../chat/full_image_viewer.dart';
import '../chat/shared_media_view.dart';
import '../components/icon_grid.dart';
import '../components/photo_avatar.dart';
import '../components/sf_symbols.dart';
import '../components/ui_components.dart';
import '../tdlib/json_helpers.dart';
import '../tdlib/td_client.dart';
import '../tdlib/td_models.dart';
import '../theme/app_theme.dart';

class ProfileDetailView extends StatefulWidget {
  const ProfileDetailView({super.key, required this.userId, this.name = ''});
  final int userId;
  final String name;

  @override
  State<ProfileDetailView> createState() => _ProfileDetailViewState();
}

class _ProfileDetailViewState extends State<ProfileDetailView> {
  String _name = '';
  String? _username;
  String _phone = '';
  String _bio = '';
  TdFileRef? _photo;
  bool _isOnline = false;
  String _statusText = '';
  int? _chatId;
  bool _muted = false;
  bool _blocked = false;
  List<TdFileRef> _photos = []; // 精选照片 — profile-photo history
  String _birthday = '';
  String _location = '';

  @override
  void initState() {
    super.initState();
    _name = widget.name;
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await TdClient.shared.query({
        '@type': 'getUser',
        'user_id': widget.userId,
      });
      if (mounted) {
        setState(() {
          _name = TDParse.userName(user);
          _username = user.obj('usernames')?.str('editable_username');
          _phone = TDParse.formatPhone(user.str('phone_number'));
          _photo = TDParse.smallPhoto(user.obj('profile_photo'));
          _isOnline = TDParse.isUserOnline(user);
          _statusText = TDParse.userStatus(user);
        });
      }
    } catch (_) {}
    try {
      final full = await TdClient.shared.query({
        '@type': 'getUserFullInfo',
        'user_id': widget.userId,
      });
      if (mounted) {
        setState(() {
          _bio = full.obj('bio')?.str('text') ?? '';
          _birthday = _formatBirthday(full.obj('birthdate'));
          _location =
              full.obj('business_info')?.obj('location')?.str('address') ?? '';
        });
      }
    } catch (_) {}
    try {
      final res = await TdClient.shared.query({
        '@type': 'getUserProfilePhotos',
        'user_id': widget.userId,
        'offset': 0,
        'limit': 12,
      });
      final raw = res.objects('photos') ?? const <Map<String, dynamic>>[];
      final refs = <TdFileRef>[];
      for (final p in raw) {
        final sizes = p.objects('sizes') ?? const <Map<String, dynamic>>[];
        if (sizes.isEmpty) continue;
        final best = sizes.reduce(
          (a, b) =>
              (a.integer('width') ?? 0) >= (b.integer('width') ?? 0) ? a : b,
        );
        final ref = TDParse.fileRef(best.obj('photo'));
        if (ref != null) refs.add(ref);
      }
      if (mounted) setState(() => _photos = refs);
    } catch (_) {}
    try {
      final chat = await TdClient.shared.query({
        '@type': 'createPrivateChat',
        'user_id': widget.userId,
        'force': false,
      });
      if (mounted) {
        setState(() {
          _chatId = chat.int64('id');
          _muted =
              (chat.obj('notification_settings')?.integer('mute_for') ?? 0) > 0;
        });
      }
    } catch (_) {}
    try {
      final res = await TdClient.shared.query({
        '@type': 'getBlockedMessageSenders',
        'block_list': {'@type': 'blockListMain'},
        'offset': 0,
        'limit': 100,
      });
      final blocked = (res.objects('senders') ?? const <Map<String, dynamic>>[])
          .any((s) => s.int64('user_id') == widget.userId);
      if (mounted) setState(() => _blocked = blocked);
    } catch (_) {}
  }

  // MARK: - Actions

  void _call(bool isVideo) =>
      context.read<CallManager>().startCall(widget.userId, isVideo);

  void _callMenu() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheet) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheet).pop();
              _call(false);
            },
            child: const Text('语音通话'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheet).pop();
              _call(true);
            },
            child: const Text('视频通话'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(sheet).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _openChat() {
    final cid = _chatId;
    if (cid == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatView(chatId: cid, title: _name),
      ),
    );
  }

  void _openSearch() {
    final cid = _chatId;
    if (cid == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatSearchView(chatId: cid, title: _name),
      ),
    );
  }

  void _openMedia() {
    final cid = _chatId;
    if (cid == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SharedMediaView(chatId: cid, title: _name),
      ),
    );
  }

  void _shareCard() {
    final link = (_username?.isNotEmpty ?? false)
        ? 'https://t.me/$_username'
        : 'tg://user?id=${widget.userId}';
    Clipboard.setData(ClipboardData(text: link));
    showToast(context, '已复制名片链接');
  }

  Future<void> _toggleMute() async {
    final cid = _chatId;
    if (cid == null) return;
    final next = !_muted;
    setState(() => _muted = next);
    try {
      await TdClient.shared.query({
        '@type': 'setChatNotificationSettings',
        'chat_id': cid,
        'notification_settings': {
          '@type': 'chatNotificationSettings',
          'use_default_mute_for': false,
          'mute_for': next ? 365 * 24 * 60 * 60 : 0,
        },
      });
    } catch (_) {
      if (mounted) setState(() => _muted = !next);
    }
  }

  Future<void> _toggleBlock() async {
    final next = !_blocked;
    setState(() => _blocked = next);
    try {
      await TdClient.shared.query({
        '@type': 'setMessageSenderBlockList',
        'sender_id': {'@type': 'messageSenderUser', 'user_id': widget.userId},
        'block_list': next ? {'@type': 'blockListMain'} : null,
      });
    } catch (_) {
      if (mounted) setState(() => _blocked = !next);
    }
  }

  // MARK: - Build

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.groupedBackground,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 20),
              children: [
                _header(),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _secondaryActions(),
                ),
                if (_photos.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _photosCard(),
                  ),
                ],
                if (_infoRows.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _infoCard(),
                  ),
                ],
              ],
            ),
          ),
          _bottomBar(),
        ],
      ),
    );
  }

  List<(String, String)> get _infoRows => [
    if (_bio.isNotEmpty) ('个性签名', _bio),
    if (_birthday.isNotEmpty) ('生日', _birthday),
    if (_location.isNotEmpty) ('所在地', _location),
    if (_phone.isNotEmpty) ('电话', _phone),
  ];

  String _formatBirthday(Map<String, dynamic>? bd) {
    if (bd == null) return '';
    final d = bd.integer('day') ?? 0;
    final m = bd.integer('month') ?? 0;
    final y = bd.integer('year') ?? 0;
    if (d == 0 || m == 0) return '';
    final md = '$m月$d日';
    return y > 0 ? '$y年$md' : md;
  }

  /// Cover (blurred profile photo, gradient fallback) + overlapping avatar +
  /// name/username/status.
  Widget _header() {
    final c = context.colors;
    final top = MediaQuery.of(context).padding.top;
    final bannerH = top + 96;
    final status = _isOnline ? '在线' : _statusText;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _cover(bannerH.toDouble()),
            Container(
              color: c.card,
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 88),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _name.isEmpty ? '?' : _name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                            color: c.textPrimary,
                          ),
                        ),
                        if (_username?.isNotEmpty ?? false) ...[
                          const SizedBox(height: 3),
                          Text(
                            '@$_username',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (status.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (_isOnline) ...[
                          const Icon(
                            Icons.circle,
                            size: 7,
                            color: Color(0xFF1AC81A),
                          ),
                          const SizedBox(width: 5),
                        ],
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: 13,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        Positioned(
          top: top + 4,
          left: 6,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(
                Icons.arrow_back_ios_new,
                size: 20,
                color: Colors.white,
              ),
            ),
          ),
        ),
        Positioned(
          top: bannerH - 40,
          left: 20,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: c.card, width: 3),
            ),
            child: PhotoAvatar(
              title: _name.isEmpty ? '?' : _name,
              photo: _photo,
              size: 76,
            ),
          ),
        ),
      ],
    );
  }

  Widget _cover(double h) {
    if (_photo != null) {
      return SizedBox(
        height: h,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: TDImage(photo: _photo, cornerRadius: 0, fit: BoxFit.cover),
            ),
            Container(color: Colors.black.withValues(alpha: 0.18)),
          ],
        ),
      );
    }
    return Container(
      height: h,
      decoration: BoxDecoration(gradient: AppTheme.brandGradient),
    );
  }

  Widget _secondaryActions() {
    final c = context.colors;
    final actions = <(String, String, VoidCallback)>[
      ('person.crop.circle', '名片', _shareCard),
      ('magnifyingglass', '查找记录', _openSearch),
      ('folder.fill', '聊天文件', _openMedia),
      (
        _muted ? 'bell.slash.fill' : 'bell.fill',
        _muted ? '已免打扰' : '免打扰',
        _toggleMute,
      ),
      (
        _blocked ? 'lock.fill' : 'nosign',
        _blocked ? '已拉黑' : '拉黑',
        _toggleBlock,
      ),
    ];
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: IconGrid(
        perRow: 5,
        children: [for (final a in actions) _actionTile(a.$1, a.$2, a.$3)],
      ),
    );
  }

  Widget _actionTile(String icon, String label, VoidCallback onTap) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.brand.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(sfIcon(icon), size: 21, color: AppTheme.brand),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: c.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.navBar,
        border: Border(top: BorderSide(color: c.divider, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: _barButton(
                  'phone.fill',
                  '音视频通话',
                  primary: false,
                  onTap: _callMenu,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _barButton(
                  'message.fill',
                  '发消息',
                  primary: true,
                  onTap: _openChat,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barButton(
    String icon,
    String label, {
    required bool primary,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: primary
              ? AppTheme.brand
              : AppTheme.brand.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              sfIcon(icon),
              size: 18,
              color: primary ? Colors.white : AppTheme.brand,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: primary ? Colors.white : AppTheme.brand,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 精选照片 — a horizontal strip of the user's profile-photo history.
  Widget _photosCard() {
    final c = context.colors;
    final count = _photos.length;
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '精选照片',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: c.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '$count',
                style: TextStyle(fontSize: 13, color: c.textSecondary),
              ),
              const SizedBox(width: 4),
              Icon(sfIcon('chevron.right'), size: 14, color: c.textTertiary),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 78,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: count,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => _photoTile(i),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoTile(int i) {
    const s = 78.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => FullImageViewer(items: _photos, startIndex: i),
        ),
      ),
      child: SizedBox(
        width: s,
        height: s,
        child: TDImage(photo: _photos[i], cornerRadius: 10, fit: BoxFit.cover),
      ),
    );
  }

  Widget _infoCard() {
    final c = context.colors;
    final rows = _infoRows;
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rows[i].$1,
                    style: TextStyle(fontSize: 16, color: c.textPrimary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      rows[i].$2,
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 15, color: c.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            if (i < rows.length - 1) const InsetDivider(leadingInset: 16),
          ],
        ],
      ),
    );
  }
}
