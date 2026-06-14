// lib/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../theme/tea_theme.dart';
import 'home_screen.dart';
import 'capture_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  final int startingIndex;
  const MainScreen({super.key, this.startingIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _selectedIndex;

  final List<Widget> _screens = [
    const HomeScreen(),
    CaptureScreen(),
    const HistoryScreen(),
    const ProfileScreen(),
  ];

  static const _navIcons = <IconData>[
    Icons.home_rounded,
    Icons.camera_alt_rounded,
    Icons.insights_rounded,
    Icons.person_rounded,
  ];

  String _navLabel(AppLocalizations l, int i) =>
      [l.navHome, l.navCapture, l.navHistory, l.navProfile][i];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.startingIndex;
  }

  void _onTap(int idx) {
    if (idx == _selectedIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = idx);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TeaTheme.bgTop,
      extendBody: true,
      // IndexedStack keeps each tab's state alive when switching.
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildNavBar() {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: TeaTheme.border),
          boxShadow: [
            BoxShadow(
              color: TeaTheme.deep.withOpacity(0.13),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(_navIcons.length, _buildNavItem),
        ),
      ),
    );
  }

  Widget _buildNavItem(int i) {
    final icon = _navIcons[i];
    final label = _navLabel(AppLocalizations.of(context), i);
    final active = _selectedIndex == i;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onTap(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: active ? 16 : 13,
          vertical: 11,
        ),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [TeaTheme.primary, TeaTheme.mid],
                )
              : null,
          borderRadius: BorderRadius.circular(18),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: TeaTheme.primary.withOpacity(0.33),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: active ? Colors.white : const Color(0xFF9AA5A0),
              size: 23,
            ),
            // Label animates in only for the active tab.
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              child: active
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 0.2,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
