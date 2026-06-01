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
  bool _navigationOpen = false;

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
      body: SafeArea(
        child: Row(
          children: [
            Container(
              width: _navigationOpen ? 184 : 64,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  right: BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
              child: _Sidebar(
                open: _navigationOpen,
                selectedIndex: _selectedIndex,
                destinations: destinations,
                onToggle: () => setState(() {
                  _navigationOpen = !_navigationOpen;
                }),
                onSelected: (index) {
                  _select(index);
                  setState(() {
                    _navigationOpen = false;
                  });
                },
              ),
            ),
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

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.open,
    required this.selectedIndex,
    required this.destinations,
    required this.onToggle,
    required this.onSelected,
  });

  final bool open;
  final int selectedIndex;
  final List<_Destination> destinations;
  final VoidCallback onToggle;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        IconButton(
          tooltip: open ? '收起侧边栏' : '打开侧边栏',
          onPressed: onToggle,
          icon: Icon(open ? Icons.menu_open : Icons.menu),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: destinations.length,
            itemBuilder: (context, index) {
              final destination = destinations[index];
              final selected = selectedIndex == index;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: selected ? const Color(0xFFF3F4F6) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onSelected(index),
                    child: SizedBox(
                      height: 48,
                      child: open
                          ? Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                children: [
                                  IconTheme(
                                    data: IconThemeData(
                                      color: selected
                                          ? const Color(0xFF111827)
                                          : const Color(0xFF6B7280),
                                    ),
                                    child: selected
                                        ? destination.selectedIcon
                                        : destination.icon,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      destination.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: selected
                                            ? const Color(0xFF111827)
                                            : const Color(0xFF4B5563),
                                        fontWeight: selected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Center(
                              child: IconTheme(
                                data: IconThemeData(
                                  color: selected
                                      ? const Color(0xFF111827)
                                      : const Color(0xFF6B7280),
                                ),
                                child: selected
                                    ? destination.selectedIcon
                                    : destination.icon,
                              ),
                            ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
