//
//  drawer_controller.dart
//
//  Drives the left-sliding "我" profile drawer, shared across tabs so any tab
//  header's avatar can open it. Port of the Swift `DrawerController`.
//

import 'package:flutter/widgets.dart';

class DrawerController extends ChangeNotifier {
  bool _isOpen = false;
  bool get isOpen => _isOpen;

  void open() {
    _isOpen = true;
    notifyListeners();
  }

  void close() {
    _isOpen = false;
    notifyListeners();
  }
}

/// Tracks per-tab navigation depth so the classic bar hides on pushes.
class TabBarVisibility extends ChangeNotifier {
  final Map<int, int> _depths = {};
  void setDepth(int tab, int depth) {
    if (_depths[tab] == depth) return;
    _depths[tab] = depth;
    notifyListeners();
  }

  int depth(int tab) => _depths[tab] ?? 0;
}

/// A [NavigatorObserver] that reports the current stack depth of one tab's
/// Navigator into [TabBarVisibility] (depth 0 = root → show the tab bar).
class TabDepthObserver extends NavigatorObserver {
  TabDepthObserver(this.tab, this.visibility);
  final int tab;
  final TabBarVisibility visibility;
  int _depth = 0;

  void _report() => WidgetsBinding.instance.addPostFrameCallback(
    (_) => visibility.setDepth(tab, _depth),
  );

  @override
  void didPush(Route route, Route? previousRoute) {
    // The Navigator's initial (root) route has no previousRoute — don't count it,
    // so depth 0 = at root (tab bar visible).
    if (route is PageRoute && previousRoute != null) _depth++;
    _report();
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    if (route is PageRoute && _depth > 0) _depth--;
    _report();
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    if (route is PageRoute && _depth > 0) _depth--;
    _report();
  }
}
