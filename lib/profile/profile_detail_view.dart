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
      backgroundColor: c.card,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _header(),
                Container(height: 12, color: c.groupedBackground),
                _secondaryActions(),
                if (_photos.isNotEmpty) ...[
                  Container(height: 12, color: c.groupedBackground),
                  _photosCard(),
                ],
                if (_infoRows.isNotEmpty) ...[
                  Container(height: 12, color: c.groupedBackground),
                  _infoCard(),
                ],
                const SizedBox(height: 24),
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
    final top = MediaQuery.of(context).padding.top;
    final bannerH = top + 232;
    final status = _isOnline ? '在线' : _statusText;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(children: [_cover(bannerH.toDouble()), _identityPanel(status)]),
        Positioned(
          top: top + 4,
          left: 18,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                size: 20,
                color: Colors.white,
              ),
            ),
          ),
        ),
        Positioned(
          top: top + 4,
          right: 18,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _shareCard,
            child: Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: Icon(sfIcon('ellipsis'), size: 21, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _identityPanel(String status) {
    final c = context.colors;
    final idText = (_username?.isNotEmpty ?? false)
        ? 'ID：$_username'
        : (widget.userId > 0 ? 'ID：${widget.userId}' : '');
    final subtitle = [
      if (_phone.isNotEmpty) _phone,
      if (idText.isNotEmpty) idText,
    ].join('  ');
    return Container(
      transform: Matrix4.translationValues(0, -34, 0),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(32, 34, 32, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: c.card, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: PhotoAvatar(
                  title: _name.isEmpty ? '?' : _name,
                  photo: _photo,
                  size: 104,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name.isEmpty ? '?' : _name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 30,
                          height: 1.08,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (status.isNotEmpty) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                if (_isOnline) ...[
                  const Icon(Icons.circle, size: 8, color: Color(0xFF1AC81A)),
                  const SizedBox(width: 6),
                ],
                Text(
                  status,
                  style: TextStyle(fontSize: 14, color: c.textSecondary),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          _profileBadges(),
          if (_bio.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _bio,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 17, color: c.textPrimary),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(sfIcon('pencil'), size: 18, color: c.textTertiary),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _profileBadges() {
    final c = context.colors;
    return Row(
      children: [
        _badge('VIP', const Color(0xFF9CA0A6), Colors.white),
        const SizedBox(width: 8),
        const Text('👑 ☀️ 🌙 🌙 ⭐ ⭐ ⭐', style: TextStyle(fontSize: 22)),
        const Spacer(),
        Icon(sfIcon('chevron.right'), size: 18, color: c.textTertiary),
      ],
    );
  }

  Widget _badge(String text, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
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
    return Container(
      color: context.colors.card,
      child: Column(
        children: [
          _profileRow(
            'star',
            _username?.isNotEmpty ?? false ? '他的 QQ 空间' : 'QQ 空间',
            trailing: _username?.isNotEmpty ?? false ? '最近有更新' : null,
            showDot: _username?.isNotEmpty ?? false,
            onTap: _shareCard,
          ),
          const InsetDivider(leadingInset: 62),
          _profileRow('tshirt', '他正在用的装扮', trailing: '查看', onTap: _shareCard),
          const InsetDivider(leadingInset: 62),
          _profileRow(
            'magnifyingglass',
            '查找聊天记录',
            trailing: '图片、视频、文件等',
            onTap: _openSearch,
          ),
          const InsetDivider(leadingInset: 62),
          _profileRow(
            _muted ? 'bell.slash.fill' : 'bell.fill',
            _muted ? '已开启消息免打扰' : '消息免打扰',
            trailing: _muted ? '开启' : '关闭',
            onTap: _toggleMute,
          ),
          const InsetDivider(leadingInset: 62),
          _profileRow(
            _blocked ? 'lock.fill' : 'nosign',
            _blocked ? '已加入黑名单' : '加入黑名单',
            trailing: _blocked ? '开启' : '关闭',
            onTap: _toggleBlock,
          ),
        ],
      ),
    );
  }

  Widget _profileRow(
    String icon,
    String title, {
    String? trailing,
    bool showDot = false,
    required VoidCallback onTap,
  }) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 72,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 28, 0),
          child: Row(
            children: [
              Icon(sfIcon(icon), size: 27, color: c.textPrimary),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: c.textPrimary,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    trailing,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 15, color: c.textTertiary),
                  ),
                ),
              ],
              if (showDot) ...[
                const SizedBox(width: 9),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppTheme.tagRed,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
              const SizedBox(width: 10),
              Icon(sfIcon('chevron.right'), size: 18, color: c.textTertiary),
            ],
          ),
        ),
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
                child: _barButton('音视频通话', primary: false, onTap: _callMenu),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _barButton('送礼物', primary: false, onTap: _shareCard),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _barButton('发消息', primary: true, onTap: _openChat),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barButton(
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
