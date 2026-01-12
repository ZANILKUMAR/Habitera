import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/habit_provider.dart';
import '../widgets/empty_state.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _selectedMonth = DateTime.now();

  Color _getHeatmapColor(int percentage, bool isDark) {
    if (percentage == 0) {
      return isDark ? Colors.grey.shade800.withValues(alpha: 0.5) : Colors.grey.shade100;
    } else if (percentage < 25) {
      return const Color(0xFFE8F5E9);
    } else if (percentage < 50) {
      return const Color(0xFFA5D6A7);
    } else if (percentage < 75) {
      return const Color(0xFF66BB6A);
    } else {
      return const Color(0xFF43A047);
    }
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final nextMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    if (nextMonth.isBefore(DateTime(now.year, now.month + 1))) {
      setState(() {
        _selectedMonth = nextMonth;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final habitsAsync = ref.watch(habitsProvider);
    final heatmapAsync = ref.watch(heatmapProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: habitsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
          data: (habits) {
            if (habits.isEmpty) {
              return EmptyState(
                icon: '📅',
                title: 'No habits to track',
                subtitle: 'Create a habit to see your activity',
                actionLabel: 'Create Habit',
                onAction: () {},
              );
            }

            return heatmapAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error: $error')),
              data: (heatmap) {
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(heatmapProvider);
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        _buildHeader(theme),
                        
                        // Stats summary cards
                        _buildStatsSummary(heatmap, theme, isDark),
                        
                        // Monthly calendar
                        _buildMonthlyCalendar(heatmap, theme, isDark),
                        
                        // Activity heatmap
                        _buildHeatmapSection(heatmap, theme, isDark),
                        
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Activity',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Track your habit journey',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSummary(Map<String, int> heatmap, ThemeData theme, bool isDark) {
    final perfectDays = heatmap.values.where((v) => v >= 100).length;
    final avgCompletion = heatmap.isEmpty 
        ? 0 
        : (heatmap.values.reduce((a, b) => a + b) / heatmap.length).round();

    // Calculate current streak
    int currentStreak = 0;
    final now = DateTime.now();
    for (int i = 0; i < 365; i++) {
      final date = now.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      if ((heatmap[dateStr] ?? 0) > 0) {
        currentStreak++;
      } else if (i > 0) {
        break;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              '🔥',
              '$currentStreak',
              'Day Streak',
              theme.colorScheme.primary,
              theme,
              isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              '⭐',
              '$perfectDays',
              'Perfect Days',
              Colors.amber.shade600,
              theme,
              isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              '📈',
              '$avgCompletion%',
              'Average',
              Colors.green.shade600,
              theme,
              isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String emoji, String value, String label, Color color, ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: isDark ? 0.2 : 0.1),
            color.withValues(alpha: isDark ? 0.1 : 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyCalendar(Map<String, int> heatmap, ThemeData theme, bool isDark) {
    final now = DateTime.now();
    final canGoNext = DateTime(_selectedMonth.year, _selectedMonth.month + 1)
        .isBefore(DateTime(now.year, now.month + 1));

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          // Month navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _previousMonth,
                icon: const Icon(Icons.chevron_left_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                ),
              ),
              Text(
                DateFormat('MMMM yyyy').format(_selectedMonth),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                onPressed: canGoNext ? _nextMonth : null,
                icon: const Icon(Icons.chevron_right_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: canGoNext 
                      ? theme.colorScheme.primary.withValues(alpha: 0.1)
                      : Colors.transparent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Day labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map((day) => SizedBox(
                      width: 40,
                      child: Text(
                        day,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          
          // Calendar grid
          _buildCalendarGrid(heatmap, theme, isDark),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(Map<String, int> heatmap, ThemeData theme, bool isDark) {
    final firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final startWeekday = firstDay.weekday % 7; // 0 = Sunday
    final daysInMonth = lastDay.day;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final rows = <Widget>[];
    var currentDay = 1;

    for (var week = 0; week < 6; week++) {
      if (currentDay > daysInMonth) break;

      final cells = <Widget>[];
      for (var day = 0; day < 7; day++) {
        if ((week == 0 && day < startWeekday) || currentDay > daysInMonth) {
          cells.add(const SizedBox(width: 40, height: 40));
        } else {
          final date = DateTime(_selectedMonth.year, _selectedMonth.month, currentDay);
          final dateStr = DateFormat('yyyy-MM-dd').format(date);
          final percentage = heatmap[dateStr] ?? 0;
          final isToday = date.isAtSameMomentAs(today);
          final isFuture = date.isAfter(today);

          cells.add(
            Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isFuture 
                    ? Colors.transparent
                    : _getHeatmapColor(percentage, isDark),
                borderRadius: BorderRadius.circular(10),
                border: isToday 
                    ? Border.all(color: theme.colorScheme.primary, width: 2)
                    : null,
              ),
              child: Center(
                child: Text(
                  '$currentDay',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                    color: isFuture
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
                        : percentage >= 50
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          );
          currentDay++;
        }
      }
      rows.add(Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: cells,
      ));
    }

    return Column(children: rows);
  }

  Widget _buildHeatmapSection(Map<String, int> heatmap, ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '3 Month Overview',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              _buildLegend(theme, isDark),
            ],
          ),
          const SizedBox(height: 16),
          _buildHeatmap(heatmap, isDark, theme),
        ],
      ),
    );
  }

  Widget _buildLegend(ThemeData theme, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Less',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(width: 4),
        _legendBox(isDark ? Colors.grey.shade800 : Colors.grey.shade200),
        _legendBox(const Color(0xFFE8F5E9)),
        _legendBox(const Color(0xFFA5D6A7)),
        _legendBox(const Color(0xFF66BB6A)),
        _legendBox(const Color(0xFF43A047)),
        const SizedBox(width: 4),
        Text(
          'More',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _legendBox(Color color) {
    return Container(
      width: 12,
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeatmap(Map<String, int> heatmap, bool isDark, ThemeData theme) {
    final now = DateTime.now();
    final daysBack = 91;
    final endDate = DateTime(now.year, now.month, now.day);
    final startDate = endDate.subtract(Duration(days: daysBack));
    final adjustedStart = startDate.subtract(Duration(days: startDate.weekday % 7));
    final numDays = endDate.difference(adjustedStart).inDays + 1;
    final numWeeks = (numDays / 7).ceil();

    final grid = List.generate(7, (dayOfWeek) {
      return List.generate(numWeeks, (weekIndex) {
        final date = adjustedStart.add(Duration(days: weekIndex * 7 + dayOfWeek));
        if (date.isAfter(endDate)) return null;
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        return MapEntry(dateStr, heatmap[dateStr] ?? 0);
      });
    });

    final dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: List.generate(7, (i) => Container(
              width: 16,
              height: 14,
              alignment: Alignment.centerLeft,
              margin: const EdgeInsets.only(bottom: 2),
              child: Text(
                dayLabels[i],
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  fontSize: 10,
                ),
              ),
            )),
          ),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(7, (dayOfWeek) => Row(
              children: List.generate(numWeeks, (weekIndex) {
                final entry = grid[dayOfWeek][weekIndex];
                if (entry == null) {
                  return Container(width: 12, height: 12, margin: const EdgeInsets.all(1));
                }
                return Tooltip(
                  message: '${DateFormat('MMM d').format(DateTime.parse(entry.key))}: ${entry.value}%',
                  child: Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: _getHeatmapColor(entry.value, isDark),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            )),
          ),
        ],
      ),
    );
  }
}
