import 'package:flutter/material.dart';

import '../api/codex_mobile_api.dart';
import 'approvals_screen.dart';
import 'conversations_screen.dart';
import 'dashboard_screen.dart';
import 'file_manager_screen.dart';
import 'goals_screen.dart';
import 'pairing_screen.dart';
import 'projects_screen.dart';
import 'settings_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({required this.api, super.key});

  final CodexMobileApi api;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 1;

  @override
  Widget build(BuildContext context) {
    final destinations = _destinations();
    final screens = [
      PairingScreen(api: widget.api),
      DashboardScreen(api: widget.api, onNavigate: _select),
      ProjectsScreen(api: widget.api),
      FileManagerScreen(api: widget.api),
      ConversationsScreen(api: widget.api),
      ApprovalsScreen(api: widget.api),
      GoalsScreen(api: widget.api),
      SettingsScreen(api: widget.api),
    ];

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              extended: MediaQuery.sizeOf(context).width >= 720,
              selectedIndex: _selectedIndex,
              onDestinationSelected: _select,
              labelType: MediaQuery.sizeOf(context).width >= 720
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              destinations: destinations,
            ),
            const VerticalDivider(width: 1),
            Expanded(child: screens[_selectedIndex]),
          ],
        ),
      ),
    );
  }

  void _select(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  List<NavigationRailDestination> _destinations() {
    return const [
      NavigationRailDestination(
        icon: Icon(Icons.link),
        selectedIcon: Icon(Icons.link_rounded),
        label: Text('Pairing'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: Text('Dashboard'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.folder_outlined),
        selectedIcon: Icon(Icons.folder),
        label: Text('Projects'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.description_outlined),
        selectedIcon: Icon(Icons.description),
        label: Text('Files'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.chat_bubble_outline),
        selectedIcon: Icon(Icons.chat_bubble),
        label: Text('Conversations'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.verified_user_outlined),
        selectedIcon: Icon(Icons.verified_user),
        label: Text('Approvals'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.track_changes_outlined),
        selectedIcon: Icon(Icons.track_changes),
        label: Text('Goals'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: Text('Settings'),
      ),
    ];
  }
}
