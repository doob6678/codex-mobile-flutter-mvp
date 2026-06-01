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
  int _selectedIndex = 0;

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
      backgroundColor: Colors.white,
      drawer: _AppDrawer(
        selectedIndex: _selectedIndex,
        destinations: destinations,
        onSelected: (index) {
          Navigator.of(context).pop();
          _select(index);
        },
      ),
      body: SafeArea(child: screens[_selectedIndex]),
    );
  }

  void _select(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  List<_Destination> _destinations() {
    return const [
      _Destination(
        icon: Icon(Icons.link),
        selectedIcon: Icon(Icons.link_rounded),
        label: '配对',
      ),
      _Destination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: '概览',
      ),
      _Destination(
        icon: Icon(Icons.folder_outlined),
        selectedIcon: Icon(Icons.folder),
        label: '项目',
      ),
      _Destination(
        icon: Icon(Icons.description_outlined),
        selectedIcon: Icon(Icons.description),
        label: '文件',
      ),
      _Destination(
        icon: Icon(Icons.chat_bubble_outline),
        selectedIcon: Icon(Icons.chat_bubble),
        label: '对话',
      ),
      _Destination(
        icon: Icon(Icons.verified_user_outlined),
        selectedIcon: Icon(Icons.verified_user),
        label: '审批',
      ),
      _Destination(
        icon: Icon(Icons.track_changes_outlined),
        selectedIcon: Icon(Icons.track_changes),
        label: '目标',
      ),
      _Destination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: '设置',
      ),
    ];
  }
}

class _Destination {
  const _Destination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final Icon icon;
  final Icon selectedIcon;
  final String label;
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer({
    required this.selectedIndex,
    required this.destinations,
    required this.onSelected,
  });

  final int selectedIndex;
  final List<_Destination> destinations;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Drawer(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      width: width < 360 ? width - 24 : 300,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: ListTile(
              leading: const Icon(Icons.phone_iphone),
              title: const Text('Codex Mobile'),
              subtitle: const Text('Windows Bridge 同步'),
              trailing: IconButton(
                tooltip: '关闭菜单',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: destinations.length,
              itemBuilder: (context, index) {
                final destination = destinations[index];
                final selected = selectedIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    selected: selected,
                    selectedTileColor: const Color(0xFFF3F4F6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    leading: IconTheme(
                      data: IconThemeData(
                        color: selected
                            ? const Color(0xFF111827)
                            : const Color(0xFF6B7280),
                      ),
                      child:
                          selected ? destination.selectedIcon : destination.icon,
                    ),
                    title: Text(
                      destination.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? const Color(0xFF111827)
                            : const Color(0xFF4B5563),
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    onTap: () => onSelected(index),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
