import 'dart:ui' as ui;

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
  String _chartFilter = 'weekly'; // 'weekly', 'monthly', 'quarterly', 'yearly'
  String _habitChartFilter = 'week'; // 'week', 'month', 'quarter', 'year', 'lifetime'
  final ScrollController _historyChartScrollController = ScrollController();
  final ScrollController _lineChartScrollController = ScrollController();

  @override
  void dispose() {
    _historyChartScrollController.dispose();
    _lineChartScrollController.dispose();
    super.dispose();
  }

  void _scrollHistoryChartToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_historyChartScrollController.hasClients) {
        _historyChartScrollController.jumpTo(
          _historyChartScrollController.position.maxScrollExtent,
        );
      }
      if (_lineChartScrollController.hasClients) {
        _lineChartScrollController.jumpTo(
          _lineChartScrollController.position.maxScrollExtent,
        );
      }
    });
  }

  Color _getHeatmapColor(int percentage, bool isDark) {
    if (percentage == 0) {
      return isDark
          ? Colors.grey.shade800.withValues(alpha: 0.5)
          : Colors.grey.shade100;
    } else if (percentage < 25) {
      // Low intensity - light green, but more visible in dark mode
      return isDark
          ? const Color(0xFF4CAF50).withValues(alpha: 0.4)
          : const Color(0xFFE8F5E9);
    } else if (percentage < 50) {
      return isDark
          ? const Color(0xFF66BB6A)
          : const Color(0xFFA5D6A7);
    } else if (percentage < 75) {
      return isDark
          ? const Color(0xFF81C784)
          : const Color(0xFF66BB6A);
    } else {
      return isDark
          ? const Color(0xFF4CAF50)
          : const Color(0xFF43A047);
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

                        // Habit Comparison Chart (Habit Overview)
                        _buildHabitComparisonChart(habits, theme, isDark),

                        // History Chart
                        _buildHistoryChart(heatmap, theme, isDark),

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

  Widget _buildStatsSummary(
      Map<String, int> heatmap, ThemeData theme, bool isDark) {
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

  Widget _buildStatCard(String emoji, String value, String label, Color color,
      ThemeData theme, bool isDark) {
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

  // ==================== History Chart Section ====================

  Widget _buildHistoryChart(
      Map<String, int> heatmap, ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? null
            : [
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
          // Header with title and filter chips
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'History',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Filter chips
          _buildChartFilters(theme, isDark),
          const SizedBox(height: 20),
          // Bar chart
          _buildBarChart(heatmap, theme, isDark),
          const SizedBox(height: 24),
          // Line chart
          _buildLineChart(heatmap, theme, isDark),
        ],
      ),
    );
  }

  Widget _buildChartFilters(ThemeData theme, bool isDark) {
    final filters = [
      ('weekly', 'Week'),
      ('monthly', 'Month'),
      ('quarterly', 'Quarter'),
      ('yearly', 'Year'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final isSelected = _chartFilter == filter.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _chartFilter = filter.$1;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.3 : 0.15)
                      : isDark
                          ? Colors.grey.shade800.withValues(alpha: 0.5)
                          : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.5)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  filter.$2,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<_ChartData> _getChartData(Map<String, int> heatmap) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final data = <_ChartData>[];

    switch (_chartFilter) {
      case 'weekly':
        // Last 260 weeks (5 years) - count days with at least one habit completed
        // Start from the beginning of the current week (Monday)
        final currentWeekStart = today.subtract(Duration(days: today.weekday - 1));
        
        for (int i = 259; i >= 0; i--) {
          final weekStart = currentWeekStart.subtract(Duration(days: i * 7));
          int activeDays = 0;
          
          for (int d = 0; d < 7; d++) {
            final date = weekStart.add(Duration(days: d));
            if (date.isAfter(today)) continue;
            final dateStr = DateFormat('yyyy-MM-dd').format(date);
            // Count day as active if at least one habit was completed (heatmap > 0)
            if ((heatmap[dateStr] ?? 0) > 0) activeDays++;
          }
          
          // Show week start date (e.g., "Jan 13") for human-friendly labels
          final label = i == 0 ? 'Now' : DateFormat('MMM d').format(weekStart);
          data.add(_ChartData(label: label, value: activeDays, isCurrentPeriod: i == 0));
        }
        break;

      case 'monthly':
        // Last 60 months (5 years) - count days with at least one habit completed
        for (int i = 59; i >= 0; i--) {
          final month = DateTime(now.year, now.month - i, 1);
          final monthEnd = DateTime(month.year, month.month + 1, 0);
          int activeDays = 0;
          
          for (int d = 1; d <= monthEnd.day; d++) {
            final date = DateTime(month.year, month.month, d);
            if (date.isAfter(today)) continue;
            final dateStr = DateFormat('yyyy-MM-dd').format(date);
            // Count day as active if at least one habit was completed (heatmap > 0)
            if ((heatmap[dateStr] ?? 0) > 0) activeDays++;
          }
          
          final label = DateFormat('MMM').format(month);
          data.add(_ChartData(label: label, value: activeDays, isCurrentPeriod: i == 0));
        }
        break;

      case 'quarterly':
        // Last 20 quarters (5 years) - count days with at least one habit completed
        for (int i = 19; i >= 0; i--) {
          final quarterStartMonth = ((now.month - 1) ~/ 3) * 3 + 1 - (i * 3);
          var year = now.year;
          var adjustedMonth = quarterStartMonth;
          
          while (adjustedMonth <= 0) {
            adjustedMonth += 12;
            year--;
          }
          
          final quarterStart = DateTime(year, adjustedMonth, 1);
          final quarterEnd = DateTime(year, adjustedMonth + 3, 0);
          int activeDays = 0;
          
          var date = quarterStart;
          while (!date.isAfter(quarterEnd) && !date.isAfter(today)) {
            final dateStr = DateFormat('yyyy-MM-dd').format(date);
            // Count day as active if at least one habit was completed (heatmap > 0)
            if ((heatmap[dateStr] ?? 0) > 0) activeDays++;
            date = date.add(const Duration(days: 1));
          }
          
          // Use month range labels for all quarters (e.g., "Jan-Mar")
          final endMonth = DateTime(year, adjustedMonth + 2, 1);
          final label = '${DateFormat('MMM').format(quarterStart)}-${DateFormat('MMM').format(endMonth)}';
          data.add(_ChartData(label: label, value: activeDays, isCurrentPeriod: i == 0));
        }
        break;

      case 'yearly':
        // Last 5 years - count days with at least one habit completed
        for (int i = 4; i >= 0; i--) {
          final year = now.year - i;
          final yearStart = DateTime(year, 1, 1);
          final yearEnd = DateTime(year, 12, 31);
          int activeDays = 0;
          
          var date = yearStart;
          while (!date.isAfter(yearEnd) && !date.isAfter(today)) {
            final dateStr = DateFormat('yyyy-MM-dd').format(date);
            // Count day as active if at least one habit was completed (heatmap > 0)
            if ((heatmap[dateStr] ?? 0) > 0) activeDays++;
            date = date.add(const Duration(days: 1));
          }
          
          final label = year.toString();
          data.add(_ChartData(label: label, value: activeDays, isCurrentPeriod: i == 0));
        }
        break;
    }

    return data;
  }

  Widget _buildBarChart(Map<String, int> heatmap, ThemeData theme, bool isDark) {
    final data = _getChartData(heatmap);
    final maxValue = data.isEmpty ? 100 : data.map((d) => d.value).reduce((a, b) => a > b ? a : b);
    final normalizedMax = maxValue == 0 ? 100 : maxValue;

    // Soft, calm colors for the bars
    final barColor = isDark
        ? const Color(0xFF81C784) // Soft green for dark mode
        : const Color(0xFF66BB6A); // Slightly darker for light mode
    final currentBarColor = isDark
        ? const Color(0xFF4FC3F7) // Soft blue accent for current period
        : const Color(0xFF42A5F5);

    // Scroll to show current period (end of list) after build
    _scrollHistoryChartToEnd();

    return SizedBox(
      height: 180,
      child: ListView.builder(
        controller: _historyChartScrollController,
        scrollDirection: Axis.horizontal,
        reverse: false,
        itemCount: data.length,
        itemBuilder: (context, index) {
          final item = data[index];
          final barHeight = (item.value / normalizedMax) * 100;
          final isLast = index == data.length - 1;

          return Container(
            width: 52,
            padding: EdgeInsets.only(
              left: index == 0 ? 0 : 4,
              right: isLast ? 0 : 4,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Value label (only show if > 0) - shows number of active days
                if (item.value > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${item.value}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                // Bar
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  height: barHeight.clamp(4.0, 100.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: item.isCurrentPeriod
                            ? [
                                currentBarColor.withValues(alpha: 0.9),
                                currentBarColor.withValues(alpha: 0.6),
                              ]
                            : [
                                barColor.withValues(alpha: 0.8),
                                barColor.withValues(alpha: 0.5),
                              ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: item.value > 0
                          ? [
                              BoxShadow(
                                color: (item.isCurrentPeriod ? currentBarColor : barColor)
                                    .withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Label
                Text(
                  item.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: item.isCurrentPeriod
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontWeight: item.isCurrentPeriod ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLineChart(Map<String, int> heatmap, ThemeData theme, bool isDark) {
    final data = _getChartData(heatmap);
    if (data.isEmpty) return const SizedBox.shrink();
    
    final maxValue = data.map((d) => d.value).reduce((a, b) => a > b ? a : b);
    final normalizedMax = maxValue == 0 ? 100.0 : maxValue.toDouble();
    
    // Soft, calm colors for the line
    final lineColor = isDark
        ? const Color(0xFF81C784) // Soft green for dark mode
        : const Color(0xFF66BB6A); // Slightly darker for light mode
    final currentPointColor = isDark
        ? const Color(0xFF4FC3F7) // Soft blue accent for current period
        : const Color(0xFF42A5F5);

    return SizedBox(
      height: 140,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate total width needed
          const double pointSpacing = 52.0;
          final totalWidth = data.length * pointSpacing;
          
          return SingleChildScrollView(
            controller: _lineChartScrollController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: totalWidth,
              child: CustomPaint(
                painter: _LineChartPainter(
                  data: data,
                  maxValue: normalizedMax,
                  lineColor: lineColor,
                  currentPointColor: currentPointColor,
                  textColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  primaryColor: theme.colorScheme.primary,
                  isDark: isDark,
                ),
                size: Size(totalWidth, 140),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMonthlyCalendar(
      Map<String, int> heatmap, ThemeData theme, bool isDark) {
    final now = DateTime.now();
    final canGoNext = DateTime(_selectedMonth.year, _selectedMonth.month + 1)
        .isBefore(DateTime(now.year, now.month + 1));

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? null
            : [
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
                  backgroundColor:
                      theme.colorScheme.primary.withValues(alpha: 0.1),
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
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
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

  Widget _buildCalendarGrid(
      Map<String, int> heatmap, ThemeData theme, bool isDark) {
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
          final date =
              DateTime(_selectedMonth.year, _selectedMonth.month, currentDay);
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

  // ===== HABIT COMPARISON CHART =====

  Widget _buildHabitComparisonChart(List<dynamic> habits, ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? null
            : [
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
          // Header with filter dropdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and subtitle
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Habit Overview',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Days completed per habit',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
              // Filter dropdown
              _buildHabitChartFilters(theme, isDark),
            ],
          ),
          const SizedBox(height: 20),
          // Bar chart
          _buildHabitComparisonBarChartWithProvider(habits, theme, isDark),
        ],
      ),
    );
  }

  DateTime _getHabitChartStartDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    switch (_habitChartFilter) {
      case 'week':
        // Last 7 days (including today)
        return today.subtract(const Duration(days: 6));
      case 'month':
        return DateTime(now.year, now.month, 1);
      case 'quarter':
        final quarterStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        return DateTime(now.year, quarterStartMonth, 1);
      case 'year':
        return DateTime(now.year, 1, 1);
      case 'lifetime':
      default:
        return DateTime(2000, 1, 1);
    }
  }

  Widget _buildHabitComparisonBarChartWithProvider(List<dynamic> habits, ThemeData theme, bool isDark) {
    if (habits.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(child: Text('No habits to display')),
      );
    }

    final startDate = _getHabitChartStartDate();
    final completionCountsAsync = ref.watch(habitCompletionCountsProvider(startDate));

    return completionCountsAsync.when(
      loading: () => const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => SizedBox(
        height: 100,
        child: Center(child: Text('Error: $error')),
      ),
      data: (completionCounts) {
        final data = habits.map((habit) => _HabitChartData(
          name: habit.title,
          emoji: habit.icon ?? '📌',
          value: completionCounts[habit.id] ?? 0,
        )).toList();
        
        // Sort by value descending
        data.sort((a, b) => b.value.compareTo(a.value));
        
        if (data.isEmpty) {
          return const SizedBox(
            height: 100,
            child: Center(child: Text('No data available')),
          );
        }

        final maxValue = data.map((d) => d.value).reduce((a, b) => a > b ? a : b);
        final normalizedMax = maxValue > 0 ? maxValue : 1;

        // Soft, calm color palette for bars
        final barColors = [
          const Color(0xFF7986CB), // Indigo
          const Color(0xFF4DB6AC), // Teal
          const Color(0xFFFFB74D), // Orange
          const Color(0xFF81C784), // Green
          const Color(0xFFBA68C8), // Purple
          const Color(0xFF64B5F6), // Blue
          const Color(0xFFE57373), // Red
          const Color(0xFFA1887F), // Brown
          const Color(0xFF90A4AE), // Blue Grey
          const Color(0xFFDCE775), // Lime
        ];

        return SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: data.length,
            itemBuilder: (context, index) {
              final item = data[index];
              final barColor = barColors[index % barColors.length];
              final barHeight = (item.value / normalizedMax) * 100;

              return Container(
                width: 60,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Value label
                    if (item.value > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${item.value}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    // Bar
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      height: barHeight.clamp(4.0, 100.0),
                      width: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            barColor.withValues(alpha: 0.9),
                            barColor.withValues(alpha: 0.6),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: item.value > 0
                            ? [
                                BoxShadow(
                                  color: barColor.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Habit emoji
                    Text(
                      item.emoji,
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 2),
                    // Habit name (truncated)
                    SizedBox(
                      width: 56,
                      child: Text(
                        item.name,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildHabitChartFilters(ThemeData theme, bool isDark) {
    final filters = [
      ('week', 'Week'),
      ('month', 'Month'),
      ('quarter', 'Quarter'),
      ('year', 'Year'),
      ('lifetime', 'All Time'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey.shade800.withValues(alpha: 0.5)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _habitChartFilter,
          isDense: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
          dropdownColor: isDark ? theme.colorScheme.surface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          items: filters.map((filter) {
            return DropdownMenuItem<String>(
              value: filter.$1,
              child: Text(
                filter.$2,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: _habitChartFilter == filter.$1
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                  fontWeight: _habitChartFilter == filter.$1
                      ? FontWeight.w600
                      : FontWeight.w500,
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _habitChartFilter = value;
              });
              // Invalidate the provider to fetch fresh data for new date range
              ref.invalidate(habitCompletionCountsProvider);
            }
          },
        ),
      ),
    );
  }
}

/// Helper class for habit comparison chart data
class _HabitChartData {
  final String name;
  final String emoji;
  final int value;

  _HabitChartData({
    required this.name,
    required this.emoji,
    required this.value,
  });
}

/// Custom painter for the line chart
class _LineChartPainter extends CustomPainter {
  final List<_ChartData> data;
  final double maxValue;
  final Color lineColor;
  final Color currentPointColor;
  final Color textColor;
  final Color primaryColor;
  final bool isDark;

  _LineChartPainter({
    required this.data,
    required this.maxValue,
    required this.lineColor,
    required this.currentPointColor,
    required this.textColor,
    required this.primaryColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const double pointSpacing = 52.0;
    const double topPadding = 20.0;
    const double bottomPadding = 30.0;
    final chartHeight = size.height - topPadding - bottomPadding;

    // Create points
    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = (i * pointSpacing) + (pointSpacing / 2);
      final normalizedValue = maxValue > 0 ? data[i].value / maxValue : 0.0;
      final y = topPadding + chartHeight * (1 - normalizedValue);
      points.add(Offset(x, y));
    }

    // Draw subtle horizontal guide lines
    final guideLinePaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)
      ..strokeWidth = 1;
    
    for (int i = 0; i <= 3; i++) {
      final y = topPadding + (chartHeight / 3) * i;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        guideLinePaint,
      );
    }

    // Draw gradient fill under the line
    if (points.length >= 2) {
      final fillPath = Path();
      fillPath.moveTo(points.first.dx, size.height - bottomPadding);
      for (final point in points) {
        fillPath.lineTo(point.dx, point.dy);
      }
      fillPath.lineTo(points.last.dx, size.height - bottomPadding);
      fillPath.close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: 0.3),
            lineColor.withValues(alpha: 0.05),
          ],
        ).createShader(Rect.fromLTWH(0, topPadding, size.width, chartHeight));
      
      canvas.drawPath(fillPath, fillPaint);
    }

    // Draw the line with smooth curves
    if (points.length >= 2) {
      final linePaint = Paint()
        ..color = lineColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path();
      path.moveTo(points.first.dx, points.first.dy);

      // Use smooth curves between points
      for (int i = 1; i < points.length; i++) {
        final prev = points[i - 1];
        final curr = points[i];
        final controlX = (prev.dx + curr.dx) / 2;
        path.cubicTo(controlX, prev.dy, controlX, curr.dy, curr.dx, curr.dy);
      }

      canvas.drawPath(path, linePaint);
    }

    // Draw data points
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final isCurrentPeriod = data[i].isCurrentPeriod;
      final pointColor = isCurrentPeriod ? currentPointColor : lineColor;
      
      // Outer circle (subtle glow)
      if (data[i].value > 0) {
        final glowPaint = Paint()
          ..color = pointColor.withValues(alpha: 0.2)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(point, 6, glowPaint);
      }
      
      // Main point
      final pointPaint = Paint()
        ..color = data[i].value > 0 ? pointColor : pointColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(point, 4, pointPaint);
      
      // White inner for current period
      if (isCurrentPeriod && data[i].value > 0) {
        final innerPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(point, 2, innerPaint);
      }

      // Draw labels
      final textSpan = TextSpan(
        text: data[i].label,
        style: TextStyle(
          color: isCurrentPeriod ? primaryColor : textColor,
          fontSize: 10,
          fontWeight: isCurrentPeriod ? FontWeight.w600 : FontWeight.w500,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout(maxWidth: pointSpacing - 4);
      textPainter.paint(
        canvas,
        Offset(point.dx - textPainter.width / 2, size.height - bottomPadding + 8),
      );

      // Draw value above point if > 0
      if (data[i].value > 0) {
        final valueSpan = TextSpan(
          text: '${data[i].value}',
          style: TextStyle(
            color: textColor,
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        );
        final valuePainter = TextPainter(
          text: valueSpan,
          textDirection: ui.TextDirection.ltr,
          textAlign: TextAlign.center,
        );
        valuePainter.layout();
        valuePainter.paint(
          canvas,
          Offset(point.dx - valuePainter.width / 2, point.dy - 16),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return data != oldDelegate.data ||
        maxValue != oldDelegate.maxValue ||
        lineColor != oldDelegate.lineColor ||
        isDark != oldDelegate.isDark;
  }
}

/// Helper class for chart data
class _ChartData {
  final String label;
  final int value;
  final bool isCurrentPeriod;

  _ChartData({
    required this.label,
    required this.value,
    this.isCurrentPeriod = false,
  });
}