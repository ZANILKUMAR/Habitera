import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/habit.dart';
import '../services/database_service.dart';
import '../providers/habit_provider.dart';
import '../screens/habit_details_screen.dart';

class HabitGrid extends ConsumerStatefulWidget {
  final List<Habit> habits;
  final int daysToShow;

  const HabitGrid({
    super.key,
    required this.habits,
    this.daysToShow = 14,
  });

  @override
  ConsumerState<HabitGrid> createState() => _HabitGridState();
}

class _HabitGridState extends ConsumerState<HabitGrid> {
  final DatabaseService _db = DatabaseService();
  final ScrollController _horizontalScrollController = ScrollController();
  late List<DateTime> _dates;
  Map<String, Set<String>> _completions = {}; // habitId -> set of date strings

  @override
  void initState() {
    super.initState();
    _generateDates();
    _loadCompletions();
  }

  void _generateDates() {
    final today = DateTime.now();
    _dates = List.generate(
      widget.daysToShow,
      (i) => DateTime(today.year, today.month, today.day - i),
    );
  }

  Future<void> _loadCompletions() async {
    final completions = <String, Set<String>>{};
    
    for (final habit in widget.habits) {
      final habitCompletions = await _db.getCompletionsForHabit(habit.id);
      completions[habit.id] = habitCompletions
          .map((c) => DateFormat('yyyy-MM-dd').format(c.date))
          .toSet();
    }

    if (mounted) {
      setState(() {
        _completions = completions;
      });
    }
  }

  Future<void> _toggleCompletion(String habitId, DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final isCompleted = _completions[habitId]?.contains(dateStr) ?? false;

    // Optimistic update for immediate feedback
    setState(() {
      _completions[habitId] ??= {};
      if (isCompleted) {
        _completions[habitId]!.remove(dateStr);
      } else {
        _completions[habitId]!.add(dateStr);
      }
    });

    try {
      if (isCompleted) {
        await _db.undoCompletion(habitId, date);
      } else {
        await _db.recordCompletion(habitId, date);
      }

      // Silently update providers for streaks, stats, heatmap
      ref.invalidate(dailyStatsProvider);
      ref.invalidate(heatmapProvider);
      ref.invalidate(completionStateProvider(habitId));
    } catch (e) {
      // Revert on error
      setState(() {
        if (isCompleted) {
          _completions[habitId]!.add(dateStr);
        } else {
          _completions[habitId]!.remove(dateStr);
        }
      });
    }
  }

  void _onHabitTapped(Habit habit) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => HabitDetailsScreen(habitId: habit.id),
      ),
    ).then((_) {
      // Refresh data when returning from details screen
      _loadCompletions();
      ref.invalidate(habitsProvider);
      ref.invalidate(dailyStatsProvider);
    });
  }

  @override
  void didUpdateWidget(HabitGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.habits.length != widget.habits.length) {
      _loadCompletions();
    }
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // Date header row
        _buildDateHeader(theme, isDark),
        const Divider(height: 1),
        // Habits grid
        Expanded(
          child: widget.habits.isEmpty
              ? _buildEmptyState(theme)
              : ListView.builder(
                  itemCount: widget.habits.length,
                  itemBuilder: (context, index) {
                    return _buildHabitRow(widget.habits[index], theme, isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDateHeader(ThemeData theme, bool isDark) {
    return Container(
      height: 50,
      color: isDark ? theme.colorScheme.surface : Colors.grey.shade50,
      child: Row(
        children: [
          // Habit name column header
          Container(
            width: 140,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            child: Text(
              'Habits',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          // Scrollable date headers
          Expanded(
            child: SingleChildScrollView(
              controller: _horizontalScrollController,
              scrollDirection: Axis.horizontal,
              reverse: false,
              child: Row(
                children: _dates.map((date) {
                  final isToday = _isToday(date);
                  return _buildDateCell(date, theme, isDark, isToday);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateCell(DateTime date, ThemeData theme, bool isDark, bool isToday) {
    return Container(
      width: 90,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      decoration: BoxDecoration(
        color: isToday
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            DateFormat('E').format(date).substring(0, 2),
            style: theme.textTheme.labelSmall?.copyWith(
              color: isToday
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
              fontSize: 10,
            ),
          ),
          Text(
            DateFormat('d').format(date),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isToday
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitRow(Habit habit, ThemeData theme, bool isDark) {
    final habitColor = _parseColor(habit.color);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Habit name and icon - tappable to view details
          GestureDetector(
            onTap: () => _onHabitTapped(habit),
            child: Container(
              width: 140,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: Row(
                children: [
                  if (habit.icon != null)
                    Text(habit.icon!, style: const TextStyle(fontSize: 18)),
                  if (habit.icon != null) const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      habit.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Scrollable completion cells
          Expanded(
            child: SingleChildScrollView(
              controller: _horizontalScrollController,
              scrollDirection: Axis.horizontal,
              reverse: false,
              child: Row(
                children: _dates.map((date) {
                  return _buildCompletionCell(habit, date, habitColor, theme, isDark);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionCell(
    Habit habit,
    DateTime date,
    Color habitColor,
    ThemeData theme,
    bool isDark,
  ) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final isCompleted = _completions[habit.id]?.contains(dateStr) ?? false;
    final isToday = _isToday(date);

    return GestureDetector(
      onTap: () => _toggleCompletion(habit.id, date),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 90,
        height: 56,
        padding: const EdgeInsets.all(8),
        child: Container(
          decoration: BoxDecoration(
            color: isCompleted
                ? habitColor.withValues(alpha: 0.2)
                : isDark
                    ? Colors.grey.shade800.withValues(alpha: 0.3)
                    : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCompleted
                  ? habitColor.withValues(alpha: 0.5)
                  : isToday
                      ? theme.colorScheme.primary.withValues(alpha: 0.3)
                      : Colors.transparent,
              width: isToday ? 2 : 1,
            ),
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isCompleted
                  ? Icon(
                      Icons.check_rounded,
                      key: const ValueKey('checked'),
                      color: habitColor,
                      size: 22,
                    )
                  : const SizedBox.shrink(key: ValueKey('unchecked')),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '🎯',
              style: TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 16),
            Text(
              'No habits yet',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first habit to start tracking',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Color _parseColor(String? colorHex) {
    if (colorHex == null) return Colors.teal;
    try {
      final hex = colorHex.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (e) {
      return Colors.teal;
    }
  }
}
