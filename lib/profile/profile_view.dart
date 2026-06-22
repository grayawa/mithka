//
//  profile_view.dart
//
//  The "我" side menu (slides in from the left, ~88% width). Redesigned to match
//  QQ's drawer: an azure avatar banner → an edit-profile card → a vertical list
//  of rows (相册 / 收藏 / 文件 / 外观 / 二维码) → account switcher → a bottom bar
//  (设置 · 夜间模式). Backed by real TDLib via ProfileViewModel + AccountStore.
//

import 'dart:io';

import 'package:flutter/material.dart';
import '../components/toast.dart';
import 'package:provider/provider.dart';

import '../auth/account_store.dart';
import '../auth/auth_manager.dart';
import '../chat/chat_view.dart';
import '../chat/custom_emoji.dart';
import '../components/drawer_controller.dart' as dc;
import '../components/photo_avatar.dart';
import '../components/sf_symbols.dart';
import '../components/ui_components.dart';
import '../chat/shared_media_view.dart';
import '../settings/appearance_view.dart';
import '../settings/edit_profile_view.dart';
import '../settings/settings_view.dart';
import 'my_album_view.dart';
import '../tdlib/json_helpers.dart';
import '../tdlib/td_client.dart';
import '../tdlib/td_models.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import 'qr_code_view.dart';

class ProfileViewModel extends ChangeNotifier {
  CurrentUser? user;
  int? savedChatId;
  bool _loaded = false;

  void onAppear() {
    if (_loaded) return;
    _loaded = true;
    _getMe();
  }

  Future<void> _getMe() async {
    try {
      final me = await TdClient.shared.query({'@type': 'getMe'});
      final id = me.int64('id') ?? 0;
      user = CurrentUser(
        id: id,
        name: TDParse.userName(me),
        phoneNumber: TDParse.formatPhone(me.str('phone_number')),
        username: me.obj('usernames')?.str('editable_username'),
        photo: TDParse.smallPhoto(me.obj('profile_photo')),
        emojiStatusId: me.obj('emoji_status')?.int64('custom_emoji_id') ?? 0,
        isPremium: me.boolean('is_premium') ?? false,
      );
      notifyListeners();
      final chat = await TdClient.shared.query({
        '@type': 'createPrivateChat',
        'user_id': id,
        'force': false,
      });
      savedChatId = chat.int64('id') ?? id;
      notifyListeners();
    } catch (_) {}
  }

  /// Default emoji-status suggestions (custom_emoji_ids), resolved on demand
  /// for the status picker.
  Future<List<int>> statusOptions() async {
    final ids = <int>[];
    for (final type in const [
      'getThemedEmojiStatuses',
      'getDefaultEmojiStatuses',
    ]) {
      try {
        final res = await TdClient.shared.query({'@type': type});
        // Newer TDLib: { emoji_statuses: [emojiStatusTypeCustomEmoji{custom_emoji_id}] };
        // older: { custom_emoji_ids: [int64] }.
        for (final s
            in res.objects('emoji_statuses') ??
                const <Map<String, dynamic>>[]) {
          final id =
              s.int64('custom_emoji_id') ??
              s.obj('type')?.int64('custom_emoji_id');
          if (id != null && id != 0) ids.add(id);
        }
        for (final id in res.int64Array('custom_emoji_ids') ?? const <int>[]) {
          if (id != 0) ids.add(id);
        }
      } catch (_) {}
      if (ids.isNotEmpty) break;
    }
    return ids.toSet().toList();
  }

  /// Sets (id != 0) or clears (id == 0) the current user's emoji status.
  Future<bool> setEmojiStatus(int id) async {
    try {
      await TdClient.shared.query({
        '@type': 'setEmojiStatus',
        'emoji_status': id == 0
            ? null
            : {
                '@type': 'emojiStatus',
                'custom_emoji_id': id,
                'expiration_date': 0,
              },
      });
      user?.emojiStatusId = id;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }
}

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _vm = ProfileViewModel();

