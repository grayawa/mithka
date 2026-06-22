//
//  archived_chats_view.dart
//
//  The reference "群助手": Telegram Archive chats folded behind a single entry.
//  GroupAssistantRow is the collapsed row shown in the 消息 list; tapping it
//  pushes ArchivedChatsView. Port of the Swift `ArchivedChatsView`.
//

import 'package:flutter/material.dart';

import '../chat/chat_view.dart';
import '../components/sf_symbols.dart';
import '../components/ui_components.dart';
import '../tdlib/td_models.dart';
import '../theme/app_theme.dart';
import '../theme/date_text.dart';
import 'chat_row_view.dart';

/// Collapsed "群助手" entry summarizing archived chats.
class GroupAssistantRow extends StatelessWidget {
  const GroupAssistantRow({super.key, required this.archived});
  final List<ChatSummary> archived;

  ChatSummary? get _latest => archived.isEmpty ? null : archived.first;
  int get _totalUnread => archived.fold(0, (a, c) => a + c.unreadCount);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: AppTheme.rowHeight,
      color: c.background,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            height: 50,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF9D2E),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    sfIcon('message.fill'),
                    size: 22,
                    color: Colors.white,
                  ),
                ),
                if (_totalUnread > 0)
                  Positioned(
                    right: -6,
                    top: -5,
                    child: UnreadBadge(count: _totalUnread),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '群助手',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                ChatPreviewText(
                  sender: _latest?.title,
                  message: _latest?.lastMessage ?? '',
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 13),
            child: Text(
              DateText.listLabel(_latest?.date ?? 0),
              style: TextStyle(fontSize: 12, color: c.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

class ArchivedChatsView extends StatelessWidget {
  const ArchivedChatsView({super.key, required this.chats});
  final List<ChatSummary> chats;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      body: Column(
        children: [
          NavHeader(title: '群助手', onBack: () => Navigator.of(context).pop()),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: chats.length,
              itemBuilder: (context, i) {
                final chat = chats[i];
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ChatView(chatId: chat.id, title: chat.title),
                        ),
                      ),
                      child: ChatRowView(chat: chat),
                    ),
                    const InsetDivider(leadingInset: 78),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
