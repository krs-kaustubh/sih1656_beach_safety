// File: lib/features/shell/app_shell.dart
// Description: Main application scaffold managing tab navigation (Home, Alerts, Maps, Settings) and bottom navigation bar styling.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/risk_theme.dart';
import '../../models/risk_level.dart';
import '../../state/providers.dart';
import '../alerts/alerts_screen.dart';
import '../home/home_screen.dart';
import '../maps/maps_screen.dart';
import '../settings/settings_screen.dart';

// Root scaffold holding the four tabs and bottom navigation bar.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}


class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  static const _tabs = [
    _TabSpec(icon: Icons.home_rounded, label: 'Home'),
    _TabSpec(icon: Icons.notifications_none_rounded, label: 'Alerts'),
    _TabSpec(icon: Icons.place_outlined, label: 'Maps'),
    _TabSpec(icon: Icons.settings_outlined, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    // The nav bar is tinted by the selected beach's risk, matching the way the
    // designs restyle the whole screen.
    final level =
        ref.watch(selectedBeachProvider).value?.riskLevel ?? RiskLevel.low;
    final risk = RiskTheme.forLevel(level);
    final accent = RiskTheme.accentFor(level, onDark: risk.isDark);

    return Scaffold(
      extendBody: true,
      backgroundColor: risk.backdrop.last,
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          AlertsScreen(),
          MapsScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: risk.surface,
          border: Border(top: BorderSide(color: risk.surfaceBorder)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: _NavItem(
                      spec: _tabs[i],
                      selected: i == _index,
                      selectedColor: accent,
                      unselectedColor: risk.textSecondary,
                      onTap: () => setState(() => _index = i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.spec,
    required this.selected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
  });

  final _TabSpec spec;
  final bool selected;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? selectedColor : unselectedColor;

    return InkWell(
      onTap: onTap,
      child: Semantics(
        selected: selected,
        button: true,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(spec.icon, color: color, size: 23),
            const SizedBox(height: 3),
            Text(
              spec.label,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
