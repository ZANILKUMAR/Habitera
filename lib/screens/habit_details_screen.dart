import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/habit.dart';
import '../providers/habit_provider.dart';
import '../services/database_service.dart';
import 'add_habit_screen.dart';

class HabitDetailsScreen extends ConsumerStatefulWidget {
  final String habitId;

  const HabitDetailsScreen({super.key, required this.habitId});

  @override
  ConsumerState<HabitDetailsScreen> createState() => _HabitDetailsScreenState();
}

class _HabitDetailsScreenState extends ConsumerState<HabitDetailsScreen> {
  final DatabaseService _db = DatabaseService();
  Habit? _habit;
  List<Completion> _completions = [];
  bool _isLoading = true;
  bool _notePromptOnTap = false; // Setting for tap behavior

  // Stats
  int _currentStreak = 0;
  int _longestStreak = 0;
  double _consistencyScore = 0;
  int _totalCompletions = 0;
  int _thisWeekCompletions = 0;
  int _thisMonthCompletions = 0;

  // History stats
  int _lastWeekCompletions = 0;
  int _thisQuarterCompletions = 0;
  int _thisYearCompletions = 0;
  List<int> _weeklyFrequency = [0, 0, 0, 0, 0, 0, 0]; // Mon-Sun

  // Calendar state
  Set<DateTime> _completionDates = {};
  Set<String> _completionDatesWithNotes =
      {}; // Dates with notes in 'yyyy-MM-dd' format

