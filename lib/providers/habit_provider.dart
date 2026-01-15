import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/habit.dart';
import '../models/settings.dart';
import '../services/database_service.dart';

final databaseProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

/// Provider to track data refresh - increment to force UI rebuild
final dataRefreshProvider = StateProvider<int>((ref) => 0);

/// Provider for app settings, automatically refreshes when settings change
final settingsProvider = FutureProvider<AppSettings>((ref) async {
  // Watch refresh provider to trigger reload when data is cleared
  ref.watch(dataRefreshProvider);
  final db = ref.watch(databaseProvider);
  return db.getSettings();
});

/// Provider specifically for notePromptOnTap setting for quick access
final notePromptOnTapProvider = FutureProvider<bool>((ref) async {
  final settings = await ref.watch(settingsProvider.future);
  return settings.notePromptOnTap;
});

final habitsProvider = FutureProvider<List<Habit>>((ref) async {
  // Watch refresh provider to trigger reload when data is cleared
  ref.watch(dataRefreshProvider);
  final db = ref.watch(databaseProvider);
  return db.getAllHabits();
});

final completionStateProvider =
    FutureProvider.family<bool, String>((ref, habitId) async {
  ref.watch(dataRefreshProvider);
  final db = ref.watch(databaseProvider);
  return db.isCompletedToday(habitId);
});

final dailyStatsProvider = FutureProvider((ref) async {
  ref.watch(dataRefreshProvider);
  final db = ref.watch(databaseProvider);
  final habits = await db.getAllHabits();
  final completions = await db.getCompletionsForDate(DateTime.now());

  final total = habits.length;
  final completed = completions.length;
  final percentage = total > 0 ? (completed / total) * 100 : 0;

  return {
    'totalHabits': total,
    'completedHabits': completed,
    'percentage': percentage,
  };
});

final heatmapProvider = FutureProvider<Map<String, int>>((ref) async {
  ref.watch(dataRefreshProvider);
  final db = ref.watch(databaseProvider);
  return db.getHeatmapData(3);
});

final streaksProvider = FutureProvider.family((ref, String habitId) async {
  ref.watch(dataRefreshProvider);
  final db = ref.watch(databaseProvider);
  final completions = await db.getCompletionsForHabit(habitId);

  final sorted = List.from(completions);
  sorted.sort((a, b) => b.date.compareTo(a.date));

  int current = 0;
  int longest = 0;

  if (sorted.isNotEmpty) {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final lastCompletionDate = DateTime(
      sorted.first.date.year,
      sorted.first.date.month,
      sorted.first.date.day,
    );

    // Calculate current streak
    if ((lastCompletionDate.year == today.year &&
            lastCompletionDate.month == today.month &&
            lastCompletionDate.day == today.day) ||
        (lastCompletionDate.year == yesterday.year &&
            lastCompletionDate.month == yesterday.month &&
            lastCompletionDate.day == yesterday.day)) {
      current = 1;

      for (int i = 1; i < sorted.length; i++) {
        final prevDate = DateTime(
          sorted[i].date.year,
          sorted[i].date.month,
          sorted[i].date.day,
        );
        final currentDate = DateTime(
          sorted[i - 1].date.year,
          sorted[i - 1].date.month,
          sorted[i - 1].date.day,
        );

        final diff = currentDate.difference(prevDate).inDays;
        if (diff == 1) {
          current++;
        } else {
          break;
        }
      }
    }
    
    // Calculate longest streak
    int tempStreak = 1;
    for (int i = 1; i < sorted.length; i++) {
      final prevDate = DateTime(
        sorted[i].date.year,
        sorted[i].date.month,
        sorted[i].date.day,
      );
      final currentDate = DateTime(
        sorted[i - 1].date.year,
        sorted[i - 1].date.month,
        sorted[i - 1].date.day,
      );

      final diff = currentDate.difference(prevDate).inDays;
      if (diff == 1) {
        tempStreak++;
      } else {
        if (tempStreak > longest) {
          longest = tempStreak;
        }
        tempStreak = 1;
      }
    }
    // Check the last streak
    if (tempStreak > longest) {
      longest = tempStreak;
    }
  }

  return {'current': current, 'longest': longest};
});

/// Provider for habit completion counts within a date range
/// Returns a map of habitId -> count of unique days completed
final habitCompletionCountsProvider = FutureProvider.family<Map<String, int>, DateTime>((ref, startDate) async {
  ref.watch(dataRefreshProvider);
  final db = ref.watch(databaseProvider);
  final habits = await ref.watch(habitsProvider.future);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  
  final result = <String, int>{};
  
  for (final habit in habits) {
    final completions = await db.getCompletionsForHabit(habit.id);
    
    // Count unique days within the date range
    final uniqueDays = <String>{};
    for (final completion in completions) {
      final completionDate = DateTime(
        completion.date.year,
        completion.date.month,
        completion.date.day,
      );
      
      if (!completionDate.isBefore(startDate) && !completionDate.isAfter(today)) {
        final dateStr = '${completionDate.year}-${completionDate.month.toString().padLeft(2, '0')}-${completionDate.day.toString().padLeft(2, '0')}';
        uniqueDays.add(dateStr);
      }
    }
    
    result[habit.id] = uniqueDays.length;
  }
  
  return result;
});
