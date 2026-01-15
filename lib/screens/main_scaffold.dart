import 'package:flutter/material.dart';
//import 'package:google_fonts/google_fonts.dart'; // Optionnel pour le style
import 'home/home_screen.dart';
import 'menu/menu_screen.dart';
import 'profile/profile_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  // Liste des 3 écrans
  final List<Widget> _pages = [
    const HomeScreen(),   // Index 0
    const MenuScreen(),   // Index 1 (Milieu)
    const ProfileScreen() // Index 2
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar( // Material 3 style
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.fastfood_outlined), // Icône Burger
            selectedIcon: Icon(Icons.fastfood),
            label: 'Produit',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}