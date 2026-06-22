//
//  search_view.dart
//
//  Chat search — a pushed secondary screen. Custom header (back chevron +
//  rounded search field) on the list-header wash, with a live list of matching
//  chats below. Port of the Swift `SearchView` / `SearchViewModel`.
//

import 'dart:async';

import 'package:flutter/material.dart';

import '../chat/chat_view.dart';
import '../components/sf_symbols.dart';
import '../components/ui_components.dart';
import '../tdlib/json_helpers.dart';
import '../tdlib/td_client.dart';
import '../tdlib/td_models.dart';
import '../theme/app_theme.dart';
import 'chat_row_view.dart';

class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _vm = SearchViewModel();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _vm.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) _focus.requestFocus();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.groupedBackground,
      body: Column(
        children: [
          _header(),
          Expanded(child: _results()),
        ],
      ),
    );
  }

  Widget _header() {
    final c = context.colors;
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: BoxDecoration(
        color: c.listHeaderTint,
        border: Border(bottom: BorderSide(color: c.divider, width: 0.5)),
      ),
      child: SizedBox(
        height: 52,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Icon(
                    sfIcon('chevron.left'),
                    size: 22,
                    color: c.textPrimary,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: c.searchFill,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        sfIcon('magnifyingglass'),
                        size: 15,
                        color: c.textTertiary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focus,
                          autocorrect: false,
                          textInputAction: TextInputAction.search,
                          style: TextStyle(fontSize: 15, color: c.textPrimary),
                          decoration: const InputDecoration(
                            hintText: '搜索',
                            border: InputBorder.none,
                            isCollapsed: true,
                          ),
                          onChanged: (q) {
                            setState(() => _query = q);
                            _vm.search(q);
                          },
                        ),
                      ),
                      if (_query.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _controller.clear();
                            setState(() => _query = '');
                            _vm.search('');
                          },
                          child: Icon(
                            Icons.cancel,
                            size: 16,
                            color: c.textTertiary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _results() {
    final c = context.colors;
    if (_query.trim().isEmpty) return _empty('搜索聊天、联系人');
    if (_vm.results.isEmpty) return _empty('未找到相关聊天');
    return Container(
      color: c.background,
      child: ListView.builder(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: _vm.results.length,
        itemBuilder: (context, i) {
          final chat = _vm.results[i];
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
    );
  }

  Widget _empty(String text) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      color: c.groupedBackground,
      alignment: Alignment.center,
      child: Text(text, style: TextStyle(fontSize: 14, color: c.textTertiary)),
    );
  }
}

class SearchViewModel extends ChangeNotifier {
  List<ChatSummary> results = [];
  String _currentQuery = '';

  void search(String q) {
    final trimmed = q.trim();
    _currentQuery = trimmed;
    if (trimmed.isEmpty) {
      results = [];
      notifyListeners();
      return;
    }
    _run(trimmed);
  }

  Future<void> _run(String trimmed) async {
    try {
      final res = await TdClient.shared.query({
        '@type': 'searchChats',
        'query': trimmed,
        'limit': 50,
      });
      final ids = res.int64Array('chat_ids') ?? const <int>[];
      final out = <ChatSummary>[];
      for (final id in ids.take(50)) {
        try {
          final chat = await TdClient.shared.query({
            '@type': 'getChat',
            'chat_id': id,
          });
          final s = TDParse.chat(chat);
          if (s != null) out.add(s);
        } catch (_) {}
      }
      if (trimmed != _currentQuery) return; // stale
      results = out;
      notifyListeners();
    } catch (_) {}
  }
}
