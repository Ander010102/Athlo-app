import 'package:flutter/material.dart';
import 'home_feed_page.dart';
import 'search_page.dart';
import 'saved_communities_page.dart';
import 'profile_page.dart';

class MainNavigation extends StatefulWidget {
  final int currentIndex;
  final Widget? child; // <- adicionamos isso

  const MainNavigation({
    super.key,
    this.currentIndex = 0,
    this.child,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late int _selectedIndex;

  final List<Widget> _pages = [
    const HomeFeedPage(),
    const SearchPage(),
    const SavedCommunitiesPage(),
    const ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.currentIndex;
  }

  void _onItemTapped(int index) {
    if (widget.child != null) {
      // se há uma tela filha (como CommunityDetailPage),
      // substitui por um MainNavigation "limpo" na aba clicada
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => MainNavigation(currentIndex: index),
        ),
        (route) => false,
      );
    } else {
      // troca de aba normalmente
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child ?? _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.black,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark_border), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: ''),
        ],
      ),
    );
  }
}
