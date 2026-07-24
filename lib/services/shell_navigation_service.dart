import 'package:flutter/widgets.dart';

enum ShellTab { home, library, repository, settings }

class ShellNavigationService {
  static final GlobalKey<NavigatorState> homeTabNavigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> libraryTabNavigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> repoTabNavigatorKey =
      GlobalKey<NavigatorState>();

  static int _currentTabIndex = 0;
  static bool _showRepoTab = false;
  static Object? _tabSelectionOwner;
  static ValueChanged<ShellTab>? _tabSelectionHandler;

  static void registerTabSelectionHandler({
    required Object owner,
    required ValueChanged<ShellTab> handler,
  }) {
    _tabSelectionOwner = owner;
    _tabSelectionHandler = handler;
  }

  static void unregisterTabSelectionHandler(Object owner) {
    if (!identical(_tabSelectionOwner, owner)) return;
    _tabSelectionOwner = null;
    _tabSelectionHandler = null;
  }

  static bool requestTab(ShellTab tab) {
    final handler = _tabSelectionHandler;
    if (handler == null) return false;
    handler(tab);
    return true;
  }

  static void syncState({
    required int currentTabIndex,
    required bool showRepoTab,
  }) {
    _currentTabIndex = currentTabIndex;
    _showRepoTab = showRepoTab;
  }

  static NavigatorState? activeTabNavigator() {
    if (_currentTabIndex == 0) return homeTabNavigatorKey.currentState;
    if (_currentTabIndex == 1) return libraryTabNavigatorKey.currentState;
    if (_showRepoTab && _currentTabIndex == 2) {
      return repoTabNavigatorKey.currentState;
    }
    return null;
  }
}
