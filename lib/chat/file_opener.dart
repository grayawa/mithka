//
//  file_opener.dart
//
//  Downloads a message's document via TDLib (TdFileCenter drives downloadFile)
//  and opens it in the system viewer. Shows progress / fallback feedback.
//

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../components/toast.dart';
import '../tdlib/td_image_loader.dart';
import '../tdlib/td_models.dart';

Future<void> openDocument(BuildContext context, MessageDocument doc) async {
  final id = doc.file?.id;
  if (id == null) return;
  // Capture the overlay up front — context may unmount during the download.
  final overlay = Overlay.of(context);
  showToastOverlay(overlay, '正在下载…');
  String? path;
  try {
    path = await TdFileCenter.shared.path(id);
  } catch (_) {}
  if (path == null) {
    showToastOverlay(overlay, '下载失败');
    return;
  }
  final result = await OpenFilex.open(path);
  if (result.type != ResultType.done) {
    showToastOverlay(overlay, '已下载：${doc.fileName}');
  }
}
