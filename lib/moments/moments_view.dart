//
//  moments_view.dart
//
//  The 动态 tab: friends' Telegram Stories (TDLib active stories). Each row is a
//  friend whose active stories are grouped; tapping opens a full-screen viewer.
//  Port of the Swift `MomentsView` / `MomentsViewModel`.
//

import 'package:flutter/material.dart';

import '../components/photo_avatar.dart';
import '../components/sf_symbols.dart';
import '../components/ui_components.dart';
import '../tdlib/json_helpers.dart';
import '../tdlib/td_client.dart';
import '../tdlib/td_models.dart';
import '../theme/app_theme.dart';
import '../theme/date_text.dart';
import 'story_viewer_view.dart';

class StoryGroup {
  StoryGroup({
    required this.chatId,
    required this.name,
    this.photo,
    required this.storyIds,
    required this.hasUnread,
    required this.order,
  });
  final int chatId;
  final String name;
  final TdFileRef? photo;
  final List<int> storyIds;
  final bool hasUnread;
  final int order;
}

class MomentsView extends StatefulWidget {
  const MomentsView({super.key});

  @override
  State<MomentsView> createState() => _MomentsViewState();
}

class _MomentsViewState extends State<MomentsView> {
  final _model = MomentsViewModel();

  @override
  void initState() {
    super.initState();
    _model.addListener(() {
      if (mounted) setState(() {});
    });
    _model.start();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      color: c.groupedBackground,
      child: Column(
        children: [
          NavHeader(title: '动态'),
          Expanded(child: _content()),
        ],
      ),
    );
  }

  Widget _content() {
    final c = context.colors;
    if (_model.groups.isEmpty && _model.loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('加载动态…'),
          ],
        ),
      );
    }
    if (_model.groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(sfIcon('circle.dashed'), size: 46, color: AppTheme.brand),
            const SizedBox(height: 12),
            Text(
              '暂无好友动态',
              style: TextStyle(fontSize: 15, color: c.textSecondary),
            ),
          ],
        ),
      );
    }
    return Container(
      color: c.background,
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: _model.groups.length,
        itemBuilder: (context, i) {
          final group = _model.groups[i];
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _row(group),
              if (i != _model.groups.length - 1)
                const InsetDivider(leadingInset: 80),
            ],
          );
        },
      ),
    );
  }

  Widget _row(StoryGroup group) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) =>
              StoryViewerView(chatId: group.chatId, storyIds: group.storyIds),
        ),
      ),
      child: Container(
        height: 72,
        color: c.background,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: group.hasUnread ? AppTheme.brandGradient : null,
              ),
              child: PhotoAvatar(
                title: group.name,
                photo: group.photo,
                size: 54,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${group.storyIds.length} 条新动态',
                    style: TextStyle(fontSize: 13, color: c.textSecondary),
                  ),
                ],
              ),
            ),
            Text(
              DateText.listLabel(group.order),
              style: TextStyle(fontSize: 12, color: c.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

class MomentsViewModel extends ChangeNotifier {
  List<StoryGroup> groups = [];
  bool loading = false;
  final Map<int, StoryGroup> _map = {};
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    loading = true;
    notifyListeners();
    TdClient.shared.subscribe().listen((update) {
      if (update.type == 'updateChatActiveStories') _handle(update);
    });
    TdClient.shared
        .query({
          '@type': 'loadActiveStories',
          'story_list': {'@type': 'storyListMain'},
        })
        .whenComplete(() {
          loading = false;
          notifyListeners();
        });
  }

  Future<void> _handle(Map<String, dynamic> update) async {
    final a = update.obj('active_stories');
    if (a == null) return;
    final chatId = a.int64('chat_id') ?? 0;
    if (chatId == 0) return;
    final order = a.int64('order') ?? 0;
    final infos = a.objects('stories') ?? const <Map<String, dynamic>>[];
    final storyIds = infos
        .map((s) => s.int64('story_id'))
        .whereType<int>()
        .toList();

    if (storyIds.isEmpty) {
      _map.remove(chatId);
      _publish();
      loading = false;
      return;
    }

    final maxRead = a.integer('max_read_story_id') ?? 0;
    final hasUnread = storyIds.any((id) => id > maxRead);

    var name = '';
    TdFileRef? photo;
    try {
      final chat = await TdClient.shared.query({
        '@type': 'getChat',
        'chat_id': chatId,
      });
      name = chat.str('title') ?? '';
      photo = TDParse.smallPhoto(chat.obj('photo'));
    } catch (_) {}
    if (name.isEmpty) name = _map[chatId]?.name ?? '未知';

    _map[chatId] = StoryGroup(
      chatId: chatId,
      name: name,
      photo: photo,
      storyIds: storyIds,
      hasUnread: hasUnread,
      order: order,
    );
    _publish();
    loading = false;
  }

  void _publish() {
    groups = _map.values.toList()..sort((a, b) => b.order.compareTo(a.order));
    notifyListeners();
  }
}
