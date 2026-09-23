import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/responsive.dart';

class MainScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  
  const MainScaffold({super.key, required this.navigationShell});

  void _onItemTapped(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = navigationShell.currentIndex;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= Responsive.mobileMaxWidth) {
          // Tablet / Desktop layout with NavigationRail
          return Scaffold(
            backgroundColor: const Color(0xFFFAFAF8),
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: currentIndex,
                  onDestinationSelected: _onItemTapped,
                  backgroundColor: Colors.white,
                  selectedIconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
                  unselectedIconTheme: const IconThemeData(color: Color(0xFF6B6B6B)),
                  selectedLabelTextStyle: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 12),
                  unselectedLabelTextStyle: const TextStyle(color: Color(0xFF6B6B6B), fontWeight: FontWeight.normal, fontSize: 12),
                  labelType: NavigationRailLabelType.all,
                  elevation: 1,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: Text('HOME'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.diamond_outlined),
                      selectedIcon: Icon(Icons.diamond),
                      label: Text('STOCK'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.cancel_outlined),
                      selectedIcon: Icon(Icons.cancel),
                      label: Text('REJECTION'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.history_outlined),
                      selectedIcon: Icon(Icons.history),
                      label: Text('HISTORY'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: Text('PROFILE'),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1, color: Color(0xFFE5E5E5)),
                Expanded(child: navigationShell),
              ],
            ),
          );
        }

        // Mobile layout with BottomNavigationBar
        return Scaffold(
          backgroundColor: const Color(0xFFFAFAF8),
          body: navigationShell,
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Color(0xFFE5E5E5),
                  width: 1.0,
                ),
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: currentIndex,
              onTap: _onItemTapped,
              backgroundColor: Colors.white,
              selectedItemColor: const Color(0xFFD4AF37),
              unselectedItemColor: const Color(0xFF6B6B6B),
              showSelectedLabels: true,
              showUnselectedLabels: true,
              type: BottomNavigationBarType.fixed,
              elevation: 0,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'HOME',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.diamond_outlined),
                  activeIcon: Icon(Icons.diamond),
                  label: 'STOCK',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.cancel_outlined),
                  activeIcon: Icon(Icons.cancel),
                  label: 'REJECTION',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.history_outlined),
                  activeIcon: Icon(Icons.history),
                  label: 'HISTORY',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'PROFILE',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
