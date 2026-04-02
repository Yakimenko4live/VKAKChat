import 'package:flutter/material.dart';
import '../widgets/chat_list_widget.dart';
import '../widgets/favorites_widget.dart';
import '../widgets/search_widget.dart';
import '../widgets/profile_widget.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const ChatListWidget(),
    const FavoritesWidget(),
    const SearchWidget(),
    const ProfileWidget(),
  ];

  @override
  Widget build(BuildContext context) {
    // Убираем Center и Column, которые могли сжимать Scaffold, 
    // используем прозрачный Scaffold как основной каркас.
    return Scaffold(
      backgroundColor: Colors.transparent, // Важно для видимости фона
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                decoration: BoxDecoration(
                  // Полупрозрачный темный фон для эффекта стекла
                  color: Colors.black.withOpacity(0.4), 
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.green.withOpacity(0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.05, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: _pages[_selectedIndex],
                  ),
                ),
              ),
            ),
            // Нижняя панель навигации
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.green.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.transparent,
                selectedItemColor: Colors.green,
                unselectedItemColor: Colors.white54,
                elevation: 0,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.chat_bubble_outline),
                    activeIcon: Icon(Icons.chat_bubble),
                    label: 'Чаты',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.star_border),
                    activeIcon: Icon(Icons.star),
                    label: 'Избранное',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.search),
                    label: 'Поиск',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline),
                    activeIcon: Icon(Icons.person),
                    label: 'Профиль',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}