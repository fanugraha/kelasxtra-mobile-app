import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/navigation_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../akun/presentation/screens/akun_screen.dart';
import '../../../beranda/presentation/screens/beranda_screen.dart';
import '../../../katalog/presentation/screens/latihan_screen.dart';
import '../../../leaderboard/presentation/screens/leaderboard_screen.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const _screens = [
    BerandaScreen(),
    LatihanScreen(),
    LeaderboardScreen(),
    AkunScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(selectedTabIndexProvider);

    return Scaffold(
      body: IndexedStack(index: index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) =>
            ref.read(selectedTabIndexProvider.notifier).state = i,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.brand500.withOpacity(0.12),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppColors.brand500),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_note_outlined),
            selectedIcon: Icon(Icons.edit_note, color: AppColors.brand500),
            label: 'Latihan',
          ),
          NavigationDestination(
            icon: Icon(Icons.leaderboard_outlined),
            selectedIcon: Icon(Icons.leaderboard, color: AppColors.brand500),
            label: 'Peringkat',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppColors.brand500),
            label: 'Akun',
          ),
        ],
      ),
    );
  }
}
