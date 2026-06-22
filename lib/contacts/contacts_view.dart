//
//  contacts_view.dart
//
//  The 联系人 tab: a custom root header (avatar → drawer, title, add icon) over a
//  search pill and a 好友 / 群聊 segmented switch. 好友 lists contacts, 群聊 lists
//  group/channel chats. Port of the Swift `ContactsView` / `ContactsViewModel`.
//

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../chat/chat_view.dart';
import '../components/drawer_controller.dart' as dc;
import 'add_people_view.dart';
import '../components/photo_avatar.dart';
import '../components/sf_symbols.dart';
import '../components/ui_components.dart';
import '../profile/profile_detail_view.dart';
import '../tdlib/json_helpers.dart';
import '../tdlib/td_client.dart';
import '../tdlib/td_models.dart';
import '../theme/app_theme.dart';

class ContactsView extends StatefulWidget {
  const ContactsView({super.key});

  @override
  State<ContactsView> createState() => _ContactsViewState();
}

class _ContactsViewState extends State<ContactsView> {
  final _vm = ContactsViewModel();
  String _meName = '我';
  TdFileRef? _mePhoto;
  int _tab = 0; // 0 好友, 1 群聊

  @override
  void initState() {
    super.initState();
    _vm.addListener(() {
      if (mounted) setState(() {});
    });
    _vm.onAppear();
    _loadMe();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  void _showAddMenu() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AddPeopleView()));
  }

  Future<void> _loadMe() async {
    try {
      final me = await TdClient.shared.query({'@type': 'getMe'});
      if (!mounted) return;
      setState(() {
        final name = TDParse.userName(me);
        if (name.isNotEmpty) _meName = name;
        _mePhoto = TDParse.smallPhoto(me.obj('profile_photo'));
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      color: c.groupedBackground,
      child: Column(
        children: [
          _header(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _searchPill(),
                _segment(),
                _tab == 0 ? _friendsList() : _groupsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final c = context.colors;
    return Container(
      color: c.listHeaderTint,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => context.read<dc.DrawerController>().open(),
              child: PhotoAvatar(title: _meName, photo: _mePhoto, size: 34),
            ),
            const SizedBox(width: 12),
            Text(
              '联系人',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
            const Spacer(),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _showAddMenu,
              child: Icon(
                sfIcon('person.badge.plus'),
                size: 22,
                color: c.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchPill() {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: c.searchFill,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            Icon(sfIcon('magnifyingglass'), size: 16, color: c.textTertiary),
            const SizedBox(width: 6),
            Text('搜索', style: TextStyle(fontSize: 14, color: c.textTertiary)),
          ],
        ),
      ),
    );
  }

  Widget _segment() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
      child: CupertinoSlidingSegmentedControl<int>(
        groupValue: _tab,
        onValueChanged: (v) => setState(() => _tab = v ?? 0),
        children: const {
          0: Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('好友'),
          ),
          1: Text('群聊'),
        },
      ),
    );
  }

  Widget _card(List<Widget> children) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      child: Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }

  Widget _friendsList() {
    final c = context.colors;
    return _card([
      for (final contact in _vm.contacts) ...[
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  ProfileDetailView(userId: contact.id, name: contact.name),
            ),
          ),
          child: SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  PhotoAvatar(
                    title: contact.name,
                    photo: contact.photo,
                    size: 44,
                    showOnlineDot: contact.isOnline,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contact.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 16, color: c.textPrimary),
                        ),
                        if (contact.statusText.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            contact.statusText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (contact != _vm.contacts.last) const InsetDivider(leadingInset: 70),
      ],
    ]);
  }

  Widget _groupsList() {
    final c = context.colors;
    return _card([
      for (final group in _vm.groups) ...[
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatView(chatId: group.id, title: group.title),
            ),
          ),
          child: SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  PhotoAvatar(
                    title: group.title,
                    photo: group.photo,
                    size: 44,
                    square: true,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      group.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, color: c.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (group != _vm.groups.last) const InsetDivider(leadingInset: 70),
      ],
    ]);
  }
}

class ContactsViewModel extends ChangeNotifier {
  List<Contact> contacts = [];
  List<ChatSummary> groups = [];

  bool _started = false;
  final Map<int, ChatSummary> _groupIndex = {};

  void onAppear() {
    if (_started) return;
    _started = true;
    _loadContacts();
    _subscribe();
    TdClient.shared
        .query({
          '@type': 'loadChats',
          'chat_list': {'@type': 'chatListMain'},
          'limit': 50,
        })
        .catchError((_) => <String, dynamic>{});
  }

  Future<void> _loadContacts() async {
    try {
      final result = await TdClient.shared.query({'@type': 'getContacts'});
      final ids = result.int64Array('user_ids') ?? const <int>[];
      final loaded = <Contact>[];
      for (final id in ids.take(300)) {
        try {
          final user = await TdClient.shared.query({
            '@type': 'getUser',
            'user_id': id,
          });
          loaded.add(
            Contact(
              id: id,
              name: TDParse.userName(user),
              username: user.obj('usernames')?.str('editable_username'),
              statusText: TDParse.userStatus(user),
              photo: TDParse.smallPhoto(user.obj('profile_photo')),
              isOnline: TDParse.isUserOnline(user),
            ),
          );
        } catch (_) {}
      }
      loaded.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      contacts = loaded;
      notifyListeners();
    } catch (_) {}
  }

  void _subscribe() {
    TdClient.shared.subscribe().listen((update) {
      switch (update.type) {
        case 'updateNewChat':
          final chat = update.obj('chat');
          if (chat != null) {
            final s = TDParse.chat(chat);
            if (s != null) _ingest(s);
          }
        case 'updateChatTitle':
          final id = update.int64('chat_id');
          final existing = id != null ? _groupIndex[id] : null;
          if (existing != null) {
            existing.title = update.str('title') ?? existing.title;
            _ingest(existing);
          }
        case 'updateChatPhoto':
          final id = update.int64('chat_id');
          final existing = id != null ? _groupIndex[id] : null;
          if (existing != null) {
            existing.photo = TDParse.smallPhoto(update.obj('photo'));
            _ingest(existing);
          }
      }
    });
  }

  void _ingest(ChatSummary summary) {
    if (summary.kind != ChatKind.group && summary.kind != ChatKind.channel) {
      return;
    }
    _groupIndex[summary.id] = summary;
    groups = _groupIndex.values.toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    notifyListeners();
  }
}
