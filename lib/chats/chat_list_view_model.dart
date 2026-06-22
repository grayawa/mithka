//
//  chat_list_view_model.dart
//
//  Drives the 消息 (chat list) screen. Loads the main chat list from TDLib, then
//  keeps it live by folding in the incremental `update*` events. Ordering:
//  pinned chats float to the top, then the rest sort by TDLib `order` desc, with
//  last-message date as the tiebreaker. Port of the Swift `ChatListViewModel`.
//

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../tdlib/json_helpers.dart';
import '../tdlib/td_client.dart';
import '../tdlib/td_models.dart';

class ChatListViewModel extends ChangeNotifier {
  List<ChatSummary> _chats = [];
  List<ChatSummary> _archived = [];
  String? notice;

  List<ChatSummary> get chats => _chats;
  List<ChatSummary> get archived => _archived;

  /// Authoritative store keyed by chat id; `chats` is a sorted projection.
  final Map<int, ChatSummary> _map = {};
  final Map<int, String> _senderNames = {};
  final Set<int> _resolvingSenders = {};

  final TdClient _client = TdClient.shared;
  StreamSubscription? _sub;
  bool _listening = false;
  static const _pageSize = 40;

  void onAppear() {
    if (_listening) return;
    _listening = true;
    _subscribe();
    _loadChats(_pageSize);
    _loadArchive(_pageSize);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // MARK: - Loading

  void _loadChats(int limit) {
    _client
        .query({
          '@type': 'loadChats',
          'chat_list': {'@type': 'chatListMain'},
          'limit': limit,
        })
        .catchError(
          (_) => <String, dynamic>{},
        ); // 404 when exhausted — harmless
  }

  void _loadArchive(int limit) {
    _client
        .query({
          '@type': 'loadChats',
          'chat_list': {'@type': 'chatListArchive'},
          'limit': limit,
        })
        .catchError((_) => <String, dynamic>{});
  }

  void loadMore() => _loadChats(_pageSize);

  // MARK: - Row actions (swipe)

  void togglePin(ChatSummary chat) {
    final newValue = !chat.isPinned;
    final id = chat.id;
    _mutate(id, (s) => s.isPinned = newValue);
    _resort();

    _client
        .query({
          '@type': 'toggleChatIsPinned',
          'chat_list': {'@type': 'chatListMain'},
          'chat_id': id,
          'is_pinned': newValue,
        })
        .catchError((_) async {
          // Failure: revert and restore the chat's true position from TDLib.
          _mutate(id, (s) => s.isPinned = !newValue);
          try {
            final raw = await _client.query({
              '@type': 'getChat',
              'chat_id': id,
            });
            final fresh = TDParse.chat(raw);
            if (fresh != null) _map[id] = fresh;
          } catch (_) {}
          notice = '置顶失败：已达置顶数量上限';
          _resort();
          return <String, dynamic>{};
        });
  }

  void markUnread(ChatSummary chat) {
    _client.send({
      '@type': 'toggleChatIsMarkedAsUnread',
      'chat_id': chat.id,
      'is_marked_as_unread': true,
    });
  }

  void deleteChat(ChatSummary chat) {
    _client.send({
      '@type': 'deleteChatHistory',
      'chat_id': chat.id,
      'remove_from_chat_list': true,
      'revoke': false,
    });
  }

  void clearNotice() {
    notice = null;
    notifyListeners();
  }

  // MARK: - Update stream

  void _subscribe() {
    _sub = _client.subscribe().listen(_apply);
  }

  void _apply(Map<String, dynamic> update) {
    switch (update.type) {
      case 'updateNewChat':
        final chat = update.obj('chat');
        if (chat == null) return;
        final summary = TDParse.chat(chat);
        if (summary == null) return;
        _map[summary.id] = summary;
        _resolveSenderIfNeeded(summary.id, chat.obj('last_message'));
        _resort();

      case 'updateChatLastMessage':
        final id = update.int64('chat_id');
        if (id == null) return;
        _applyPositions(id, update.objects('positions'));
        _mutate(id, (s) {
          final last = update.obj('last_message');
          if (last != null) {
            s.date = last.integer('date') ?? s.date;
            final content = last.obj('content');
            if (content != null) s.lastMessage = TDParse.messageText(content);
          } else {
            s.lastMessage = '';
            s.date = 0;
            s.lastSender = null;
          }
        });
        _resolveSenderIfNeeded(id, update.obj('last_message'));
        _resort();

      case 'updateChatPosition':
        final id = update.int64('chat_id');
        final position = update.obj('position');
        if (id == null || position == null) return;
        switch (position.obj('list')?.type) {
          case 'chatListMain':
            _mutate(id, (s) {
              s.order = position.int64('order') ?? 0;
              s.isPinned = position.boolean('is_pinned') ?? false;
            });
          case 'chatListArchive':
            _mutate(id, (s) => s.archiveOrder = position.int64('order') ?? 0);
          default:
            return;
        }
        _resort();

      case 'updateChatDraftMessage':
        final id = update.int64('chat_id');
        if (id == null) return;
        _applyPositions(id, update.objects('positions'));
        _mutate(
          id,
          (s) => s.draftText = TDParse.draftText(update.obj('draft_message')),
        );
        _resort();

      case 'updateChatReadInbox':
        final id = update.int64('chat_id');
        if (id == null) return;
        _mutate(
          id,
          (s) =>
              s.unreadCount = update.integer('unread_count') ?? s.unreadCount,
        );
        _resort();

      case 'updateChatIsMarkedAsUnread':
        final id = update.int64('chat_id');
        if (id == null) return;
        _mutate(
          id,
          (s) =>
              s.isMarkedUnread = update.boolean('is_marked_as_unread') ?? false,
        );
        _resort();

      case 'updateChatTitle':
        final id = update.int64('chat_id');
        if (id == null) return;
        _mutate(id, (s) => s.title = update.str('title') ?? s.title);
        _resort();

      case 'updateChatNotificationSettings':
        final id = update.int64('chat_id');
        if (id == null) return;
        _mutate(id, (s) {
          final muteFor =
              update.obj('notification_settings')?.integer('mute_for') ?? 0;
          s.isMuted = muteFor > 0;
        });
        _resort();

      case 'updateChatPhoto':
        final id = update.int64('chat_id');
        if (id == null) return;
        _mutate(id, (s) => s.photo = TDParse.smallPhoto(update.obj('photo')));
        _resort();
    }
  }

  // MARK: - Mutation helpers

  void _mutate(int id, void Function(ChatSummary) body) {
    final s = _map[id];
    if (s == null) return;
    body(s);
  }

  void _applyPositions(int id, List<Map<String, dynamic>>? positions) {
    if (positions == null) return;
    for (final position in positions) {
      switch (position.obj('list')?.type) {
        case 'chatListMain':
          _mutate(id, (s) {
            s.order = position.int64('order') ?? s.order;
            s.isPinned = position.boolean('is_pinned') ?? s.isPinned;
          });
        case 'chatListArchive':
          _mutate(
            id,
            (s) => s.archiveOrder = position.int64('order') ?? s.archiveOrder,
          );
      }
    }
  }

  // MARK: - Sorting

  void _resort() {
    final all = _map.values.toList();
    _archived = all.where((c) => c.archiveOrder > 0).toList()
      ..sort(
        (a, b) => a.archiveOrder != b.archiveOrder
            ? b.archiveOrder.compareTo(a.archiveOrder)
            : b.date.compareTo(a.date),
      );
    _chats = all.where((c) => c.order > 0).toList()..sort(_compare);
    notifyListeners();
  }

  static int _compare(ChatSummary a, ChatSummary b) {
    if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
    if (a.order != b.order) return b.order.compareTo(a.order);
    if (a.date != b.date) return b.date.compareTo(a.date);
    return b.id.compareTo(a.id);
  }

  // MARK: - Last-message sender resolution (groups & channels)

  void _resolveSenderIfNeeded(int id, Map<String, dynamic>? lastMessage) {
    final summary = _map[id];
    if (summary == null) return;
    if (summary.kind != ChatKind.group && summary.kind != ChatKind.channel) {
      return;
    }
    final sender = lastMessage?.obj('sender_id');
    if (sender == null) return;

    switch (sender.type) {
      case 'messageSenderUser':
        final userId = sender.int64('user_id');
        if (userId == null) return;
        final name = _senderNames[userId];
        if (name != null) {
          _setLastSender(name, id);
        } else {
          _resolveUserName(userId, id);
        }
      case 'messageSenderChat':
        final senderChatId = sender.int64('chat_id');
        if (senderChatId == null) return;
        if (senderChatId == id) {
          _setLastSender(null, id);
          return;
        }
        final name = _senderNames[senderChatId];
        if (name != null) {
          _setLastSender(name, id);
        } else {
          _resolveChatTitle(senderChatId, id);
        }
      default:
        _setLastSender(null, id);
    }
  }

  void _setLastSender(String? name, int id) =>
      _mutate(id, (s) => s.lastSender = name);

  void _resolveUserName(int userId, int id) {
    if (_resolvingSenders.contains(userId)) return;
    _resolvingSenders.add(userId);
    _client
        .query({'@type': 'getUser', 'user_id': userId})
        .then((user) {
          _resolvingSenders.remove(userId);
          final name = TDParse.userName(user);
          _senderNames[userId] = name;
          _setLastSender(name, id);
          _resort();
        })
        .catchError((_) {
          _resolvingSenders.remove(userId);
        });
  }

  void _resolveChatTitle(int senderChatId, int id) {
    if (_resolvingSenders.contains(senderChatId)) return;
    _resolvingSenders.add(senderChatId);
    _client
        .query({'@type': 'getChat', 'chat_id': senderChatId})
        .then((chat) {
          _resolvingSenders.remove(senderChatId);
          final title = chat.str('title');
          if (title == null) return;
          _senderNames[senderChatId] = title;
          _setLastSender(title, id);
          _resort();
        })
        .catchError((_) {
          _resolvingSenders.remove(senderChatId);
        });
  }
}
