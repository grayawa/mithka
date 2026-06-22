//
//  account_store.dart
//
//  UI-facing coordinator for multi-account: exposes the configured accounts
//  (with each one's identity for display), the active slot, and actions to
//  switch or add an account. Port of the Swift `AccountStore`.
//

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tdlib/json_helpers.dart';
import '../tdlib/td_client.dart';
import '../tdlib/td_models.dart';
import 'auth_manager.dart';

class AccountSummary {
  AccountSummary({
    required this.slot,
    required this.name,
    required this.phone,
    this.avatarPath,
  });
  final int slot;
  final String name;
  final String phone;
  final String? avatarPath; // resolved via this account's OWN TDLib client
}

class AccountStore extends ChangeNotifier {
  AccountStore(SharedPreferences prefs)
    : _activeSlot = prefs.getInt('drachma.activeSlot') ?? 0;

  int _activeSlot;
  List<AccountSummary> _summaries = [];

  int get activeSlot => _activeSlot;
  List<AccountSummary> get summaries => _summaries;

  /// Re-reads each account's identity (getMe per client) for the switcher.
  Future<void> refresh() async {
    _activeSlot = TdClient.shared.activeSlot;
    final result = <AccountSummary>[];
    for (final slot in TdClient.shared.configuredSlots) {
      final cid = TdClient.shared.clientId(slot);
      if (cid == null) continue;
      Map<String, dynamic>? me;
      try {
        me = await TdClient.shared.queryTo({'@type': 'getMe'}, cid);
      } catch (_) {}
      final parsedName = me != null ? TDParse.userName(me) : '';
      final name = parsedName.isEmpty
          ? (slot == _activeSlot ? '未登录账号' : '未登录')
          : parsedName;
      final phone = TDParse.formatPhone(me?.str('phone_number'));

      String? avatarPath;
      final fileId = me?.obj('profile_photo')?.obj('small')?.integer('id');
      if (fileId != null) {
        try {
          final res = await TdClient.shared.queryTo({
            '@type': 'downloadFile',
            'file_id': fileId,
            'priority': 1,
            'offset': 0,
            'limit': 0,
            'synchronous': true,
          }, cid);
          final path = res.obj('local')?.str('path');
          if (path != null && path.isNotEmpty) avatarPath = path;
        } catch (_) {}
      }
      result.add(
        AccountSummary(
          slot: slot,
          name: name,
          phone: phone,
          avatarPath: avatarPath,
        ),
      );
    }
    _summaries = result;
    notifyListeners();
  }

  /// Switches to an existing account and re-gates auth on it.
  void switchTo(int slot, AuthManager auth) {
    if (slot == _activeSlot) return;
    TdClient.shared.setActive(slot);
    _activeSlot = slot;
    notifyListeners();
    auth.reloadAuthState();
    refresh();
  }

  /// Creates a fresh account and switches to it (lands on the login flow).
  void addAccount(AuthManager auth) {
    final slot = TdClient.shared.addSlot();
    TdClient.shared.setActive(slot);
    _activeSlot = slot;
    notifyListeners();
    auth.reloadAuthState();
    refresh();
  }
}
