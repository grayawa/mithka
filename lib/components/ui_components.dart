//
//  ui_components.dart
//
//  Reusable reference-styled building blocks. People use circular avatars;
//  groups use rounded squares. Bubbles have a small tail. Port of the Swift
//  `UIComponents` (NavHeader, badges, dividers, separators, bubble shape).
//

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/date_text.dart';
import '../tdlib/td_models.dart';
import 'sf_symbols.dart';

/// Flat reference-style header bar: optional back chevron, leading title,
/// optional trailing icon. Fixed 44pt height with a hairline bottom divider.
class NavHeader extends StatelessWidget {
  const NavHeader({
    super.key,
    required this.title,
    this.onBack,
    this.trailingIcon,
    this.onTrailing,
    this.trailing,
  });

  final String title;
  final VoidCallback? onBack;
  final String? trailingIcon;
  final VoidCallback? onTrailing;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: 44 + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: BoxDecoration(
        color: c.navBar,
        border: Border(bottom: BorderSide(color: c.divider, width: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            if (onBack != null)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onBack,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(
                    sfIcon('chevron.left'),
                    size: 22,
                    color: c.textPrimary,
                  ),
                ),
              ),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: c.textPrimary,
                ),
              ),
            ),
            ?trailing,
            if (trailing == null && trailingIcon != null)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTrailing,
                child: Icon(
                  sfIcon(trailingIcon!),
                  size: 21,
                  color: c.textPrimary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Red unread-count pill.
class UnreadBadge extends StatelessWidget {
  const UnreadBadge({super.key, required this.count, this.muted = false});
  final int count;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: EdgeInsets.symmetric(horizontal: count > 9 ? 5 : 0),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: muted ? context.colors.textTertiary : AppTheme.unreadBadge,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Group role tag: owner = yellow, admin = teal, member = purple.
class RoleTag extends StatelessWidget {
  const RoleTag({super.key, required this.role, this.title});
  final MemberRole role;
  final String? title;

  Color get _color => switch (role) {
    MemberRole.owner => const Color(0xFFFFB300),
    MemberRole.admin => const Color(0xFF16B0A0),
    MemberRole.member => const Color(0xFF9B7BE8),
  };

  String get _label {
    if (title != null && title!.isNotEmpty) return title!;
    return switch (role) {
      MemberRole.owner => '群主',
      MemberRole.admin => '管理员',
      MemberRole.member => '成员',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Small solid dot (muted unread indicator / tab markers).
class RedDot extends StatelessWidget {
  const RedDot({super.key, this.size = 9});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: AppTheme.unreadBadge,
      shape: BoxShape.circle,
    ),
  );
}

/// Thin inset list divider.
class InsetDivider extends StatelessWidget {
  const InsetDivider({super.key, this.leadingInset = 76});
  final double leadingInset;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(left: leadingInset),
    child: Container(height: 0.5, color: context.colors.divider),
  );
}

/// Centered gray timestamp separator in a conversation.
class TimeSeparator extends StatelessWidget {
  const TimeSeparator({super.key, required this.unix});
  final int unix;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Center(
      child: Text(
        DateText.separatorLabel(unix),
        style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
      ),
    ),
  );
}

/// Centered system/service banner (joins, pins, friendship notes).
class SystemBanner extends StatelessWidget {
  const SystemBanner({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: c.textPrimary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: c.textSecondary),
          ),
        ),
      ),
    );
  }
}

/// Chat-list preview: optional gray sender prefix + message, with a few "alert"
/// tags colored red.
class ChatPreviewText extends StatelessWidget {
  const ChatPreviewText({
    super.key,
    this.sender,
    required this.message,
    this.draft = false,
  });
  final String? sender;
  final String message;
  final bool draft; // render a red "[草稿]" prefix and ignore sender

  static const _redTags = ['[有新文件]', '[有人@我]', '[草稿]', '[@我]'];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isRed = _redTags.any(message.startsWith);
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(fontSize: 13),
        children: [
          if (draft)
            TextSpan(
              text: '[草稿] ',
              style: TextStyle(color: AppTheme.tagRed),
            )
          else if (sender != null && sender!.isNotEmpty)
            TextSpan(
              text: '$sender: ',
              style: TextStyle(color: c.textSecondary),
            ),
          TextSpan(
            text: message.replaceAll('\n', ' '),
            style: TextStyle(
              color: !draft && isRed ? AppTheme.tagRed : c.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded bubble with a small tail (leading = incoming, trailing = outgoing).
class BubbleClipper extends CustomClipper<Path> {
  BubbleClipper({required this.isOutgoing, this.radius = 9, this.tail = 6});
  final bool isOutgoing;
  final double radius;
  final double tail;

  @override
  Path getClip(Size size) {
    final p = Path();
    final body = isOutgoing
        ? Rect.fromLTWH(0, 0, size.width - tail, size.height)
        : Rect.fromLTWH(tail, 0, size.width - tail, size.height);
    p.addRRect(RRect.fromRectAndRadius(body, Radius.circular(radius)));

    const ty = 16.0;
    if (isOutgoing) {
      p.moveTo(body.right - 1, ty - 5);
      p.lineTo(size.width, ty);
      p.lineTo(body.right - 1, ty + 6);
    } else {
      p.moveTo(body.left + 1, ty - 5);
      p.lineTo(0, ty);
      p.lineTo(body.left + 1, ty + 6);
    }
    p.close();
    return p;
  }

  @override
  bool shouldReclip(BubbleClipper old) =>
      old.isOutgoing != isOutgoing || old.radius != radius || old.tail != tail;
}
