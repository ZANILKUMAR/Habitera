import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/habit.dart';
import '../services/database_service.dart';

final databaseProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

final habitsProvider = FutureProvider<List<Habit>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getAllHabits();
});

final completionStateProvider =
    FutureProvider.family<bool, String>((ref, habitId) async {
  final db = ref.watch(databaseProvider);
  return db.isCompletedToday(habitId);
});

final dailyStatsProvider = FutureProvider((ref) async {
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
  final db = ref.watch(databaseProvider);
  return db.getHeatmapData(3);
});

final streaksProvider = FutureProvider.family((ref, String habitId) async {
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
