//
//  shared_media_view.dart
//
//  Shared-content browser for a chat (群相册 / 文件). Tabs run `searchChatMessages`
//  with a media filter — photos/videos in a grid, documents / links / voice in
//  lists. Opened from the chat-info screen.
//

import 'package:flutter/material.dart';

import '../components/photo_avatar.dart';
import '../components/sf_symbols.dart';
import '../tdlib/json_helpers.dart';
import '../tdlib/td_client.dart';
import '../tdlib/td_models.dart';
import '../theme/app_theme.dart';
import '../theme/date_text.dart';
import 'file_opener.dart';
import 'full_image_viewer.dart';
import 'link_handler.dart';

class _MediaTab {
  const _MediaTab(this.label, this.filter, this.grid);
  final String label;
  final String filter;
  final bool grid;
}

class SharedMediaView extends StatefulWidget {
  const SharedMediaView({
    super.key,
    required this.chatId,
    required this.title,
    this.initialTab = 0,
  });
  final int chatId;
  final String title;
  final int initialTab; // 0 图片视频, 1 文件, 2 链接, 3 语音

  @override
  State<SharedMediaView> createState() => _SharedMediaViewState();
}

class _SharedMediaViewState extends State<SharedMediaView> {
  static const _tabs = [
    _MediaTab('图片视频', 'searchMessagesFilterPhotoAndVideo', true),
    _MediaTab('文件', 'searchMessagesFilterDocument', false),
    _MediaTab('链接', 'searchMessagesFilterUrl', false),
    _MediaTab('语音', 'searchMessagesFilterVoiceNote', false),
  ];

  final TdClient _client = TdClient.shared;
  late int _tab = widget.initialTab;
  final Map<int, List<ChatMessage>> _cache = {};
  final Set<int> _loading = {};

  @override
  void initState() {
    super.initState();
    _load(_tab);
  }

  Future<void> _load(int tab) async {
    if (_cache.containsKey(tab) || _loading.contains(tab)) return;
    _loading.add(tab);
    try {
      final res = await _client.query({
        '@type': 'searchChatMessages',
        'chat_id': widget.chatId,
        'query': '',
        'sender_id': null,
        'from_message_id': 0,
        'offset': 0,
        'limit': 80,
        'filter': {'@type': _tabs[tab].filter},
      });
      final list = res.objects('messages') ?? const <Map<String, dynamic>>[];
      final parsed = list
          .map(TDParse.message)
          .whereType<ChatMessage>()
          .toList();
      if (!mounted) return;
      setState(() {
        _cache[tab] = parsed;
        _loading.remove(tab);
      });
    } catch (_) {
      if (mounted) setState(() => _loading.remove(tab));
    }
  }

  void _select(int tab) {
    setState(() => _tab = tab);
    _load(tab);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      body: Column(
        children: [
          _header(),
          _tabStrip(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _header() {
    final c = context.colors;
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: BoxDecoration(
        color: c.navBar,
        border: Border(bottom: BorderSide(color: c.divider, width: 0.5)),
      ),
      child: SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Icon(
                    sfIcon('chevron.left'),
                    size: 22,
                    color: c.textPrimary,
                  ),
                ),
              ),
            ),
            Text(
              '聊天文件',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabStrip() {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.navBar,
        border: Border(bottom: BorderSide(color: c.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _tabs.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _select(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: _tab == i ? AppTheme.brand : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    _tabs[i].label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: _tab == i ? FontWeight.w600 : FontWeight.w400,
                      color: _tab == i ? AppTheme.brand : c.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _body() {
    final c = context.colors;
    final items = _cache[_tab];
    if (items == null) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator.adaptive(strokeWidth: 2),
        ),
      );
    }
    if (items.isEmpty) {
      return Center(
        child: Text(
          '暂无内容',
          style: TextStyle(fontSize: 14, color: c.textSecondary),
        ),
      );
    }
    return _tabs[_tab].grid ? _grid(items) : _list(items);
  }

  Widget _grid(List<ChatMessage> items) {
    final withImage = items.where((m) => m.image != null).toList();
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: withImage.length,
      itemBuilder: (context, i) {
        final m = withImage[i];
        return GestureDetector(
          onTap: () {
            final imgs = withImage.map((e) => e.image!).toList();
            Navigator.of(context).push(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => FullImageViewer(items: imgs, startIndex: i),
              ),
            );
          },
          child: TDImage(photo: m.image),
        );
      },
    );
  }

  Widget _list(List<ChatMessage> items) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: items.length,
      itemBuilder: (context, i) => _listRow(items[i]),
    );
  }

  Widget _listRow(ChatMessage m) {
    final c = context.colors;
    final isVoice = m.voice != null;
    final isLink = m.document == null && !isVoice;
    final title =
        m.document?.fileName ??
        (isVoice ? '语音消息' : (m.text.isEmpty ? '链接' : m.text));
    final subtitle = m.document != null
        ? _fileSize(m.document!.size)
        : DateText.listLabel(m.date);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (m.document != null) {
          openDocument(context, m.document!);
        } else if (isLink && m.text.isNotEmpty) {
          openLink(context, m.text);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: c.background,
          border: Border(bottom: BorderSide(color: c.divider, width: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.brand.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                sfIcon(
                  isVoice
                      ? 'mic.fill'
                      : isLink
                      ? 'link'
                      : 'doc.fill',
                ),
                size: 20,
                color: AppTheme.brand,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.replaceAll('\n', ' '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, color: c.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: c.textTertiary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fileSize(int bytes) {
    if (bytes >= 1 << 20) return '${(bytes / (1 << 20)).toStringAsFixed(1)} MB';
    if (bytes >= 1 << 10) return '${(bytes / (1 << 10)).toStringAsFixed(0)} KB';
    return '$bytes B';
  }
}
