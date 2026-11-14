import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';

class ShellDestination {
  const ShellDestination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Bottom-navigation scaffold for each role (navigation rail on tablets).
class RoleShell extends StatelessWidget {
  const RoleShell({super.key, required this.shell, required this.destinations});

  final StatefulNavigationShell shell;
  final List<ShellDestination> destinations;

  static const owner = [
    ShellDestination('Dashboard', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded),
    ShellDestination('Sales', Icons.receipt_long_outlined, Icons.receipt_long_rounded),
    ShellDestination('Team', Icons.groups_2_outlined, Icons.groups_2_rounded),
    ShellDestination('Customers', Icons.people_outline_rounded, Icons.people_rounded),
    ShellDestination('More', Icons.tune_rounded, Icons.tune_rounded),
  ];

  static const manager = [
    ShellDestination('Home', Icons.storefront_outlined, Icons.storefront_rounded),
    ShellDestination('Bills', Icons.receipt_long_outlined, Icons.receipt_long_rounded),
    ShellDestination('Customers', Icons.people_outline_rounded, Icons.people_rounded),
    ShellDestination('Sarees', Icons.checkroom_outlined, Icons.checkroom_rounded),
    ShellDestination('More', Icons.tune_rounded, Icons.tune_rounded),
  ];

  static const salesperson = [
    ShellDestination('My Sales', Icons.insights_outlined, Icons.insights_rounded),
    ShellDestination('History', Icons.receipt_long_outlined, Icons.receipt_long_rounded),
    ShellDestination('Profile', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  void _go(int i) => shell.goBranch(i, initialLocation: i == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              backgroundColor: AppColors.card,
              selectedIndex: shell.currentIndex,
              onDestinationSelected: _go,
              labelType: NavigationRailLabelType.all,
              indicatorColor: AppColors.goldPale,
              selectedIconTheme: const IconThemeData(color: AppColors.maroon),
              unselectedIconTheme: const IconThemeData(color: AppColors.inkSoft),
              selectedLabelTextStyle: const TextStyle(color: AppColors.maroon, fontWeight: FontWeight.w600, fontSize: 12),
              unselectedLabelTextStyle: const TextStyle(color: AppColors.inkMuted, fontSize: 12),
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: Text(d.label)),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: shell),
          ],
        ),
      );
    }
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: _go,
          destinations: [
            for (final d in destinations)
              NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label),
          ],
        ),
      ),
    );
  }
}
