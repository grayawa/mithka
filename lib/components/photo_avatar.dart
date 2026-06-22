//
//  photo_avatar.dart
//
//  Avatar that shows a real TDLib profile photo when available (with an instant
//  minithumbnail placeholder), falling back to a colored monogram. Circle for
//  people, rounded-square for groups. Port of the Swift `PhotoAvatar`/`TDImage`.
//

import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../tdlib/td_client.dart';
import '../tdlib/td_image_loader.dart';
import '../tdlib/td_models.dart';

/// Clips its child to a circle (people) or a rounded square (groups/channels).
class AvatarClip extends StatelessWidget {
  const AvatarClip({
    super.key,
    required this.child,
    required this.size,
    this.square = false,
  });
  final Widget child;
  final double size;
  final bool square;

  @override
  Widget build(BuildContext context) {
    if (square) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(
          size * AppTheme.groupAvatarCornerRatio,
        ),
        child: child,
      );
    }
    return ClipOval(child: child);
  }
}

String _initial(String title) {
  final trimmed = title.trim();
  if (trimmed.isEmpty) return '?';
  return trimmed.characters.first.toUpperCase();
}

/// Profile/group avatar with a real TDLib photo, placeholder, and monogram.
class PhotoAvatar extends StatefulWidget {
  const PhotoAvatar({
    super.key,
    required this.title,
    this.photo,
    this.size = 50,
    this.square = false,
    this.showOnlineDot = false,
  });

  final String title;
  final TdFileRef? photo;
  final double size;
  final bool square;
  final bool showOnlineDot;

  @override
  State<PhotoAvatar> createState() => _PhotoAvatarState();
}

class _PhotoAvatarState extends State<PhotoAvatar> {
  File? _file;
  int? _loadedId;
  int? _loadedSlot;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PhotoAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _load();
  }

  void _load() {
    final ref = widget.photo;
    final slot = TdClient.shared.activeSlot;
    if (ref == null) {
      if (_file != null) setState(() => _file = null);
      _loadedId = null;
      _loadedSlot = null;
      return;
    }
    // File ids are per-account; reload when either id or active account changes.
    if (_loadedId == ref.id && _loadedSlot == slot) return;
    _loadedId = ref.id;
    _loadedSlot = slot;
    setState(() => _file = null); // reset to placeholder
    TdFileCenter.shared.path(ref.id).then((path) {
      if (!mounted || _loadedId != ref.id || _loadedSlot != slot) return;
      if (path != null) setState(() => _file = File(path));
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    Widget avatar = AvatarClip(
      size: size,
      square: widget.square,
      child: SizedBox(width: size, height: size, child: _content()),
    );

    if (widget.showOnlineDot) {
      final dot = size * 0.26;
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                color: AppTheme.onlineDot,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: size * 0.05),
              ),
            ),
          ),
        ],
      );
    }
    return avatar;
  }

  Widget _content() {
    final ref = widget.photo;
    if (_file != null) {
      return Image.file(
        _file!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }
    if (ref?.miniThumb != null) {
      return Image.memory(
        ref!.miniThumb!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    final size = widget.size;
    return Container(
      color: AppTheme.avatarColor(widget.title),
      alignment: Alignment.center,
      child: Text(
        _initial(widget.title),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Circular monogram avatar (fallback / simple cases like "我").
class MonogramAvatar extends StatelessWidget {
  const MonogramAvatar({
    super.key,
    required this.title,
    this.size = 50,
    this.showOnlineDot = false,
    this.square = false,
  });

  final String title;
  final double size;
  final bool showOnlineDot;
  final bool square;

  @override
  Widget build(BuildContext context) {
    return PhotoAvatar(
      title: title,
      size: size,
      square: square,
      showOnlineDot: showOnlineDot,
    );
  }
}

/// Generic TDLib-file image (e.g. photo-message thumbnails).
class TDImage extends StatefulWidget {
  const TDImage({
    super.key,
    this.photo,
    this.cornerRadius = 8,
    this.fit = BoxFit.cover,
  });
  final TdFileRef? photo;
  final double cornerRadius;
  final BoxFit fit;

  @override
  State<TDImage> createState() => _TDImageState();
}

class _TDImageState extends State<TDImage> {
  File? _file;
  int? _loadedId;
  int? _loadedSlot;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(TDImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _load();
  }

  void _load() {
    final ref = widget.photo;
    final slot = TdClient.shared.activeSlot;
    if (ref == null) {
      _loadedId = null;
      return;
    }
    if (_loadedId == ref.id && _loadedSlot == slot) return;
    _loadedId = ref.id;
    _loadedSlot = slot;
    setState(() => _file = null);
    TdFileCenter.shared.path(ref.id).then((path) {
      if (!mounted || _loadedId != ref.id || _loadedSlot != slot) return;
      if (path != null) setState(() => _file = File(path));
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (_file != null) {
      child = Image.file(_file!, fit: widget.fit);
    } else if (widget.photo?.miniThumb != null) {
      child = Image.memory(widget.photo!.miniThumb!, fit: widget.fit);
    } else {
      child = Container(color: context.colors.groupedBackground);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.cornerRadius),
      child: child,
    );
  }
}
