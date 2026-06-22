//
//  td_image_loader.dart
//
//  Resolves TDLib file ids to on-disk paths by driving downloadFile and
//  listening for updateFile. Used by PhotoAvatar / TDImage to show real profile
//  photos and thumbnails. The Flutter port of the Swift `TDFileCenter`.
//

import 'dart:async';

import 'json_helpers.dart';
import 'td_client.dart';

class TdFileCenter {
  TdFileCenter._();
  static final TdFileCenter shared = TdFileCenter._();

  final TdClient _client = TdClient.shared;

  // Keyed by "slot:fileId" — TDLib file ids are PER-ACCOUNT, so the same id
  // means different files in different accounts.
  final Map<String, String> _cache = {};
  final Map<String, List<Completer<String?>>> _waiters = {};
  bool _started = false;

  String _key(int slot, int fileId) => '$slot:$fileId';

  void _startIfNeeded() {
    if (_started) return;
    _started = true;
    _client.subscribe().listen((update) {
      if (update.type != 'updateFile') return;
      final file = update.obj('file');
      if (file != null) _ingest(file);
    });
  }

  /// Records a completed file and wakes any waiters.
  void _ingest(Map<String, dynamic> file) {
    final id = file.integer('id');
    final local = file.obj('local');
    if (id == null ||
        local == null ||
        local.boolean('is_downloading_completed') != true) {
      return;
    }
    final path = local.str('path');
    if (path == null || path.isEmpty) return;

    final slot = _client.activeSlot;
    final k = _key(slot, id);
    _cache[k] = path;
    final pending = _waiters.remove(k) ?? [];
    for (final c in pending) {
      if (!c.isCompleted) c.complete(path);
    }
  }

  /// Returns a local path for the file id, downloading if needed.
  Future<String?> path(int fileId) async {
    _startIfNeeded();

    final slot = _client.activeSlot;
    final cached = _cache[_key(slot, fileId)];
    if (cached != null) return cached;

    // Kick the download. The immediate response reflects current state, so an
    // already-complete file resolves without waiting for an update.
    try {
      final response = await _client.query({
        '@type': 'downloadFile',
        'file_id': fileId,
        'priority': 16,
        'offset': 0,
        'limit': 0,
        'synchronous': false,
      });
      final local = response.obj('local');
      if (local?.boolean('is_downloading_completed') == true) {
        final path = local?.str('path');
        if (path != null && path.isNotEmpty) {
          _cache[_key(slot, fileId)] = path;
          return path;
        }
      }
    } catch (_) {
      // fall through to wait for updateFile
    }

    // Otherwise wait for the completing updateFile.
    final k = _key(slot, fileId);
    final existing = _cache[k];
    if (existing != null) return existing;
    final completer = Completer<String?>();
    _waiters.putIfAbsent(k, () => []).add(completer);
    return completer.future;
  }
}
