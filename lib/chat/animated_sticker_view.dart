//
//  animated_sticker_view.dart
//
//  Renders a Telegram `.tgs` sticker — gzipped Lottie JSON. We resolve the file
//  via TDFileCenter, gunzip it (the `archive` package), and play it with the
//  `lottie` package. Port of the Swift `AnimatedStickerView` + `Gzip` (which
//  used the Compression framework + lottie-ios).
//

import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../tdlib/td_client.dart';
import '../tdlib/td_image_loader.dart';
import '../tdlib/td_models.dart';

class AnimatedStickerView extends StatefulWidget {
  const AnimatedStickerView({super.key, required this.file, this.onReady});
  final TdFileRef file;
  final VoidCallback? onReady;

  @override
  State<AnimatedStickerView> createState() => _AnimatedStickerViewState();
}

class _AnimatedStickerViewState extends State<AnimatedStickerView> {
  Uint8List? _bytes;
  int? _loadedId;
  int? _loadedSlot;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AnimatedStickerView old) {
    super.didUpdateWidget(old);
    _load();
  }

  Future<void> _load() async {
    final ref = widget.file;
    final slot = TdClient.shared.activeSlot;
    if (_loadedId == ref.id && _loadedSlot == slot) return;
    _loadedId = ref.id;
    _loadedSlot = slot;

    final path = await TdFileCenter.shared.path(ref.id);
    if (!mounted || path == null || _loadedId != ref.id) return;
    try {
      final bytes = await File(path).readAsBytes();
      // .tgs = gzipped Lottie JSON.
      final inflated = Uint8List.fromList(GZipDecoder().decodeBytes(bytes));
      if (!mounted || _loadedId != ref.id) return;
      setState(() => _bytes = inflated);
      widget.onReady?.call();
    } catch (_) {
      // not gzipped or unreadable — leave the placeholder showing
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes == null) return const SizedBox.expand();
    return Lottie.memory(bytes, fit: BoxFit.contain, repeat: true);
  }
}
