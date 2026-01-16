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
    this.daysToShow = 7,
  });

  @override
  ConsumerState<HabitGrid> createState() => _HabitGridState();
}

class _HabitGridState extends ConsumerState<HabitGrid> {
  final DatabaseService _db = DatabaseService();
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  late List<DateTime> _dates;
  Map<String, Set<String>> _completions = {}; // habitId -> set of date strings
  Map<String, Set<String>> _completionsWithNotes = {}; // habitId -> set of date strings that have notes
  bool _notePromptOnTap = false; // Cached setting value
  
  // Local habits list for optimistic reordering (prevents flicker)
  List<Habit>? _localHabits;
  
  /// Get the current habits list (local if reordering, otherwise from widget)
  List<Habit> get _habits => _localHabits ?? widget.habits;

  // Fixed dimensions - prioritize habit name visibility
  static const double _habitColumnWidth = 160.0;
  static const double _dateCellWidth = 44.0;
  static const double _headerHeight = 44.0;
  static const double _rowHeight = 52.0;

  /// Determines if a date shows a "fulfilled" state for frequency-based habits
  /// Returns: true if the frequency goal has been met and this day is in the fulfilled window
  /// Fulfilled = goal achieved, remaining days in period show subtle "done" indication
  bool _isFulfilledDay(Habit habit, DateTime date) {
    final today = DateTime.now();
    final dateOnly = DateTime(date.year, date.month, date.day);
    final todayOnly = DateTime(today.year, today.month, today.day);
    
    // Don't show fulfilled state for future dates
    if (dateOnly.isAfter(todayOnly)) return false;
    
    // Don't show on days that are already completed
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final isCompleted = _completions[habit.id]?.contains(dateStr) ?? false;
    if (isCompleted) return false;
    
    final completions = _completions[habit.id] ?? {};
    
    switch (habit.frequency) {
      case HabitFrequency.daily:
        // Daily habits - no fulfilled state (every day needs completion)
        return false;
        
      case HabitFrequency.everyXDays:
        // Every X days - show fulfilled for remaining days in current cycle after completion
        final interval = habit.customDays ?? 2;
        
        // Find the start of the current cycle containing this date
        // Cycles are based on the most recent completion before or on this date
        DateTime? lastCompletionBeforeOrOn;
        for (final cDateStr in completions) {
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
        
        // This date is within the fulfilled window if it's after the completion
        // but before the next due date (within the X-day cycle)
        final daysSinceCompletion = dateOnly.difference(lastCompletionBeforeOrOn).inDays;
        return daysSinceCompletion > 0 && daysSinceCompletion < interval;
        
      case HabitFrequency.timesPerWeek:
        // X times per week - show fulfilled when weekly goal is met
        final required = habit.customDays ?? 3;
        
        // Get the week containing this date
        final weekStart = dateOnly.subtract(Duration(days: dateOnly.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 6));
        
        // Count completions in this week
        int weekCompletions = 0;
        for (final cDateStr in completions) {
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
        final required = habit.customDays ?? 10;
        
        // Count completions in this month
        int monthCompletions = 0;
        for (final cDateStr in completions) {
          final d = DateTime.parse(cDateStr);
          if (d.year == dateOnly.year && d.month == dateOnly.month) {
            monthCompletions++;
          }
        }
        
        // Show fulfilled if monthly target is met
        return monthCompletions >= required;
        
      case HabitFrequency.specificDays:
        // Specific days - show fulfilled when all selected days in the week are completed
        final selectedDaysMask = habit.customDays ?? 0;
        
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
            if (completions.contains(dayDateStr)) {
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
    _generateDates();
    _loadCompletions();
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

  @override
  void didUpdateWidget(covariant HabitGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Clear local reorder state when provider updates match our order
    if (_localHabits != null) {
      final localIds = _localHabits!.map((h) => h.id).join(',');
      final widgetIds = widget.habits.map((h) => h.id).join(',');
      if (localIds == widgetIds) {
        // Provider caught up - clear local state
        _localHabits = null;
      }
    }
    
    // Reload completions if habits list changed
    if (widget.habits.length != oldWidget.habits.length ||
        widget.habits.map((h) => h.id).join(',') != 
        oldWidget.habits.map((h) => h.id).join(',')) {
      _loadCompletions();
    }
    // Reload settings in case they changed
    _loadSettings();
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
    final completionsWithNotes = <String, Set<String>>{};

    for (final habit in _habits) {
      final habitCompletions = await _db.getCompletionsForHabit(habit.id);
      completions[habit.id] = habitCompletions
          .map((c) => DateFormat('yyyy-MM-dd').format(c.date))
          .toSet();
      completionsWithNotes[habit.id] = habitCompletions
          .where((c) => c.notes != null && c.notes!.isNotEmpty)
          .map((c) => DateFormat('yyyy-MM-dd').format(c.date))
          .toSet();
    }

    if (mounted) {
      setState(() {
        _completions = completions;
        _completionsWithNotes = completionsWithNotes;
      });
    }
  }

  /// Handles reordering of habits via drag-and-drop
  Future<void> _onReorderHabits(int oldIndex, int newIndex) async {
    // Adjust index if moving down (ReorderableListView behavior)
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    
    // Skip if no actual change
    if (oldIndex == newIndex) return;
    
    // Optimistic update: update local state immediately (no flicker)
    final reorderedHabits = List<Habit>.from(_habits);
    final habit = reorderedHabits.removeAt(oldIndex);
    reorderedHabits.insert(newIndex, habit);
    
    setState(() {
      _localHabits = reorderedHabits;
    });
    
    // Get the new order of habit IDs
    final habitIds = reorderedHabits.map((h) => h.id).toList();
    
    // Save to database in background
    await _db.updateHabitSortOrders(habitIds);
    
    // Silently refresh provider - our local state prevents flicker
    ref.invalidate(habitsProvider);
  }

  /// Handles tap on a completion cell based on notePromptOnTap setting
  Future<void> _onCompletionTap(Habit habit, DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final isCompleted = _completions[habit.id]?.contains(dateStr) ?? false;

    if (isCompleted) {
      // Check if this completion has notes
      final hasNotes = _completionsWithNotes[habit.id]?.contains(dateStr) ?? false;
      if (hasNotes) {
        // Has notes - show options sheet to review/edit before unchecking
        await _showCompletionOptionsSheet(habit.id, date, dateStr);
      } else {
        // No notes - quick undo without popup
        await _quickUndo(habit.id, date, dateStr);
      }
    } else {
      // If not completed, behavior depends on setting
      if (_notePromptOnTap) {
        // Tap opens notes popup
        await _showAddCompletionSheet(habit, date, dateStr);
      } else {
        // Tap marks immediately
        await _quickComplete(habit, date, dateStr);
      }
    }
  }

  /// Handles long-press on a completion cell based on notePromptOnTap setting
  Future<void> _onCompletionLongPress(Habit habit, DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final isCompleted = _completions[habit.id]?.contains(dateStr) ?? false;

    if (isCompleted) {
      // Always show options sheet on long-press to allow editing notes
      await _showCompletionOptionsSheet(habit.id, date, dateStr);
    } else {
      // If not completed, behavior depends on setting (opposite of tap)
      if (_notePromptOnTap) {
        // Long-press marks immediately (opposite of tap)
        await _quickComplete(habit, date, dateStr);
      } else {
        // Long-press opens notes popup (opposite of tap)
        await _showAddCompletionSheet(habit, date, dateStr);
      }
    }
  }

  /// Quick undo completion without showing popup
  Future<void> _quickUndo(String habitId, DateTime date, String dateStr) async {
    // Optimistic update
    setState(() {
      _completions[habitId]?.remove(dateStr);
      _completionsWithNotes[habitId]?.remove(dateStr);
    });

    try {
      await _db.undoCompletion(habitId, date);
      ref.invalidate(dailyStatsProvider);
      ref.invalidate(heatmapProvider);
      ref.invalidate(completionStateProvider(habitId));
      ref.invalidate(habitCompletionCountsProvider);
    } catch (e) {
      // Rollback on error
      setState(() {
        _completions[habitId] ??= {};
        _completions[habitId]!.add(dateStr);
      });
    }
  }

  /// Quick complete without showing notes popup
  Future<void> _quickComplete(Habit habit, DateTime date, String dateStr) async {
    // Optimistic update
    setState(() {
      _completions[habit.id] ??= {};
      _completions[habit.id]!.add(dateStr);
    });

    try {
      await _db.recordCompletion(habit.id, date);
      ref.invalidate(dailyStatsProvider);
      ref.invalidate(heatmapProvider);
      ref.invalidate(completionStateProvider(habit.id));
      ref.invalidate(habitCompletionCountsProvider);
    } catch (e) {
      // Rollback on error
      setState(() {
        _completions[habit.id]!.remove(dateStr);
      });
    }
  }

  Future<void> _showAddCompletionSheet(Habit habit, DateTime date, String dateStr) async {
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
                    if (habit.icon != null && habit.icon!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          habit.icon!,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        habit.title,
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
                  if (habit.description != null && habit.description!.isNotEmpty) {
                    if (habit.description!.contains('|||')) {
                      final parts = habit.description!.split('|||');
                      if (parts[0].isNotEmpty) {
                        reflectiveQuestion = parts[0];
                      }
                    } else {
                      // If no separator, treat as reflective question
                      reflectiveQuestion = habit.description;
                    }
                  }
                  
                  if (reflectiveQuestion == null || reflectiveQuestion.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  
                  return Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
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
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
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
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      hintText: 'Add notes (optional)',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.all(16),
                      hintStyle: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
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
      // User confirmed - add completion
      final notes = notesController.text.trim().isEmpty ? null : notesController.text.trim();
      
      setState(() {
        _completions[habit.id] ??= {};
        _completions[habit.id]!.add(dateStr);
        _completionsWithNotes[habit.id] ??= {};
        if (notes != null) {
          _completionsWithNotes[habit.id]!.add(dateStr);
        }
      });

      try {
        await _db.recordCompletion(habit.id, date, notes: notes);
        ref.invalidate(dailyStatsProvider);
        ref.invalidate(heatmapProvider);
        ref.invalidate(completionStateProvider(habit.id));
        ref.invalidate(habitCompletionCountsProvider);
      } catch (e) {
        setState(() {
          _completions[habit.id]!.remove(dateStr);
          _completionsWithNotes[habit.id]!.remove(dateStr);
        });
      }
    }
    
    notesController.dispose();
  }

  Future<void> _showCompletionOptionsSheet(String habitId, DateTime date, String dateStr) async {
    // Load existing completion to get notes
    final completion = await _db.getCompletionForDate(habitId, date);
    if (!mounted) return;
    
    final notesController = TextEditingController(text: completion?.notes ?? '');
    
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
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      hintText: 'Add notes (optional)',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.all(16),
                      hintStyle: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
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
      // User wants to undo completion
      setState(() {
        _completions[habitId]!.remove(dateStr);
        _completionsWithNotes[habitId]?.remove(dateStr);
      });

      try {
        await _db.undoCompletion(habitId, date);
        ref.invalidate(dailyStatsProvider);
        ref.invalidate(heatmapProvider);
        ref.invalidate(completionStateProvider(habitId));
        ref.invalidate(habitCompletionCountsProvider);
      } catch (e) {
        setState(() {
          _completions[habitId]!.add(dateStr);
        });
      }
    } else if (result == 'save') {
      // User wants to save notes
      try {
        final notes = notesController.text.trim().isEmpty ? null : notesController.text.trim();
        await _db.updateCompletionNotes(habitId, date, notes);
        
        // Update notes indicator
        setState(() {
          _completionsWithNotes[habitId] ??= {};
          if (notes != null) {
            _completionsWithNotes[habitId]!.add(dateStr);
          } else {
            _completionsWithNotes[habitId]!.remove(dateStr);
          }
        });
      } catch (e) {
        // Ignore errors for notes update
      }
    }
    
    notesController.dispose();
  }

  void _onHabitTapped(Habit habit) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => HabitDetailsScreen(habitId: habit.id),
      ),
    )
        .then((_) {
      // Refresh data when returning from details screen
      _loadCompletions();
      ref.invalidate(habitsProvider);
      ref.invalidate(dailyStatsProvider);
    });
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Watch the setting provider for reactive updates
    final notePromptSetting = ref.watch(notePromptOnTapProvider);
    notePromptSetting.whenData((value) {
      if (_notePromptOnTap != value) {
        // Use addPostFrameCallback to avoid setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _notePromptOnTap = value;
            });
          }
        });
      }
    });

    if (_habits.isEmpty) {
      return _buildEmptyState(theme);
    }

    // Calculate total grid width for scrollable area
    final scrollableWidth = _dateCellWidth * _dates.length;

    return Column(
      children: [
        // Fixed header row with synchronized horizontal scroll
        SizedBox(
          height: _headerHeight,
          child: Row(
            children: [
              // Fixed "Habits" label
              Container(
                width: _habitColumnWidth,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: isDark ? theme.colorScheme.surface : Colors.grey.shade50,
                  border: Border(
                    bottom: BorderSide(
                      color: theme.dividerColor,
                      width: 1,
                    ),
                  ),
                ),
                child: Text(
                  'Habits',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
              // Scrollable date headers - synced bidirectionally with body
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? theme.colorScheme.surface : Colors.grey.shade50,
                    border: Border(
                      bottom: BorderSide(
                        color: theme.dividerColor,
                        width: 1,
                      ),
                    ),
                  ),
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      // This prevents scroll notifications from bubbling up
                      // The actual sync is handled by the scroll controller listener
                      return false;
                    },
                    child: SingleChildScrollView(
                      controller: _horizontalScrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
                      child: SizedBox(
                        width: scrollableWidth,
                        child: Row(
                          children: _dates.map((date) {
                            final isToday = _isToday(date);
                            return _buildDateCell(date, theme, isDark, isToday);
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Scrollable grid body - vertical + horizontal synchronized
        Expanded(
          child: _SyncedScrollGrid(
            horizontalController: _horizontalScrollController,
            verticalController: _verticalScrollController,
            habitColumnWidth: _habitColumnWidth,
            scrollableWidth: scrollableWidth,
            habits: _habits,
            rowHeight: _rowHeight,
            buildHabitNameCell: (habit) => _buildHabitNameCell(habit, theme, isDark),
            buildHabitRow: (habit) => _buildHabitCompletionRow(habit, theme, isDark),
            onReorder: _onReorderHabits,
          ),
        ),
      ],
    );
  }

  Widget _buildDateCell(
      DateTime date, ThemeData theme, bool isDark, bool isToday) {
    return SizedBox(
      width: _dateCellWidth,
      child: Center(
        child: Container(
          width: _dateCellWidth - 12, // Match completion cell inner width (44 - 6*2 = 32)
          padding: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: isToday
                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat('E').format(date).substring(0, 1),
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isToday
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 9,
                ),
              ),
              Text(
                DateFormat('d').format(date),
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isToday
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHabitNameCell(Habit habit, ThemeData theme, bool isDark) {
    return GestureDetector(
      onTap: () => _onHabitTapped(habit),
      child: Container(
        height: _rowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: theme.dividerColor.withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            if (habit.icon != null)
              Text(habit.icon!, style: const TextStyle(fontSize: 16)),
            if (habit.icon != null) const SizedBox(width: 8),
            Expanded(
              child: Text(
                habit.title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitCompletionRow(Habit habit, ThemeData theme, bool isDark) {
    final habitColor = _parseColor(habit.color);

    return Container(
      height: _rowHeight,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: _dates.map((date) {
          return _buildCompletionCell(habit, date, habitColor, theme, isDark);
        }).toList(),
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
    final hasNotes = _completionsWithNotes[habit.id]?.contains(dateStr) ?? false;
    final isToday = _isToday(date);
    final isFulfilled = _isFulfilledDay(habit, date);

    return GestureDetector(
      onTap: () => _onCompletionTap(habit, date),
      onLongPress: () => _onCompletionLongPress(habit, date),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: _dateCellWidth,
        height: _rowHeight,
        padding: const EdgeInsets.all(6),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                // Fulfilled state: very subtle tint to show "goal met"
                color: isCompleted
                    ? habitColor.withValues(alpha: 0.25)
                    : isFulfilled
                        ? (isDark 
                            ? Colors.green.shade900.withValues(alpha: 0.15)
                            : Colors.green.shade50.withValues(alpha: 0.8))
                        : isDark
                            ? Colors.grey.shade800.withValues(alpha: 0.25)
                            : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isCompleted
                      ? habitColor.withValues(alpha: 0.4)
                      : isToday
                          ? theme.colorScheme.primary.withValues(alpha: 0.25)
                          : isFulfilled
                              ? (isDark 
                                  ? Colors.green.shade700.withValues(alpha: 0.3)
                                  : Colors.green.shade200.withValues(alpha: 0.6))
                              : isDark
                                  ? Colors.grey.shade700.withValues(alpha: 0.3)
                                  : Colors.grey.shade200,
                  width: isToday ? 1.5 : 0.5,
                ),
              ),
              // No icon or symbol for fulfilled - just the subtle background
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: isCompleted
                      ? Icon(
                          Icons.check_rounded,
                          key: const ValueKey('checked'),
                          color: habitColor,
                          size: 16,
                        )
                      : const SizedBox.shrink(key: ValueKey('unchecked')),
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
                        color: Colors.black.withValues(alpha: 0.15),
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
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
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

/// A synchronized scroll grid widget that keeps habit names fixed
/// while allowing horizontal scrolling of completion cells
class _SyncedScrollGrid extends StatefulWidget {
  final ScrollController horizontalController;
  final ScrollController verticalController;
  final double habitColumnWidth;
  final double scrollableWidth;
  final List<Habit> habits;
  final double rowHeight;
  final Widget Function(Habit habit) buildHabitNameCell;
  final Widget Function(Habit habit) buildHabitRow;
  final void Function(int oldIndex, int newIndex)? onReorder;

  const _SyncedScrollGrid({
    required this.horizontalController,
    required this.verticalController,
    required this.habitColumnWidth,
    required this.scrollableWidth,
    required this.habits,
    required this.rowHeight,
    required this.buildHabitNameCell,
    required this.buildHabitRow,
    this.onReorder,
  });

  @override
  State<_SyncedScrollGrid> createState() => _SyncedScrollGridState();
}

class _SyncedScrollGridState extends State<_SyncedScrollGrid> {
  late ScrollController _gridHorizontalController;
  late ScrollController _namesVerticalController;
  late ScrollController _gridVerticalController;
  bool _isSyncingHorizontal = false;
  bool _isSyncingFromHeader = false;
  bool _isSyncingVerticalFromNames = false;
  bool _isSyncingVerticalFromGrid = false;
  
  // Track drag state to hide grid items during drag animation
  int? _draggingIndex;

  @override
  void initState() {
    super.initState();
    _gridHorizontalController = ScrollController();
    _namesVerticalController = ScrollController();
    _gridVerticalController = ScrollController();

    // Sync horizontal scroll bidirectionally between header and body
    _gridHorizontalController.addListener(_onGridHorizontalScroll);
    widget.horizontalController.addListener(_onHeaderHorizontalScroll);
    
    // Sync vertical scroll between names column and grid column
    _namesVerticalController.addListener(_onNamesVerticalScroll);
    _gridVerticalController.addListener(_onGridVerticalScroll);
  }

  void _onGridHorizontalScroll() {
    if (_isSyncingHorizontal || _isSyncingFromHeader) return;
    _isSyncingHorizontal = true;
    
    if (widget.horizontalController.hasClients) {
      widget.horizontalController.jumpTo(_gridHorizontalController.offset);
    }
    
    _isSyncingHorizontal = false;
  }

  void _onHeaderHorizontalScroll() {
    if (_isSyncingFromHeader || _isSyncingHorizontal) return;
    _isSyncingFromHeader = true;
    
    if (_gridHorizontalController.hasClients) {
      _gridHorizontalController.jumpTo(widget.horizontalController.offset);
    }
    
    _isSyncingFromHeader = false;
  }

  void _onNamesVerticalScroll() {
    if (_isSyncingVerticalFromNames || _isSyncingVerticalFromGrid) return;
    _isSyncingVerticalFromNames = true;
    
    if (_gridVerticalController.hasClients) {
      _gridVerticalController.jumpTo(_namesVerticalController.offset);
    }
    
    _isSyncingVerticalFromNames = false;
  }

  void _onGridVerticalScroll() {
    if (_isSyncingVerticalFromGrid || _isSyncingVerticalFromNames) return;
    _isSyncingVerticalFromGrid = true;
    
    if (_namesVerticalController.hasClients) {
      _namesVerticalController.jumpTo(_gridVerticalController.offset);
    }
    
    _isSyncingVerticalFromGrid = false;
  }

  @override
  void dispose() {
    _gridHorizontalController.removeListener(_onGridHorizontalScroll);
    widget.horizontalController.removeListener(_onHeaderHorizontalScroll);
    _namesVerticalController.removeListener(_onNamesVerticalScroll);
    _gridVerticalController.removeListener(_onGridVerticalScroll);
    _gridHorizontalController.dispose();
    _namesVerticalController.dispose();
    _gridVerticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bottomPadding = 80.0;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Two-column layout: fixed habit names on left, scrollable completions on right
    // Both columns must rebuild together when habits list changes to stay in sync
    return Row(
      children: [
        // Fixed habit names column (with drag-to-reorder)
        SizedBox(
          width: widget.habitColumnWidth,
          child: widget.onReorder != null
              ? ReorderableListView.builder(
                  scrollController: _namesVerticalController,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: bottomPadding),
                  itemCount: widget.habits.length,
                  buildDefaultDragHandles: false,
                  onReorderStart: (index) {
                    setState(() {
                      _draggingIndex = index;
                    });
                  },
                  onReorderEnd: (index) {
                    setState(() {
                      _draggingIndex = null;
                    });
                  },
                  onReorder: widget.onReorder!,
                  proxyDecorator: (child, index, animation) {
                    return Material(
                      elevation: 4,
                      color: isDark 
                          ? theme.colorScheme.surfaceContainerHighest
                          : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.3),
                      child: child,
                    );
                  },
                  itemBuilder: (context, index) {
                    final habit = widget.habits[index];
                    return ReorderableDelayedDragStartListener(
                      key: ValueKey('name_${habit.id}'),
                      index: index,
                      child: widget.buildHabitNameCell(habit),
                    );
                  },
                )
              : ListView.builder(
                  controller: _namesVerticalController,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: bottomPadding),
                  itemCount: widget.habits.length,
                  itemBuilder: (context, index) {
                    return KeyedSubtree(
                      key: ValueKey('name_${widget.habits[index].id}'),
                      child: widget.buildHabitNameCell(widget.habits[index]),
                    );
                  },
                ),
        ),
        // Horizontally scrollable completion grid (synced vertically with names column)
        Expanded(
          child: SingleChildScrollView(
            controller: _gridHorizontalController,
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: SizedBox(
              width: widget.scrollableWidth,
              child: ListView.builder(
                controller: _gridVerticalController,
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: bottomPadding),
                itemCount: widget.habits.length,
                itemBuilder: (context, index) {
                  final habit = widget.habits[index];
                  // Make the grid row semi-transparent when its name is being dragged
                  final isDragging = _draggingIndex == index;
                  return KeyedSubtree(
                    key: ValueKey('grid_${habit.id}'),
                    child: Opacity(
                      opacity: isDragging ? 0.3 : 1.0,
                      child: widget.buildHabitRow(habit),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
