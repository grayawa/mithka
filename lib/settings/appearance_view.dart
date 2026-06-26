//
//  appearance_view.dart
//
//  外观: theme mode (跟随系统 / 浅色 / 深色) + tab-bar style (经典 / 系统), driving
//  ThemeController live. Mapped from QQ's 外观/装扮 entry.
//

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../components/ui_components.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import 'edit_field_view.dart';

class AppearanceView extends StatelessWidget {
  const AppearanceView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = context.watch<ThemeController>();
    return Scaffold(
      backgroundColor: c.groupedBackground,
      body: Column(
        children: [
          NavHeader(title: '外观', onBack: () => Navigator.of(context).pop()),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.section,
              ),
              children: [
                _label(context, '深色模式'),
                _card(context, [
                  for (final m in AppearanceMode.values)
                    _choiceRow(
                      context,
                      m.icon,
                      m.label,
                      theme.mode == m,
                      () => theme.mode = m,
                    ),
                ]),
                const SizedBox(height: AppSpacing.xl),
                _label(context, '大小'),
                _fontSizeCard(context, theme),
                const SizedBox(height: AppSpacing.xl),
                _label(context, '字体'),
                _card(context, [
                  _navigationRow(
                    context,
                    '字体',
                    theme.fontChoice.isCjk
                        ? theme.effectivePrimaryFontLabel
                        : '${theme.effectivePrimaryFontLabel} / ${theme.effectiveCjkFontLabel}',
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const FontSettingsView(),
                      ),
                    ),
                    icon: Icons.font_download_outlined,
                  ),
                ]),
                const SizedBox(height: AppSpacing.xl),
                _label(context, '主题颜色'),
                _colorCard(context, theme),
                const SizedBox(height: AppSpacing.xl),
                _label(context, '显示'),
                _card(context, [
                  _toggleRow(
                    context,
                    Icons.groups_rounded,
                    '群聊头像显示为圆形',
                    theme.circularGroupAvatars,
                    (v) => theme.circularGroupAvatars = v,
                  ),
                  _toggleRow(
                    context,
                    Icons.badge_outlined,
                    '显示成员头衔',
                    theme.showMemberTags,
                    (v) => theme.showMemberTags = v,
                  ),
                  _toggleRow(
                    context,
                    Icons.photo_library_outlined,
                    '合并连续图片消息',
                    theme.groupImageMessages,
                    (v) => theme.groupImageMessages = v,
                  ),
                  _toggleRow(
                    context,
                    Icons.circle_outlined,
                    '显示底部动态',
                    theme.showMomentsTab,
                    (v) => theme.showMomentsTab = v,
                  ),
                ]),
                const SizedBox(height: AppSpacing.xl),
                _label(context, '聊天界面'),
                _card(context, [
                  _toggleRow(
                    context,
                    Icons.palette_outlined,
                    '显示 Premium 名字颜色',
                    theme.showChatPremiumNameColors,
                    (v) => theme.showChatPremiumNameColors = v,
                  ),
                  _toggleRow(
                    context,
                    Icons.emoji_emotions_outlined,
                    '显示 Premium 状态表情',
                    theme.showChatPremiumEmojiStatus,
                    (v) => theme.showChatPremiumEmojiStatus = v,
                  ),
                  _toggleRow(
                    context,
                    Icons.edit_note_rounded,
                    '显示编辑和已读标记',
                    theme.showMessageMetaIndicators,
                    (v) => theme.showMessageMetaIndicators = v,
                  ),
                  _toggleRow(
                    context,
                    Icons.vertical_align_bottom_rounded,
                    '打开聊天显示最新消息',
                    theme.openChatsAtLatest,
                    (v) => theme.openChatsAtLatest = v,
                  ),
                ]),
                const SizedBox(height: AppSpacing.xl),
                _label(context, '聊天列表'),
                _card(context, [
                  _toggleRow(
                    context,
                    Icons.filter_list_rounded,
                    '顶部显示聊天分组筛选',
                    theme.showChatFolderFilter,
                    (v) => theme.showChatFolderFilter = v,
                  ),
                  _toggleRow(
                    context,
                    Icons.search_rounded,
                    '显示聊天列表搜索',
                    theme.showChatListSearch,
                    (v) => theme.showChatListSearch = v,
                  ),
                  _toggleRow(
                    context,
                    Icons.palette_outlined,
                    '显示 Premium 名字颜色',
                    theme.showPremiumNameColors,
                    (v) => theme.showPremiumNameColors = v,
                  ),
                  _toggleRow(
                    context,
                    Icons.emoji_emotions_outlined,
                    '显示 Premium 状态表情',
                    theme.showPremiumEmojiStatus,
                    (v) => theme.showPremiumEmojiStatus = v,
                  ),
                ]),
                const SizedBox(height: AppSpacing.xl),
                _label(context, '消息红点'),
                _card(context, [
                  for (final m in UnreadBadgeMode.values)
                    _choiceRow(
                      context,
                      m.icon,
                      m.label,
                      theme.unreadBadgeMode == m,
                      () => theme.unreadBadgeMode = m,
                    ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _palette = [
    Color(0xFF0099FF), // 蔚蓝 (default)
    Color(0xFF2DC100), // 绿
    Color(0xFF00C4B3), // 青
    Color(0xFF4A6CF7), // 靛蓝
    Color(0xFF8E7BFF), // 紫
    Color(0xFFFF5E7D), // 粉
    Color(0xFFFA5151), // 红
    Color(0xFFFF9500), // 橙
  ];

  Widget _colorCard(BuildContext context, ThemeController theme) {
    final c = context.colors;
    final selected = theme.brandColor.toARGB32();
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.xxl,
      ),
      child: Wrap(
        spacing: AppSpacing.xxl,
        runSpacing: AppSpacing.xl,
        children: [
          for (final color in _palette)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => theme.brandColor = color,
              child: Container(
                width: AppMetric.hitTarget - AppSpacing.xxs,
                height: AppMetric.hitTarget - AppSpacing.xxs,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: color.toARGB32() == selected
                      ? Border.all(
                          color: c.textPrimary,
                          width: AppMetric.selectedBorder,
                        )
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: color.toARGB32() == selected
                    ? const Icon(Icons.check, size: 18, color: Colors.white)
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  Widget _fontSizeCard(BuildContext context, ThemeController theme) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _scaleSlider(
            context,
            icon: Icons.text_fields_rounded,
            title: '字体大小',
            value: theme.fontScale,
            min: ThemeController.minFontScale,
            max: ThemeController.maxFontScale,
            divisions: 24,
            leading: Text(
              'A',
              style: TextStyle(
                fontSize: AppTextSize.footnote,
                color: c.textSecondary,
              ),
            ),
            trailing: Text(
              'A',
              style: TextStyle(
                fontSize: AppTextSize.largeDisplay,
                color: c.textPrimary,
              ),
            ),
            onChanged: (value) => theme.fontScale = value,
          ),
          const InsetDivider(leadingInset: 52),
          _scaleSlider(
            context,
            icon: Icons.space_dashboard_outlined,
            title: '界面大小',
            value: theme.interfaceScale,
            min: ThemeController.minInterfaceScale,
            max: ThemeController.maxInterfaceScale,
            divisions: 17,
            leading: Icon(
              Icons.crop_square,
              size: AppTextSize.body,
              color: c.textSecondary,
            ),
            trailing: Icon(
              Icons.crop_square,
              size: AppIconSize.add,
              color: c.textPrimary,
            ),
            onChanged: (value) => theme.interfaceScale = value,
          ),
        ],
      ),
    );
  }

  Widget _scaleSlider(
    BuildContext context, {
    required IconData icon,
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required Widget leading,
    required Widget trailing,
    required ValueChanged<double> onChanged,
  }) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.lg,
        AppSpacing.xxl,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.brand),
              const SizedBox(width: AppSpacing.xl),
              Text(
                title,
                style: TextStyle(
                  fontSize: AppTextSize.bodyLarge,
                  color: c.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${(value * 100).round()}%',
                style: TextStyle(
                  fontSize: AppTextSize.body,
                  color: c.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              SizedBox(
                width: AppIconSize.nav,
                child: Center(child: leading),
              ),
              Expanded(
                child: CupertinoSlider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: divisions,
                  activeColor: AppTheme.brand,
                  onChanged: onChanged,
                ),
              ),
              SizedBox(
                width: AppIconSize.toolbar + AppSpacing.xs,
                child: Center(child: trailing),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String t) => Padding(
    padding: const EdgeInsets.only(left: AppSpacing.xxl, bottom: AppSpacing.sm),
    child: Text(
      t,
      style: TextStyle(
        fontSize: AppTextSize.footnote,
        color: context.colors.textTertiary,
      ),
    ),
  );

  Widget _card(BuildContext context, List<Widget> rows) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i < rows.length - 1) const InsetDivider(leadingInset: 52),
          ],
        ],
      ),
    );
  }

  Widget _choiceRow(
    BuildContext context,
    IconData icon,
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: AppMetric.menuRowHeight + AppSpacing.xxs,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Row(
            children: [
              Icon(icon, size: AppIconSize.xl, color: AppTheme.brand),
              const SizedBox(width: AppSpacing.xl),
              Text(
                label,
                style: TextStyle(
                  fontSize: AppTextSize.bodyLarge,
                  color: c.textPrimary,
                ),
              ),
              const Spacer(),
              if (selected)
                Icon(Icons.check, size: AppIconSize.lg, color: AppTheme.brand),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggleRow(
    BuildContext context,
    IconData icon,
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    final c = context.colors;
    return SizedBox(
      height: AppMetric.menuRowHeight + AppSpacing.xxs,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: Row(
          children: [
            Icon(icon, size: AppIconSize.xl, color: AppTheme.brand),
            const SizedBox(width: AppSpacing.xl),
            Text(
              label,
              style: TextStyle(
                fontSize: AppTextSize.bodyLarge,
                color: c.textPrimary,
              ),
            ),
            const Spacer(),
            CupertinoSwitch(
              value: value,
              activeTrackColor: AppTheme.brand,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _navigationRow(
    BuildContext context,
    String label,
    String value,
    VoidCallback onTap, {
    IconData? icon,
  }) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: AppMetric.menuRowHeight + AppSpacing.xxs,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: AppIconSize.xl, color: AppTheme.brand),
                const SizedBox(width: AppSpacing.xl),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: AppTextSize.bodyLarge,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: AppTextSize.body,
                    color: c.textTertiary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.chevron_right_rounded,
                size: AppIconSize.lg,
                color: c.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FontSettingsView extends StatelessWidget {
  const FontSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = context.watch<ThemeController>();
    final showCjkFallback = !theme.fontChoice.isCjk;
    return Scaffold(
      backgroundColor: c.groupedBackground,
      body: Column(
        children: [
          NavHeader(title: '字体', onBack: () => Navigator.of(context).pop()),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.section,
              ),
              children: [
                _settingsCard(context, [
                  _settingsRow(
                    context,
                    '主要字体',
                    theme.fontChoice.label,
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const FontPickerView(
                          title: '主要字体',
                          kind: FontPickerKind.primary,
                        ),
                      ),
                    ),
                  ),
                  _settingsRow(
                    context,
                    '自定义主要字体',
                    theme.customPrimaryFontFamily.isEmpty
                        ? '未设置'
                        : theme.customPrimaryFontFamily,
                    () => _editCustomFont(
                      context,
                      title: '自定义主要字体',
                      initial: theme.customPrimaryFontFamily,
                      onSave: (value) =>
                          context
                                  .read<ThemeController>()
                                  .customPrimaryFontFamily =
                              value,
                    ),
                  ),
                  if (showCjkFallback)
                    _settingsRow(
                      context,
                      '汉字字体',
                      theme.cjkFontChoice.label,
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const FontPickerView(
                            title: '汉字字体',
                            kind: FontPickerKind.cjk,
                          ),
                        ),
                      ),
                    ),
                  if (showCjkFallback)
                    _settingsRow(
                      context,
                      '自定义汉字字体',
                      theme.customCjkFontFamily.isEmpty
                          ? '未设置'
                          : theme.customCjkFontFamily,
                      () => _editCustomFont(
                        context,
                        title: '自定义汉字字体',
                        initial: theme.customCjkFontFamily,
                        onSave: (value) =>
                            context
                                    .read<ThemeController>()
                                    .customCjkFontFamily =
                                value,
                      ),
                    ),
                ]),
                const SizedBox(height: AppSpacing.md),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxl,
                  ),
                  child: Text(
                    showCjkFallback
                        ? '主要字体用于西文；汉字字体用于中文、日文等 CJK 字符。'
                        : '当前主要字体已覆盖汉字，不需要单独设置汉字字体。',
                    style: TextStyle(
                      fontSize: AppTextSize.footnote,
                      color: c.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsCard(BuildContext context, List<Widget> rows) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i < rows.length - 1)
              const InsetDivider(leadingInset: AppSpacing.xxl),
          ],
        ],
      ),
    );
  }

  Future<void> _editCustomFont(
    BuildContext context, {
    required String title,
    required String initial,
    required ValueChanged<String> onSave,
  }) async {
    final value = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => EditFieldView(
          title: title,
          initial: initial,
          hint: '输入系统字体 family，例如 Futura 或 PingFang SC；留空使用预设',
          maxLength: 80,
        ),
      ),
    );
    if (value == null || !context.mounted) return;
    onSave(value);
  }

  Widget _settingsRow(
    BuildContext context,
    String label,
    String value,
    VoidCallback onTap,
  ) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: AppMetric.menuRowHeight + AppSpacing.xxs,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: AppTextSize.bodyLarge,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: AppTextSize.body,
                    color: c.textTertiary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.chevron_right_rounded,
                size: AppIconSize.lg,
                color: c.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum FontPickerKind { primary, cjk }