  @override
  void initState() {
    super.initState();
    _vm.addListener(() {
      if (mounted) setState(() {});
    });
    _vm.onAppear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AccountStore>().refresh();
    });
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  NavigatorState get _root => Navigator.of(context, rootNavigator: true);

  void _openSaved(String title) {
    final cid = _vm.savedChatId ?? _vm.user?.id ?? 0;
    _root.push(
      MaterialPageRoute(
        builder: (_) => ChatView(chatId: cid, title: title),
      ),
    );
  }

  /// QQ's status picker, mapped to Telegram's emoji status: a grid of suggested
  /// custom-emoji statuses (+ a clear option) → setEmojiStatus.
  void _openStatusPicker() {
    final optionsFuture = _vm.statusOptions();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        final c = sheetContext.colors;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '设置状态',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if ((_vm.user?.emojiStatusId ?? 0) != 0)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () async {
                          await _vm.setEmojiStatus(0);
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        },
                        child: Text(
                          '清除',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.tagRed,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: FutureBuilder<List<int>>(
                    future: optionsFuture,
                    builder: (context, snap) {
                      final ids = snap.data ?? const [];
                      if (snap.connectionState != ConnectionState.done) {
                        return const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator.adaptive(
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      }
                      if (ids.isEmpty) {
                        return Center(
                          child: Text(
                            '暂无可用状态（需要 Premium）',
                            style: TextStyle(
                              fontSize: 13,
                              color: c.textSecondary,
                            ),
                          ),
                        );
                      }
                      return GridView.count(
                        crossAxisCount: 6,
                        children: [
                          for (final id in ids)
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () async {
                                final ok = await _vm.setEmojiStatus(id);
                                if (!sheetContext.mounted) return;
                                Navigator.of(sheetContext).pop();
                                if (!ok && mounted) {
                                  showToast(context, '设置状态失败（需要 Premium）');
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(5),
                                child: CustomEmojiView(
                                  id: id,
                                  size: 34,
                                  color: c.textPrimary,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      color: c.groupedBackground,
      child: Column(
        children: [
          _banner(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              children: [
                _editCard(),
                const SizedBox(height: 12),
                _rowsCard(),
                const SizedBox(height: 12),
                _accountsCard(),
              ],
            ),
          ),
          _bottomBar(),
        ],
      ),
    );
  }

  // MARK: - Azure avatar banner

  Widget _banner() {
    final user = _vm.user;
    final username = (user?.username?.isNotEmpty ?? false)
        ? '@${user!.username}'
        : (user?.phoneNumber ?? '');
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: BoxDecoration(gradient: AppTheme.brandGradient),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top controls: QR + close.
            Row(
              children: [
                const Spacer(),
                GestureDetector(
                  onTap: () => _root.push(
                    MaterialPageRoute(
                      builder: (_) => QRCodeView(name: user?.name ?? '我'),
                    ),
                  ),
                  child: Icon(sfIcon('qrcode'), size: 22, color: Colors.white),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => context.read<dc.DrawerController>().close(),
                  child: Icon(sfIcon('xmark'), size: 22, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: PhotoAvatar(
                    title: user?.name ?? '我',
                    photo: user?.photo,
                    size: 64,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              user?.name ?? '加载中…',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (user?.isPremium ?? false) ...[
                            const SizedBox(width: 6),
                            const _VipBadge(),
                          ],
                          if ((user?.emojiStatusId ?? 0) != 0) ...[
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: _openStatusPicker,
                              child: CustomEmojiView(
                                id: user!.emojiStatusId,
                                size: 24,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final premium = user?.isPremium ?? false;
                final hasStatus = (user?.emojiStatusId ?? 0) != 0;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: premium ? _openStatusPicker : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasStatus)
                          CustomEmojiView(
                            id: user!.emojiStatusId,
                            size: 16,
                            color: Colors.white,
                          )
                        else
                          const Icon(
                            Icons.circle,
                            size: 8,
                            color: Color(0xFF1AC81A),
                          ),
                        const SizedBox(width: 5),
                        Text(
                          hasStatus ? '设置状态' : '在线',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                        if (premium) ...[
                          const SizedBox(width: 3),
                          Icon(
                            sfIcon('chevron.down'),
                            size: 10,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // MARK: - Edit-profile card

  Widget _editCard() {
    final c = context.colors;
    final user = _vm.user;
    return _card(
      onTap: () => _root.push(
        MaterialPageRoute(builder: (_) => const EditProfileView()),
      ),
      child: Row(
        children: [
          PhotoAvatar(title: user?.name ?? '我', photo: user?.photo, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name ?? '我',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '编辑资料，展示我的独特态度',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: c.textSecondary),
                ),
              ],
            ),
          ),
          Icon(sfIcon('chevron.right'), size: 16, color: c.textTertiary),
        ],
      ),
    );
  }

  // MARK: - QQ-style vertical rows

  Widget _rowsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _row('photo.fill', const Color(0xFFF5A623), '相册', () {
            _root.push(
              MaterialPageRoute(
                builder: (_) => MyAlbumView(userId: _vm.user?.id ?? 0),
              ),
            );
          }),
          const InsetDivider(leadingInset: 60),
          _row(
            'star.fill',
            const Color(0xFFFF9D2E),
            '收藏',
            () => _openSaved('收藏'),
          ),
          const InsetDivider(leadingInset: 60),
          _row('folder.fill', const Color(0xFF3C8CF0), '文件', () {
            final cid = _vm.savedChatId ?? _vm.user?.id ?? 0;
            _root.push(
              MaterialPageRoute(
                builder: (_) =>
                    SharedMediaView(chatId: cid, title: '文件', initialTab: 1),
              ),
            );
          }),
          const InsetDivider(leadingInset: 60),
          _row('sparkles', const Color(0xFF8E7BFF), '外观', () {
            _root.push(
              MaterialPageRoute(builder: (_) => const AppearanceView()),
            );
          }),
          const InsetDivider(leadingInset: 60),
          _row('qrcode', AppTheme.brand, '二维码名片', () {
            _root.push(
              MaterialPageRoute(
                builder: (_) => QRCodeView(name: _vm.user?.name ?? '我'),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _row(String icon, Color color, String label, VoidCallback onTap) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 54,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(sfIcon(icon), size: 17, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Text(label, style: TextStyle(fontSize: 16, color: c.textPrimary)),
              const Spacer(),
              Icon(sfIcon('chevron.right'), size: 16, color: c.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  // MARK: - Account switcher

  Widget _accountsCard() {
    final c = context.colors;
    final accounts = context.watch<AccountStore>();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final s in accounts.summaries) ...[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () =>
                  accounts.switchTo(s.slot, context.read<AuthManager>()),
              child: _accountRow(
                s.name,
                s.phone,
                s.avatarPath,
                selected: s.slot == accounts.activeSlot,
              ),
            ),
            const InsetDivider(leadingInset: 64),
          ],
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.read<AccountStore>().addAccount(
              context.read<AuthManager>(),
            ),
            child: SizedBox(
              height: 54,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.brand.withValues(alpha: 0.12),
                      ),
                      child: Icon(
                        sfIcon('plus'),
                        size: 18,
                        color: AppTheme.brand,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '添加账号',
                      style: TextStyle(fontSize: 15, color: AppTheme.brand),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountRow(
    String name,
    String phone,
    String? avatarPath, {
    required bool selected,
  }) {
    final c = context.colors;
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            if (avatarPath != null && avatarPath.isNotEmpty)
              ClipOval(
                child: Image.file(
                  File(avatarPath),
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                ),
              )
            else
              PhotoAvatar(title: name, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, color: c.textPrimary),
                  ),
                  if (phone.isNotEmpty)
                    Text(
                      phone,
                      style: TextStyle(fontSize: 12, color: c.textSecondary),
                    ),
                ],
              ),
            ),
            if (selected)
              Icon(sfIcon('checkmark'), size: 16, color: AppTheme.brand),
          ],
        ),
      ),
    );
  }

  // MARK: - Bottom bar (设置 · 夜间模式)

  Widget _bottomBar() {
    final c = context.colors;
    final theme = context.watch<ThemeController>();
    final isDark = theme.mode == AppearanceMode.dark;
    return Container(
      decoration: BoxDecoration(
        color: c.navBar,
        border: Border(top: BorderSide(color: c.divider, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _root.push(
                    MaterialPageRoute(builder: (_) => const SettingsView()),
                  ),
                  child: _barItem('gearshape.fill', '设置'),
                ),
              ),
              Container(width: 0.5, height: 28, color: c.divider),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => theme.mode = isDark
                      ? AppearanceMode.system
                      : AppearanceMode.dark,
                  child: _barItem(
                    isDark ? 'sun.max.fill' : 'moon.fill',
                    isDark ? '日间' : '夜间',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barItem(String icon, String label) {
    final c = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(sfIcon(icon), size: 20, color: c.textSecondary),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 15, color: c.textPrimary)),
      ],
    );
  }

  Widget _card({required Widget child, VoidCallback? onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      ),
    );
  }
}

/// QQ-style VIP indicator shown next to a Telegram Premium user's name: the QQ
/// penguin mascot followed by a gold "VIP" badge.
class _VipBadge extends StatelessWidget {
  const _VipBadge();

  static const _ink = Color(0xFF7A4A00); // dark-gold ink for glyph + lettering

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE08A), Color(0xFFF5A623)],
        ),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Penguin silhouette tinted to the same ink as the VIP lettering.
          const ColorFiltered(
            colorFilter: ColorFilter.mode(_ink, BlendMode.srcATop),
            child: Text('🐧', style: TextStyle(fontSize: 13, height: 1.1)),
          ),
          const SizedBox(width: 2),
          const Text(
            'VIP',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: _ink,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
