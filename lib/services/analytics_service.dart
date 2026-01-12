import '../models/habit.dart';
import '../services/database_service.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  final DatabaseService _db = DatabaseService();

  AnalyticsService._internal();

  factory AnalyticsService() {
    return _instance;
  }

  Future<HabitStreak> getStreaks(String habitId) async {
    final completions = await _db.getCompletionsForHabit(habitId);
    final habit = await _db.getHabitById(habitId);

    if (habit == null) {
      return HabitStreak(habitId: habitId, current: 0, longest: 0);
    }

    final sorted = List.from(completions);
    sorted.sort((a, b) => b.date.compareTo(a.date));

    int current = 0;
    int longest = 0;

    // Calculate current streak
    if (sorted.isNotEmpty) {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final lastCompletionDate = DateTime(
        sorted.first.date.year,
        sorted.first.date.month,
        sorted.first.date.day,
      );

      if (_isSameDay(lastCompletionDate, today) ||
          _isSameDay(lastCompletionDate, yesterday)) {
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
    }

    // Calculate longest streak
    final sortedAsc = List.from(completions);
    sortedAsc.sort((a, b) => a.date.compareTo(b.date));

    for (int i = 0; i < sortedAsc.length; i++) {
      int streak = 1;

      for (int j = i + 1; j < sortedAsc.length; j++) {
        final diff = sortedAsc[j]
            .date
            .difference(DateTime(
              sortedAsc[j - 1].date.year,
              sortedAsc[j - 1].date.month,
              sortedAsc[j - 1].date.day,
            ))
            .inDays;

        if (diff == 1) {
          streak++;
        } else {
          break;
        }
      }

      if (streak > longest) {
        longest = streak;
      }
    }

    return HabitStreak(
      habitId: habitId,
      current: current,
      longest: longest,
      lastCompletionDate:
          sorted.isNotEmpty ? sorted.first.date : null,
    );
  }

  Future<DailyStats> getDailyStats(DateTime date) async {
    final habits = await _db.getAllHabits();
    final completions = await _db.getCompletionsForDate(date);

    final total = habits.length;
    final completed = completions.length;
    final percentage = total > 0 ? (completed / total) * 100.0 : 0.0;

    return DailyStats(
      date: date,
      totalHabits: total,
      completedHabits: completed,
      percentage: percentage,
    );
  }

  Future<Map<String, dynamic>> getWeeklyStats() async {
    final habits = await _db.getAllHabits();
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));

    int totalCompletions = 0;
    int totalDaysNeeded = 0;

    for (int i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      if (date.isBefore(now) || _isSameDay(date, now)) {
        final completions = await _db.getCompletionsForDate(date);
        totalCompletions += completions.length;
        totalDaysNeeded += habits.length;
      }
    }

    final percentage =
        totalDaysNeeded > 0 ? (totalCompletions / totalDaysNeeded) * 100 : 0;

    return {
      'week': (now.day / 7).ceil(),
      'year': now.year,
      'completionPercentage': percentage,
      'daysCompletedCount': totalCompletions,
    };
  }

  Future<Map<String, dynamic>> getMonthlyStats() async {
    final habits = await _db.getAllHabits();
    final now = DateTime.now();

    int totalCompletions = 0;
    int totalDaysNeeded = 0;

    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);

    DateTime current = firstDay;
    while (current.isBefore(lastDay) || _isSameDay(current, lastDay)) {
      if (current.isBefore(now) || _isSameDay(current, now)) {
        final completions = await _db.getCompletionsForDate(current);
        totalCompletions += completions.length;
        totalDaysNeeded += habits.length;
      }
      current = current.add(const Duration(days: 1));
    }

    final percentage =
        totalDaysNeeded > 0 ? (totalCompletions / totalDaysNeeded) * 100 : 0;

    return {
      'month': now.month,
      'year': now.year,
      'completionPercentage': percentage,
      'daysCompletedCount': totalCompletions,
    };
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}