class FontPickerView extends StatelessWidget {
  const FontPickerView({super.key, required this.title, required this.kind});

  final String title;
  final FontPickerKind kind;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = context.watch<ThemeController>();
    final fonts = switch (kind) {
      FontPickerKind.primary => AppFontChoice.primaryOptions,
      FontPickerKind.cjk => AppFontChoice.cjkOptions,
    };
    final selected = switch (kind) {
      FontPickerKind.primary => theme.fontChoice,
      FontPickerKind.cjk => theme.cjkFontChoice,
    };
    return Scaffold(
      backgroundColor: c.groupedBackground,
      body: Column(
        children: [
          NavHeader(title: title, onBack: () => Navigator.of(context).pop()),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.section,
              ),
              children: [_fontCard(context, fonts, selected)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fontCard(
    BuildContext context,
    List<AppFontChoice> fonts,
    AppFontChoice selected,
  ) {
    final c = context.colors;
    final rows = fonts
        .map(
          (font) => _fontRow(
            context,
            font,
            selected: selected == font,
            onTap: () {
              final theme = context.read<ThemeController>();
              switch (kind) {
                case FontPickerKind.primary:
                  theme.fontChoice = font;
                case FontPickerKind.cjk:
                  theme.cjkFontChoice = font;
              }
            },
          ),
        )
        .toList();
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i < rows.length - 1)
              const InsetDivider(leadingInset: AppSpacing.xxl),
          ],
        ],
      ),
    );
  }

  Widget _fontRow(
    BuildContext context,
    AppFontChoice font, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: AppMetric.menuRowHeight + AppSpacing.md,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      font.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: font.previewStyle(
                        TextStyle(
                          fontSize: AppTextSize.bodyLarge,
                          color: c.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      font.previewText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: font.previewStyle(
                        TextStyle(
                          fontSize: AppTextSize.footnote,
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              if (selected)
                Icon(Icons.check, size: AppIconSize.lg, color: AppTheme.brand),
            ],
          ),
        ),
      ),
    );
  }
}