  /// Determines if a date shows a "fulfilled" state for frequency-based habits
  /// Returns: true if the frequency goal has been met and this day is in the fulfilled window
  /// Fulfilled = goal achieved, remaining days in period show subtle "done" indication
  bool _isFulfilledDay(DateTime date, Set<String> completionDates) {
    if (_habit == null) return false;
    
    final today = DateTime.now();
    final dateOnly = DateTime(date.year, date.month, date.day);
    final todayOnly = DateTime(today.year, today.month, today.day);
    
    // Don't show fulfilled state for future dates
    if (dateOnly.isAfter(todayOnly)) return false;
    
    // Don't show on days that are already completed
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    if (completionDates.contains(dateStr)) return false;
    
    switch (_habit!.frequency) {
      case HabitFrequency.daily:
        // Daily habits - no fulfilled state (every day needs completion)
        return false;
        
      case HabitFrequency.everyXDays:
        // Every X days - show fulfilled for remaining days in current cycle after completion
        final interval = _habit!.customDays ?? 2;
        
        // Find the most recent completion before or on this date
        DateTime? lastCompletionBeforeOrOn;
        for (final cDateStr in completionDates) {
          final d = DateTime.parse(cDateStr);
          final dOnly = DateTime(d.year, d.month, d.day);
          if (!dOnly.isAfter(dateOnly)) {
            if (lastCompletionBeforeOrOn == null || dOnly.isAfter(lastCompletionBeforeOrOn)) {
              lastCompletionBeforeOrOn = dOnly;
            }
          }
        }
        
        if (lastCompletionBeforeOrOn == null) {
          return false; // No completion yet - not fulfilled
        }
        
        // This date is fulfilled if it's after the completion but before the next due date
        final daysSinceCompletion = dateOnly.difference(lastCompletionBeforeOrOn).inDays;
        return daysSinceCompletion > 0 && daysSinceCompletion < interval;
        
      case HabitFrequency.timesPerWeek:
        // X times per week - show fulfilled when weekly goal is met
        final required = _habit!.customDays ?? 3;
        
        // Get the week containing this date
        final weekStart = dateOnly.subtract(Duration(days: dateOnly.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 6));
        
        // Count completions in this week
        int weekCompletions = 0;
        for (final cDateStr in completionDates) {
          final d = DateTime.parse(cDateStr);
          final dOnly = DateTime(d.year, d.month, d.day);
          if (!dOnly.isBefore(weekStart) && !dOnly.isAfter(weekEnd)) {
            weekCompletions++;
          }
        }
        
        // Show fulfilled if weekly target is met
        return weekCompletions >= required;
        
      case HabitFrequency.timesPerMonth:
        // X times per month - show fulfilled when monthly goal is met
        final required = _habit!.customDays ?? 10;
        
        // Count completions in this month
        int monthCompletions = 0;
        for (final cDateStr in completionDates) {
          final d = DateTime.parse(cDateStr);
          if (d.year == dateOnly.year && d.month == dateOnly.month) {
            monthCompletions++;
          }
        }
        
        // Show fulfilled if monthly target is met
        return monthCompletions >= required;
        
      case HabitFrequency.specificDays:
        // Specific days - show fulfilled when all selected days in the week are completed
        final selectedDaysMask = _habit!.customDays ?? 0;
        
        // Get the week containing this date
        final weekStart = dateOnly.subtract(Duration(days: dateOnly.weekday - 1));
        
        // Check if this day is one of the selected days - if so, no fulfilled state
        final dayIndex = (dateOnly.weekday - 1) % 7; // 0 = Monday
        if ((selectedDaysMask & (1 << dayIndex)) != 0) {
          return false; // This is a required day, not a "rest" day
        }
        
        // Count how many selected days are in a week and how many are completed
        int requiredDaysInWeek = 0;
        int completedRequiredDays = 0;
        
        for (int i = 0; i < 7; i++) {
          if ((selectedDaysMask & (1 << i)) != 0) {
            requiredDaysInWeek++;
            // Check if this day is completed
            final dayDate = weekStart.add(Duration(days: i));
            final dayDateStr = DateFormat('yyyy-MM-dd').format(dayDate);
            if (completionDates.contains(dayDateStr)) {
              completedRequiredDays++;
            }
          }
        }
        
        // Show fulfilled if all required days in the week are completed
        return requiredDaysInWeek > 0 && completedRequiredDays >= requiredDaysInWeek;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _db.getSettings();
      if (mounted) {
        setState(() {
          _notePromptOnTap = settings.notePromptOnTap;
        });
      }
    } catch (e) {
      // Use default if error
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final habit = await _db.getHabitById(widget.habitId);
    if (habit == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final completions = await _db.getCompletionsForHabit(widget.habitId);

    // Calculate stats
    _calculateStats(habit, completions);

    if (mounted) {
      setState(() {
        _habit = habit;
        _completions = completions;
        _isLoading = false;
      });
    }
  }

  void _calculateStats(Habit habit, List<Completion> completions) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Sort completions by date descending
    final sorted = List<Completion>.from(completions);
    sorted.sort((a, b) => b.date.compareTo(a.date));

    // Total completions
    _totalCompletions = completions.length;

    // This week completions
    final weekStart = today.subtract(Duration(days: today.weekday % 7));
    _thisWeekCompletions = completions.where((c) {
      final date = DateTime(c.date.year, c.date.month, c.date.day);
      return date.isAfter(weekStart.subtract(const Duration(days: 1)));
    }).length;

    // This month completions
    final monthStart = DateTime(now.year, now.month, 1);
    _thisMonthCompletions = completions.where((c) {
      final date = DateTime(c.date.year, c.date.month, c.date.day);
      return date.isAfter(monthStart.subtract(const Duration(days: 1)));
    }).length;

    // Current streak
    _currentStreak = _calculateCurrentStreak(sorted, today);

    // Longest streak
    _longestStreak = _calculateLongestStreak(sorted);

    // Consistency score (last 30 days)
    final thirtyDaysAgo = today.subtract(const Duration(days: 30));
    final last30DaysCompletions = completions.where((c) {
      final date = DateTime(c.date.year, c.date.month, c.date.day);
      return date.isAfter(thirtyDaysAgo);
    }).length;

    // Expected completions based on frequency
    int expectedCompletions = 30; // Default for daily
    switch (habit.frequency) {
      case HabitFrequency.daily:
        expectedCompletions = 30;
        break;
      case HabitFrequency.everyXDays:
        expectedCompletions = (30 / (habit.customDays ?? 2)).round();
        break;
      case HabitFrequency.timesPerWeek:
        expectedCompletions = ((habit.customDays ?? 3) * 4.3).round();
        break;
      case HabitFrequency.timesPerMonth:
        expectedCompletions = habit.customDays ?? 10;
        break;
      case HabitFrequency.specificDays:
        // Count bits set in bitmask
        int daysCount = 0;
        int mask = habit.customDays ?? 0;
        while (mask > 0) {
          daysCount += mask & 1;
          mask >>= 1;
        }
        expectedCompletions = (daysCount * 4.3).round();
        break;
    }

    _consistencyScore = expectedCompletions > 0
        ? (last30DaysCompletions / expectedCompletions * 100).clamp(0, 100)
        : 0;

    // Build completion dates set for calendar
    _completionDates = completions
        .map((c) => DateTime(c.date.year, c.date.month, c.date.day))
        .toSet();

    // Build set of dates that have notes
    _completionDatesWithNotes = completions
        .where((c) => c.notes != null && c.notes!.isNotEmpty)
        .map((c) => DateFormat('yyyy-MM-dd').format(c.date))
        .toSet();

    // Last week completions
    final lastWeekStart = weekStart.subtract(const Duration(days: 7));
    _lastWeekCompletions = completions.where((c) {
      final date = DateTime(c.date.year, c.date.month, c.date.day);
      return date.isAfter(lastWeekStart.subtract(const Duration(days: 1))) &&
          date.isBefore(weekStart);
    }).length;

    // This quarter completions
    final quarterMonth = ((now.month - 1) ~/ 3) * 3 + 1;
    final quarterStart = DateTime(now.year, quarterMonth, 1);
    _thisQuarterCompletions = completions.where((c) {
      final date = DateTime(c.date.year, c.date.month, c.date.day);
      return date.isAfter(quarterStart.subtract(const Duration(days: 1)));
    }).length;

    // This year completions
    final yearStart = DateTime(now.year, 1, 1);
    _thisYearCompletions = completions.where((c) {
      final date = DateTime(c.date.year, c.date.month, c.date.day);
      return date.isAfter(yearStart.subtract(const Duration(days: 1)));
    }).length;

    // Weekly frequency (which days are most common) - last 12 weeks
    _weeklyFrequency = [0, 0, 0, 0, 0, 0, 0];
    final twelveWeeksAgo = today.subtract(const Duration(days: 84));
    for (var c in completions) {
      final date = DateTime(c.date.year, c.date.month, c.date.day);
      if (date.isAfter(twelveWeeksAgo)) {
        final dayIndex = (date.weekday - 1) % 7; // 0 = Monday
        _weeklyFrequency[dayIndex]++;
      }
    }
  }

  int _calculateCurrentStreak(List<Completion> sorted, DateTime today) {
    if (sorted.isEmpty) return 0;

    final yesterday = today.subtract(const Duration(days: 1));
    final lastDate = DateTime(
      sorted.first.date.year,
      sorted.first.date.month,
      sorted.first.date.day,
    );

    // Check if last completion is today or yesterday
    final isRecent = (lastDate.year == today.year &&
            lastDate.month == today.month &&
            lastDate.day == today.day) ||
        (lastDate.year == yesterday.year &&
            lastDate.month == yesterday.month &&
            lastDate.day == yesterday.day);

    if (!isRecent) return 0;

    int streak = 1;
    for (int i = 1; i < sorted.length; i++) {
      final prevDate = DateTime(
        sorted[i].date.year,
        sorted[i].date.month,
        sorted[i].date.day,
      );
      final currDate = DateTime(
        sorted[i - 1].date.year,
        sorted[i - 1].date.month,
        sorted[i - 1].date.day,
      );

      if (currDate.difference(prevDate).inDays == 1) {
        streak++;
      } else {
        break;
      }
    }

    return streak;
  }

  int _calculateLongestStreak(List<Completion> sorted) {
    if (sorted.isEmpty) return 0;

    // Sort ascending for longest streak calculation
    final ascending = List<Completion>.from(sorted);
    ascending.sort((a, b) => a.date.compareTo(b.date));

    int longest = 1;
    int current = 1;

    for (int i = 1; i < ascending.length; i++) {
      final prevDate = DateTime(
        ascending[i - 1].date.year,
        ascending[i - 1].date.month,
        ascending[i - 1].date.day,
      );
      final currDate = DateTime(
        ascending[i].date.year,
        ascending[i].date.month,
        ascending[i].date.day,
      );

      if (currDate.difference(prevDate).inDays == 1) {
        current++;
        if (current > longest) longest = current;
      } else if (currDate.difference(prevDate).inDays > 1) {
        current = 1;
      }
    }

    return longest;
  }

  void _onEdit() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => AddHabitScreen(habitId: widget.habitId),
          ),
        )
        .then((_) => _loadData());
  }

  Future<void> _onDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Habit?'),
        content: Text(
          'Are you sure you want to delete "${_habit?.title}"?\n\n'
          'This will remove all $_totalCompletions completion records. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _db.deleteHabit(widget.habitId);
      ref.invalidate(habitsProvider);
      ref.invalidate(dailyStatsProvider);
      ref.invalidate(heatmapProvider);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_habit == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Habit not found')),
      );
    }

    final habit = _habit!;
    final habitColor = _parseColor(habit.color);

    return Scaffold(
      appBar: AppBar(
        title: Text(habit.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _onEdit,
            tooltip: 'Edit Habit',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              _buildHeaderCard(habit, habitColor, theme, isDark),
              const SizedBox(height: 20),

              // Schedule Section
              _buildFrequencySection(habit, theme, isDark),
              const SizedBox(height: 20),

              // Completion History Section
              _buildHistoryStatsSection(habitColor, theme, isDark),
              const SizedBox(height: 20),

              // Calendar (Visual History)
              _buildVisualHistory(theme, isDark),
              const SizedBox(height: 20),

              // Streak Stats
              _buildStreakSection(theme, isDark),
              const SizedBox(height: 20),

              // Weekly Pattern (Frequency Chart)
              _buildFrequencyChartSection(habitColor, theme, isDark),
              const SizedBox(height: 20),

              // Frequency Dot Matrix Chart
              _buildFrequencyDotMatrixSection(habitColor, theme, isDark),
              const SizedBox(height: 20),

              // Highlights Section
              _buildHighlightsSection(theme, isDark),
              const SizedBox(height: 32),

              // Action Buttons
              _buildActionButtons(theme),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(
      Habit habit, Color habitColor, ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            habitColor.withValues(alpha: 0.15),
            habitColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: habitColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (habit.icon != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: habitColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      Text(habit.icon!, style: const TextStyle(fontSize: 28)),
                ),
              if (habit.icon != null) const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (habit.description != null &&
                        habit.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          habit.description!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Consistency Score
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  '${_consistencyScore.round()}%',
                  'Consistency',
                  Icons.trending_up_rounded,
                  habitColor,
                  theme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMiniStat(
                  '$_totalCompletions',
                  'Total Check-ins',
                  Icons.check_circle_outline_rounded,
                  habitColor,
                  theme,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  '$_thisWeekCompletions',
                  'This Week',
                  Icons.view_week_rounded,
                  habitColor,
                  theme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMiniStat(
                  '$_thisMonthCompletions',
                  'This Month',
                  Icons.calendar_month_rounded,
                  habitColor,
                  theme,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(
      String value, String label, IconData icon, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStreakSection(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Streaks',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStreakCard(
                _currentStreak,
                'Current Streak',
                '🔥',
                theme.colorScheme.primary,
                theme,
                isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStreakCard(
                _longestStreak,
                'Best Streak',
                '🏆',
                Colors.amber.shade600,
                theme,
                isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStreakCard(int days, String label, String emoji, Color color,
      ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.3),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(
            '$days',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            days == 1 ? 'day' : 'days',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildVisualHistory(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Calendar',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            TextButton(
              onPressed: () => _showEditCalendarSheet(theme, isDark),
              child: const Text('EDIT'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? theme.colorScheme.surface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.3),
            ),
          ),
          child: _buildCalendarGrid(theme, isDark),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid(ThemeData theme, bool isDark) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final completionDates = _completions
        .map((c) => DateFormat('yyyy-MM-dd').format(c.date))
        .toSet();

    final baseHabitColor = _parseColor(_habit?.color);
    final habitColor = _enhanceColorForDarkMode(baseHabitColor, isDark);
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    // Show 2 years of history (no restriction) - allows backfilling completions
    final twoYearsAgo = today.subtract(const Duration(days: 730));
    final startDate = DateTime(twoYearsAgo.year, twoYearsAgo.month, twoYearsAgo.day);

    // Adjust to start from Monday of that week
    final adjustedStart =
        startDate.subtract(Duration(days: (startDate.weekday - 1) % 7));

    // Calculate weeks to show
    final daysDiff = today.difference(adjustedStart).inDays;
    final numWeeks = (daysDiff / 7).ceil() + 1;

    // Build week columns with dates
    List<Widget> weekColumns = [];

    // Find unique months to display
    Map<int, String> monthHeaders = {};
    for (int week = 0; week < numWeeks; week++) {
      final weekStart = adjustedStart.add(Duration(days: week * 7));
      if (week == 0 ||
          weekStart.month !=
              adjustedStart.add(Duration(days: (week - 1) * 7)).month) {
        monthHeaders[week] = DateFormat('MMM').format(weekStart);
        if (weekStart.month == 1 || week == 0) {
          monthHeaders[week] =
              '${DateFormat('MMM').format(weekStart)} ${weekStart.year}';
        }
      }
    }

    for (int week = 0; week < numWeeks; week++) {
      List<Widget> dayWidgets = [];

      // Add month header if applicable
      dayWidgets.add(
        SizedBox(
          height: 20,
          child: monthHeaders.containsKey(week)
              ? Text(
                  monthHeaders[week]!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                    fontSize: 10,
                  ),
                )
              : null,
        ),
      );

      for (int day = 0; day < 7; day++) {
        final date = adjustedStart.add(Duration(days: week * 7 + day));
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        final isCompleted = completionDates.contains(dateStr);
        final hasNotes = _completionDatesWithNotes.contains(dateStr);
        final isToday = date.year == today.year &&
            date.month == today.month &&
            date.day == today.day;
        final isFuture = date.isAfter(today);
        final isBeforeStart = date.isBefore(startDate);
        final isFulfilled = !isCompleted && !isFuture && !isBeforeStart && 
            _isFulfilledDay(date, completionDates);

        dayWidgets.add(
          GestureDetector(
            onTap: (isCompleted && hasNotes)
                ? () => _showNotesPopup(date, dateStr, habitColor, theme, isDark)
                : null,
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.symmetric(vertical: 2),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? habitColor
                          : isFulfilled
                              ? (isDark 
                                  ? Colors.green.shade900.withValues(alpha: 0.25)
                                  : Colors.green.shade50)
                              : (isFuture || isBeforeStart)
                                  ? Colors.transparent
                                  : (isDark
                                          ? Colors.grey.shade800
                                          : Colors.grey.shade700)
                                      .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(6),
                      border: isToday
                          ? Border.all(color: habitColor, width: 2)
                          : isFulfilled
                              ? Border.all(
                                  color: isDark 
                                      ? Colors.green.shade700.withValues(alpha: 0.4)
                                      : Colors.green.shade200,
                                  width: 1,
                                )
                              : null,
                    ),
                    child: Center(
                      child: Text(
                        date.day.toString(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isCompleted
                              ? Colors.white
                              : isFuture
                                  ? theme.colorScheme.onSurface
                                      .withValues(alpha: 0.3)
                                  : theme.colorScheme.onSurface
                                      .withValues(alpha: 0.8),
                          fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  if (hasNotes)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }

      weekColumns.add(Column(children: dayWidgets));
    }

    // Day name labels column
    List<Widget> dayLabels = [
      const SizedBox(height: 20), // Space for month headers
    ];
    for (final dayName in dayNames) {
      dayLabels.add(
        Container(
          width: 28,
          height: 36,
          margin: const EdgeInsets.symmetric(vertical: 2),
          alignment: Alignment.centerRight,
          child: Text(
            dayName,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
              fontSize: 10,
            ),
          ),
        ),
      );
    }

    // Use a scroll controller to scroll to the end (showing today)
    final scrollController = ScrollController();
    
    // Schedule scroll to end after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      }
    });

    // Fixed day labels on left, scrollable calendar on right
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fixed day labels
        SizedBox(
          width: 28,
          child: Column(children: dayLabels),
        ),
        const SizedBox(width: 4),
        // Scrollable calendar
        Expanded(
          child: SingleChildScrollView(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: weekColumns,
            ),
          ),
        ),
      ],
    );
  }

  /// Handles tap on a completion cell based on notePromptOnTap setting
  Future<void> _onCompletionTap(DateTime date, {VoidCallback? onComplete}) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final existingCompletion = _completions.cast<Completion?>().firstWhere(
          (c) =>
              c != null && DateFormat('yyyy-MM-dd').format(c.date) == dateStr,
          orElse: () => null,
        );
    final isCompleted = existingCompletion != null;
    final hasNotes = existingCompletion?.notes != null && 
                     existingCompletion!.notes!.isNotEmpty;

    if (isCompleted) {
      // Unchecking behavior
      if (hasNotes) {
        // Has notes - show options sheet to review before unchecking
        await _showCompletionOptionsSheet(date, existingCompletion, onComplete);
      } else {
        // No notes - quick undo without popup
        await _quickUndo(date, onComplete);
      }
    } else {
      // Checking behavior depends on setting
      if (_notePromptOnTap) {
        // Tap opens notes popup
        await _showAddCompletionSheet(date, onComplete);
      } else {
        // Tap marks immediately
        await _quickComplete(date, onComplete);
      }
    }
  }

  /// Handles long-press on a completion cell based on notePromptOnTap setting
  Future<void> _onCompletionLongPress(DateTime date, {VoidCallback? onComplete}) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final existingCompletion = _completions.cast<Completion?>().firstWhere(
          (c) =>
              c != null && DateFormat('yyyy-MM-dd').format(c.date) == dateStr,
          orElse: () => null,
        );
    final isCompleted = existingCompletion != null;

    if (isCompleted) {
      // Always show options sheet on long-press for editing notes
      await _showCompletionOptionsSheet(date, existingCompletion, onComplete);
    } else {
      // Opposite of tap behavior
      if (_notePromptOnTap) {
        // Long-press marks immediately
        await _quickComplete(date, onComplete);
      } else {
        // Long-press opens notes popup
        await _showAddCompletionSheet(date, onComplete);
      }
    }
  }

  /// Quick complete without showing notes popup
  Future<void> _quickComplete(DateTime date, VoidCallback? onComplete) async {
    try {
      final completion = await _db.recordCompletion(_habit!.id, date);
      
      setState(() {
        _completions.add(completion);
        _completionDates.add(DateTime(date.year, date.month, date.day));
      });

      ref.invalidate(dailyStatsProvider);
      ref.invalidate(heatmapProvider);
      ref.invalidate(completionStateProvider(_habit!.id));
      ref.invalidate(habitCompletionCountsProvider);
      
      onComplete?.call();
      _calculateStats(_habit!, _completions);
    } catch (e) {
      // Error handling
    }
  }

  /// Quick undo completion without showing popup
  Future<void> _quickUndo(DateTime date, VoidCallback? onComplete) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    
    try {
      await _db.undoCompletion(_habit!.id, date);
      
      setState(() {
        _completions.removeWhere(
            (c) => DateFormat('yyyy-MM-dd').format(c.date) == dateStr);
        _completionDates.remove(DateTime(date.year, date.month, date.day));
        _completionDatesWithNotes.remove(dateStr);
      });

      ref.invalidate(dailyStatsProvider);
      ref.invalidate(heatmapProvider);
      ref.invalidate(completionStateProvider(_habit!.id));
      ref.invalidate(habitCompletionCountsProvider);
      
      onComplete?.call();
      _calculateStats(_habit!, _completions);
    } catch (e) {
      // Error handling
    }
  }

  Future<void> _showAddCompletionSheet(
      DateTime date, VoidCallback? onComplete) async {
    final notesController = TextEditingController();

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[600] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (_habit?.icon != null && _habit!.icon!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          _habit!.icon!,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        _habit?.title ?? 'Mark Complete',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEEE, MMMM d').format(date),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                // Show reflective question if exists (stored as "QUESTION|||NOTES")
                Builder(builder: (context) {
                  String? reflectiveQuestion;
                  if (_habit?.description != null &&
                      _habit!.description!.isNotEmpty) {
                    if (_habit!.description!.contains('|||')) {
                      final parts = _habit!.description!.split('|||');
                      if (parts[0].isNotEmpty) {
                        reflectiveQuestion = parts[0];
                      }
                    } else {
                      // If no separator, treat as reflective question
                      reflectiveQuestion = _habit!.description;
                    }
                  }

                  if (reflectiveQuestion == null ||
                      reflectiveQuestion.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                reflectiveQuestion,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.8),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: TextField(
                    controller: notesController,
                    style: theme.textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Add notes (optional)',
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    maxLines: 3,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('OK'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == true) {
      try {
        final notes = notesController.text.trim().isEmpty
            ? null
            : notesController.text.trim();
        await _db.recordCompletion(widget.habitId, date, notes: notes);
        await _loadData();
        ref.invalidate(habitsProvider);
        ref.invalidate(dailyStatsProvider);
        ref.invalidate(heatmapProvider);
        ref.invalidate(habitCompletionCountsProvider);
        onComplete?.call();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }

    notesController.dispose();
  }

  Future<void> _showCompletionOptionsSheet(
      DateTime date, Completion completion, VoidCallback? onComplete) async {
    final notesController = TextEditingController(text: completion.notes ?? '');

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[600] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Completed',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEEE, MMMM d').format(date),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: TextField(
                    controller: notesController,
                    style: theme.textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Add notes (optional)',
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    maxLines: 3,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context, 'undo'),
                        icon: const Icon(Icons.undo, size: 18),
                        label: const Text('Undo'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          foregroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, 'save'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == 'undo') {
      try {
        await _db.undoCompletion(widget.habitId, date);
        await _loadData();
        ref.invalidate(habitsProvider);
        ref.invalidate(dailyStatsProvider);
        ref.invalidate(heatmapProvider);
        ref.invalidate(habitCompletionCountsProvider);
        onComplete?.call();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    } else if (result == 'save') {
      try {
        final notes = notesController.text.trim().isEmpty
            ? null
            : notesController.text.trim();
        await _db.updateCompletionNotes(widget.habitId, date, notes);
      } catch (e) {
        // Ignore errors for notes update
      }
    }

    notesController.dispose();
  }

  void _showEditCalendarSheet(ThemeData theme, bool isDark) {
    final scrollController = ScrollController();
    bool hasScrolledToEnd = false;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          // Only scroll to end on initial build
          if (!hasScrolledToEnd) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (scrollController.hasClients) {
                scrollController.jumpTo(scrollController.position.maxScrollExtent);
                hasScrolledToEnd = true;
              }
            });
          }
          
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(
                        'Edit Completions',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Tap on any date to mark or unmark completion',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Calendar
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? theme.colorScheme.surface
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              theme.colorScheme.outline.withValues(alpha: 0.3),
                        ),
                      ),
                      child: _buildEditableCalendarGrid(
                          theme, isDark, setSheetState, scrollController),
                    ),
                  ),
                ),
                // Legend
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLegendItem(
                          theme, _parseColor(_habit?.color), 'Completed'),
                      const SizedBox(width: 20),
                      _buildLegendItem(
                          theme,
                          isDark ? Colors.grey.shade800 : Colors.grey.shade400,
                          'Not done'),
                      const SizedBox(width: 20),
                      _buildNotesLegendItem(theme, isDark),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    ).then((_) {
      // Refresh when sheet is closed
      _loadData();
    });
  }

  Widget _buildEditableCalendarGrid(
      ThemeData theme, bool isDark, StateSetter setSheetState, ScrollController scrollController) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final completionDates = _completions
        .map((c) => DateFormat('yyyy-MM-dd').format(c.date))
        .toSet();

    // Track dates that have notes
    final datesWithNotes = _completions
        .where((c) => c.notes != null && c.notes!.isNotEmpty)
        .map((c) => DateFormat('yyyy-MM-dd').format(c.date))
        .toSet();

    final baseHabitColor = _parseColor(_habit?.color);
    final habitColor = _enhanceColorForDarkMode(baseHabitColor, isDark);
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    // Show 2 years of history (no restriction) - allows backfilling completions
    final twoYearsAgo = today.subtract(const Duration(days: 730));
    final startDate = DateTime(twoYearsAgo.year, twoYearsAgo.month, twoYearsAgo.day);
    final adjustedStart =
        startDate.subtract(Duration(days: (startDate.weekday - 1) % 7));
    final daysDiff = today.difference(adjustedStart).inDays;
    final numWeeks = (daysDiff / 7).ceil() + 1;

    // Find unique months to display
    Map<int, String> monthHeaders = {};
    for (int week = 0; week < numWeeks; week++) {
      final weekStart = adjustedStart.add(Duration(days: week * 7));
      if (week == 0 ||
          weekStart.month !=
              adjustedStart.add(Duration(days: (week - 1) * 7)).month) {
        monthHeaders[week] = DateFormat('MMM').format(weekStart);
        if (weekStart.month == 1 || week == 0) {
          monthHeaders[week] =
              '${DateFormat('MMM').format(weekStart)} ${weekStart.year}';
        }
      }
    }

    List<Widget> weekColumns = [];

    for (int week = 0; week < numWeeks; week++) {
      List<Widget> dayWidgets = [];

      dayWidgets.add(
        SizedBox(
          height: 20,
          child: monthHeaders.containsKey(week)
              ? Text(
                  monthHeaders[week]!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                    fontSize: 10,
                  ),
                )
              : null,
        ),
      );

      for (int day = 0; day < 7; day++) {
        final date = adjustedStart.add(Duration(days: week * 7 + day));
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        final isCompleted = completionDates.contains(dateStr);
        final hasNotes = datesWithNotes.contains(dateStr);
        final isToday = date.year == today.year &&
            date.month == today.month &&
            date.day == today.day;
        final isFuture = date.isAfter(today);
        // Only check creation date if we're not showing backfilled completions
        // Allow fulfilled state for any day that has completions around it
        final isFulfilled = !isCompleted && !isFuture && 
            _isFulfilledDay(date, completionDates);

        dayWidgets.add(
          GestureDetector(
            onTap: (!isFuture)
                ? () async {
                    await _onCompletionTap(date, onComplete: () {
                      setSheetState(() {});
                    });
                  }
                : null,
            onLongPress: (!isFuture)
                ? () async {
                    await _onCompletionLongPress(date, onComplete: () {
                      setSheetState(() {});
                    });
                  }
                : null,
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.symmetric(vertical: 2),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? habitColor
                          : isFulfilled
                              ? (isDark 
                                  ? Colors.green.shade900.withValues(alpha: 0.25)
                                  : Colors.green.shade50)
                              : isFuture
                                  ? Colors.transparent
                                  : (isDark
                                          ? Colors.grey.shade800
                                          : Colors.grey.shade700)
                                      .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(6),
                      border: isToday
                          ? Border.all(color: habitColor, width: 2)
                          : isFulfilled
                              ? Border.all(
                                  color: isDark 
                                      ? Colors.green.shade700.withValues(alpha: 0.4)
                                      : Colors.green.shade200,
                                  width: 1,
                                )
                              : null,
                    ),
                    child: Center(
                      child: Text(
                        date.day.toString(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isCompleted
                              ? Colors.white
                              : isFuture
                                  ? theme.colorScheme.onSurface
                                      .withValues(alpha: 0.3)
                                  : theme.colorScheme.onSurface
                                      .withValues(alpha: 0.8),
                          fontWeight:
                              isToday ? FontWeight.bold : FontWeight.w500,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  // Notes indicator - small dot in top-right corner
                  if (hasNotes)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.amber.shade300
                              : Colors.amber.shade600,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 1,
                              offset: const Offset(0, 0.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }

      weekColumns.add(Column(children: dayWidgets));
    }

    // Day name labels column (Mon, Tue, Wed, etc.)
    List<Widget> dayLabels = [
      const SizedBox(height: 20),
    ];
    for (final dayName in dayNames) {
      dayLabels.add(
        Container(
          width: 28,
          height: 36,
          margin: const EdgeInsets.symmetric(vertical: 2),
          alignment: Alignment.centerRight,
          child: Text(
            dayName,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
              fontSize: 10,
            ),
          ),
        ),
      );
    }

    // Use a Row with fixed day labels and scrollable calendar
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fixed day labels on the left
        SizedBox(
          width: 28,
          child: Column(children: dayLabels),
        ),
        const SizedBox(width: 4),
        // Scrollable calendar grid
        Expanded(
          child: SingleChildScrollView(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: weekColumns,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(ThemeData theme, Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildNotesLegendItem(ThemeData theme, bool isDark) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color:
                        isDark ? Colors.amber.shade300 : Colors.amber.shade600,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'Has notes',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildFrequencySection(Habit habit, ThemeData theme, bool isDark) {
    String frequencyText;
    int expectedPerWeek;

    switch (habit.frequency) {
      case HabitFrequency.daily:
        frequencyText = 'Every day';
        expectedPerWeek = 7;
        break;
      case HabitFrequency.everyXDays:
        frequencyText = 'Every ${habit.customDays ?? 2} days';
        expectedPerWeek = (7 / (habit.customDays ?? 2)).round();
        break;
      case HabitFrequency.timesPerWeek:
        frequencyText = '${habit.customDays ?? 3}x per week';
        expectedPerWeek = habit.customDays ?? 3;
        break;
      case HabitFrequency.timesPerMonth:
        frequencyText = '${habit.customDays ?? 10}x per month';
        expectedPerWeek = ((habit.customDays ?? 10) / 4.3).round();
        break;
      case HabitFrequency.specificDays:
        final weekDayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        List<String> days = [];
        int mask = habit.customDays ?? 0;
        for (int i = 0; i < 7; i++) {
          if ((mask & (1 << i)) != 0) {
            days.add(weekDayNames[i]);
          }
        }
        frequencyText = days.isEmpty ? 'No days selected' : days.join(', ');
        expectedPerWeek = days.length;
        break;
    }

    final weeklyProgress = expectedPerWeek > 0
        ? (_thisWeekCompletions / expectedPerWeek * 100).clamp(0, 100)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Schedule',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? theme.colorScheme.surface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              // Frequency and Reminder row
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    frequencyText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Icon(
                    Icons.notifications_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    habit.reminderTime != null
                        ? _formatReminderTime(habit.reminderTime!)
                        : 'Off',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Weekly progress bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'This week',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      Text(
                        '$_thisWeekCompletions / $expectedPerWeek',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: weeklyProgress / 100,
                      minHeight: 8,
                      backgroundColor:
                          isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(
                        weeklyProgress >= 100
                            ? Colors.green
                            : theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatReminderTime(String reminderTime) {
    try {
      final parts = reminderTime.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final period = hour >= 12 ? 'pm' : 'am';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
    } catch (e) {
      return reminderTime;
    }
  }

  Widget _buildHighlightsSection(ThemeData theme, bool isDark) {
    final highlights = <Map<String, dynamic>>[];

    // Add achievements based on stats
    if (_currentStreak >= 7) {
      highlights.add({
        'emoji': '🔥',
        'title': 'On Fire!',
        'subtitle': '$_currentStreak day streak going strong',
      });
    } else if (_currentStreak >= 3) {
      highlights.add({
        'emoji': '⚡',
        'title': 'Building Momentum',
        'subtitle': '$_currentStreak days in a row',
      });
    }

    if (_longestStreak >= 30) {
      highlights.add({
        'emoji': '🏆',
        'title': 'Monthly Master',
        'subtitle': 'Best streak: $_longestStreak days',
      });
    } else if (_longestStreak >= 7) {
      highlights.add({
        'emoji': '⭐',
        'title': 'Week Warrior',
        'subtitle': 'Best streak: $_longestStreak days',
      });
    }

    if (_totalCompletions >= 100) {
      highlights.add({
        'emoji': '💯',
        'title': 'Century Club',
        'subtitle': '$_totalCompletions total check-ins',
      });
    } else if (_totalCompletions >= 50) {
      highlights.add({
        'emoji': '🎯',
        'title': 'Dedicated',
        'subtitle': '$_totalCompletions check-ins so far',
      });
    }

    if (_consistencyScore >= 80) {
      highlights.add({
        'emoji': '🌟',
        'title': 'Highly Consistent',
        'subtitle': '${_consistencyScore.round()}% consistency this month',
      });
    }

    if (highlights.isEmpty) {
      highlights.add({
        'emoji': '🌱',
        'title': 'Just Getting Started',
        'subtitle': 'Keep going to unlock achievements',
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Highlights',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...highlights.map((h) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? theme.colorScheme.surface : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Text(h['emoji'] as String,
                        style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            h['title'] as String,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            h['subtitle'] as String,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _onEdit,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit Habit'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: _onDelete,
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            label: const Text('Delete Habit'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _parseColor(String? colorHex) {
    if (colorHex == null || colorHex.isEmpty) {
      return Colors.blue;
    }
    try {
      final hex = colorHex.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (e) {
      return Colors.blue;
    }
  }

  /// Enhance color for better visibility in dark mode
  Color _enhanceColorForDarkMode(Color color, bool isDark) {
    if (!isDark) return color;
    
    // Convert to HSL and increase saturation/lightness for dark mode
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withSaturation((hsl.saturation * 1.2).clamp(0.0, 1.0))
        .withLightness((hsl.lightness * 1.15).clamp(0.3, 0.7))
        .toColor();
  }

  void _showNotesPopup(DateTime date, String dateStr, Color habitColor,
      ThemeData theme, bool isDark) {
    // Find the completion with notes for this date
    final completion = _completions.firstWhere(
      (c) => DateFormat('yyyy-MM-dd').format(c.date) == dateStr,
      orElse: () => _completions.first,
    );

    if (completion.notes == null || completion.notes!.isEmpty) return;

    // Parse notes - handle "QUESTION|||NOTES" format
    String displayNotes = completion.notes!;
    String? reflectiveQuestion;

    if (displayNotes.contains('|||')) {
      final parts = displayNotes.split('|||');
      reflectiveQuestion = parts[0];
      displayNotes = parts.length > 1 ? parts[1] : '';
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          decoration: BoxDecoration(
            color: isDark ? theme.colorScheme.surface : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: habitColor.withValues(alpha: 0.1),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: habitColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.note_alt_rounded,
                        color: habitColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Note',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('EEEE, MMM d, yyyy').format(date),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor:
                            theme.colorScheme.onSurface.withValues(alpha: 0.05),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (reflectiveQuestion != null &&
                        reflectiveQuestion.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('💭', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                reflectiveQuestion,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontStyle: FontStyle.italic,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      displayNotes.isNotEmpty
                          ? displayNotes
                          : 'No additional notes',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // History Stats Section - Week, Month, Quarter, Year
  Widget _buildHistoryStatsSection(
      Color habitColor, ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Completion History',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? theme.colorScheme.surface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildHistoryStatCard(
                      'This Week',
                      _thisWeekCompletions,
                      Icons.view_week_rounded,
                      habitColor,
                      theme,
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildHistoryStatCard(
                      'Last Week',
                      _lastWeekCompletions,
                      Icons.history_rounded,
                      habitColor.withValues(alpha: 0.7),
                      theme,
                      isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildHistoryStatCard(
                      'This Month',
                      _thisMonthCompletions,
                      Icons.calendar_month_rounded,
                      habitColor,
                      theme,
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildHistoryStatCard(
                      'This Quarter',
                      _thisQuarterCompletions,
                      Icons.date_range_rounded,
                      habitColor,
                      theme,
                      isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildHistoryStatCard(
                      'This Year',
                      _thisYearCompletions,
                      Icons.calendar_today_rounded,
                      habitColor,
                      theme,
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildHistoryStatCard(
                      'All Time',
                      _totalCompletions,
                      Icons.all_inclusive_rounded,
                      Colors.amber.shade600,
                      theme,
                      isDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryStatCard(
    String label,
    int count,
    IconData icon,
    Color color,
    ThemeData theme,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            count == 1 ? 'completion' : 'completions',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  // Frequency Chart Section - Bar chart showing day-of-week distribution
  Widget _buildFrequencyChartSection(
      Color habitColor, ThemeData theme, bool isDark) {
    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxValue = _weeklyFrequency.reduce((a, b) => a > b ? a : b);
    final total = _weeklyFrequency.reduce((a, b) => a + b);

    // Find best and worst days
    int bestDay = 0;
    int worstDay = 0;
    for (int i = 0; i < 7; i++) {
      if (_weeklyFrequency[i] > _weeklyFrequency[bestDay]) bestDay = i;
      if (_weeklyFrequency[i] < _weeklyFrequency[worstDay]) worstDay = i;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Weekly Pattern',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Based on last 12 weeks',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? theme.colorScheme.surface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              // Bar chart
              SizedBox(
                height: 140,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (index) {
                    final value = _weeklyFrequency[index];
                    final percentage = maxValue > 0 ? value / maxValue : 0.0;
                    final isBest = index == bestDay && value > 0;

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          value.toString(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight:
                                isBest ? FontWeight.bold : FontWeight.normal,
                            color: isBest
                                ? habitColor
                                : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 32,
                          height: percentage * 80 + 8,
                          decoration: BoxDecoration(
                            color: isBest
                                ? habitColor
                                : habitColor.withValues(
                                    alpha: 0.3 + percentage * 0.4),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          weekDays[index],
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight:
                                isBest ? FontWeight.bold : FontWeight.normal,
                            color: isBest
                                ? habitColor
                                : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),
              // Summary
              if (total > 0) ...[
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildChartSummaryItem(
                      '🏆 Best Day',
                      weekDays[bestDay],
                      theme,
                    ),
                    _buildChartSummaryItem(
                      '📊 Average',
                      '${(total / 7).toStringAsFixed(1)}/day',
                      theme,
                    ),
                    _buildChartSummaryItem(
                      '📈 Total',
                      '$total times',
                      theme,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // Frequency Dot Matrix Chart - Shows completions over time in a dot matrix format
  Widget _buildFrequencyDotMatrixSection(
      Color habitColor, ThemeData theme, bool isDark) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Get completion dates as a set for quick lookup
    final completionDates = _completions
        .map((c) => DateFormat('yyyy-MM-dd').format(c.date))
        .toSet();
    
    // Count completions per date for intensity
    final completionCounts = <String, int>{};
    for (final c in _completions) {
      final dateStr = DateFormat('yyyy-MM-dd').format(c.date);
      completionCounts[dateStr] = (completionCounts[dateStr] ?? 0) + 1;
    }
    
    // Find max completions for a single day (for dot sizing)
    final maxCompletions = completionCounts.isEmpty 
        ? 1 
        : completionCounts.values.reduce((a, b) => a > b ? a : b);
    
    // Show 5 years of data
    final startDate = DateTime(today.year - 5, today.month, 1);
    
    // Calculate weeks
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    
    // Adjust start to beginning of week (Monday)
    final adjustedStart = startDate.subtract(Duration(days: (startDate.weekday - 1) % 7));
    final daysDiff = today.difference(adjustedStart).inDays;
    final numWeeks = (daysDiff / 7).ceil() + 1;
    
    // Find unique months to display
    Map<int, String> monthHeaders = {};
    for (int week = 0; week < numWeeks; week++) {
      final weekStart = adjustedStart.add(Duration(days: week * 7));
      if (week == 0 ||
          weekStart.month != adjustedStart.add(Duration(days: (week - 1) * 7)).month) {
        String label = DateFormat('MMM').format(weekStart);
        if (weekStart.month == 1 || week == 0) {
          label = '${DateFormat('MMM').format(weekStart)} ${weekStart.year}';
        }
        monthHeaders[week] = label;
      }
    }
    
    // Build week columns
    List<Widget> weekColumns = [];
    for (int week = 0; week < numWeeks; week++) {
      List<Widget> dayWidgets = [];
      
      // Month header
      dayWidgets.add(
        SizedBox(
          height: 20,
          child: monthHeaders.containsKey(week)
              ? Text(
                  monthHeaders[week]!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                    fontSize: 10,
                  ),
                )
              : null,
        ),
      );
      
      // Days
      for (int day = 0; day < 7; day++) {
        final date = adjustedStart.add(Duration(days: week * 7 + day));
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        final isCompleted = completionDates.contains(dateStr);
        final completionCount = completionCounts[dateStr] ?? 0;
        final isFuture = date.isAfter(today);
        final isBeforeStart = date.isBefore(startDate);
        
        // Calculate dot size based on completion count
        double dotSize = 0;
        if (isCompleted) {
          final intensity = completionCount / maxCompletions;
          dotSize = 6 + (intensity * 10); // Range from 6 to 16
        }
        
        dayWidgets.add(
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.symmetric(vertical: 1),
            child: Center(
              child: (isFuture || isBeforeStart)
                  ? const SizedBox.shrink()
                  : isCompleted
                      ? Container(
                          width: dotSize,
                          height: dotSize,
                          decoration: BoxDecoration(
                            color: habitColor.withValues(
                                alpha: 0.4 + (completionCount / maxCompletions) * 0.6),
                            shape: BoxShape.circle,
                            boxShadow: completionCount > 1
                                ? [
                                    BoxShadow(
                                      color: habitColor.withValues(alpha: 0.3),
                                      blurRadius: 4,
                                      spreadRadius: 0,
                                    ),
                                  ]
                                : null,
                          ),
                        )
                      : Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                        ),
            ),
          ),
        );
      }
      
      weekColumns.add(Column(children: dayWidgets));
    }
    
    // Day labels column
    List<Widget> dayLabels = [
      const SizedBox(height: 20),
    ];
    for (final dayName in dayNames) {
      dayLabels.add(
        Container(
          height: 28,
          margin: const EdgeInsets.symmetric(vertical: 1),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 8),
          child: Text(
            dayName,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontWeight: FontWeight.w500,
              fontSize: 10,
            ),
          ),
        ),
      );
    }
    
    // Create scroll controller for horizontal scrolling
    final scrollController = ScrollController();
    
    // Schedule scroll to end after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Frequency',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? theme.colorScheme.surface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day labels on the right side
              Column(children: dayLabels),
              // Scrollable chart
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: weekColumns,
                  ),
                ),
              ),
              // Day name labels on right
              const SizedBox(width: 8),
              Column(
                children: [
                  const SizedBox(height: 20),
                  ...dayNames.map((dayName) => Container(
                    height: 28,
                    margin: const EdgeInsets.symmetric(vertical: 1),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      dayName,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                      ),
                    ),
                  )),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChartSummaryItem(String label, String value, ThemeData theme) {
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
