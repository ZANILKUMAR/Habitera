import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/habit_provider.dart';
import '../services/notification_service.dart';
import 'today_screen.dart';
import 'calendar_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;
  bool _remindersRescheduled = false;

  @override
  void initState() {
    super.initState();
    // Reschedule all reminders on app start
    _rescheduleReminders();
  }

  Future<void> _rescheduleReminders() async {
    if (_remindersRescheduled) return;
    _remindersRescheduled = true;
    
    // Wait a bit for providers to initialize
    await Future.delayed(const Duration(milliseconds: 500));
    
    try {
      final habits = await ref.read(habitsProvider.future);
      await NotificationService().rescheduleAllReminders(habits);
    } catch (e) {
      debugPrint('Error rescheduling reminders: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the refresh provider to rebuild screens when data is cleared
    final refreshKey = ref.watch(dataRefreshProvider);
    
    // Create screens with key so they rebuild when data changes
    final screens = [
      TodayScreen(key: ValueKey('today_$refreshKey')),
      CalendarScreen(key: ValueKey('calendar_$refreshKey')),
      const SettingsScreen(),
    ];
    
    return Scaffold(
      // Use IndexedStack to keep screens alive when switching tabs
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
