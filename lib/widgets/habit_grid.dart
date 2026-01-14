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

  // Fixed dimensions - prioritize habit name visibility
  static const double _habitColumnWidth = 160.0;
  static const double _dateCellWidth = 44.0;
  static const double _headerHeight = 44.0;
  static const double _rowHeight = 52.0;

  @override
  void initState() {
    super.initState();
    _generateDates();
    _loadCompletions();
  }

  @override
  void didUpdateWidget(covariant HabitGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload completions if habits list changed
    if (widget.habits.length != oldWidget.habits.length ||
        widget.habits.map((h) => h.id).join(',') != 
        oldWidget.habits.map((h) => h.id).join(',')) {
      _loadCompletions();
    }
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

    for (final habit in widget.habits) {
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

  Future<void> _toggleCompletion(Habit habit, DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final isCompleted = _completions[habit.id]?.contains(dateStr) ?? false;

    if (isCompleted) {
      // If already completed, show options to edit notes or undo
      await _showCompletionOptionsSheet(habit.id, date, dateStr);
    } else {
      // If not completed, show popup to add completion with optional notes
      await _showAddCompletionSheet(habit, date, dateStr);
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
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
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
                          color: theme.colorScheme.primaryContainer.withOpacity(0.3),
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
                                  color: theme.colorScheme.onSurface.withOpacity(0.8),
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
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
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

    if (widget.habits.isEmpty) {
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
            habits: widget.habits,
            rowHeight: _rowHeight,
            buildHabitNameCell: (habit) => _buildHabitNameCell(habit, theme, isDark),
            buildHabitRow: (habit) => _buildHabitCompletionRow(habit, theme, isDark),
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

    return GestureDetector(
      onTap: () => _toggleCompletion(habit, date),
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
                color: isCompleted
                    ? habitColor.withValues(alpha: 0.25)
                    : isDark
                        ? Colors.grey.shade800.withValues(alpha: 0.25)
                        : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isCompleted
                      ? habitColor.withValues(alpha: 0.4)
                      : isToday
                          ? theme.colorScheme.primary.withValues(alpha: 0.25)
                          : isDark
                              ? Colors.grey.shade700.withValues(alpha: 0.3)
                              : Colors.grey.shade200,
                  width: isToday ? 1.5 : 0.5,
                ),
              ),
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

/// A synchronized scroll grid widget that keeps habit names and completion cells
/// perfectly aligned during horizontal scrolling
class _SyncedScrollGrid extends StatefulWidget {
  final ScrollController horizontalController;
  final ScrollController verticalController;
  final double habitColumnWidth;
  final double scrollableWidth;
  final List<Habit> habits;
  final double rowHeight;
  final Widget Function(Habit habit) buildHabitNameCell;
  final Widget Function(Habit habit) buildHabitRow;

  const _SyncedScrollGrid({
    required this.horizontalController,
    required this.verticalController,
    required this.habitColumnWidth,
    required this.scrollableWidth,
    required this.habits,
    required this.rowHeight,
    required this.buildHabitNameCell,
    required this.buildHabitRow,
  });

  @override
  State<_SyncedScrollGrid> createState() => _SyncedScrollGridState();
}

class _SyncedScrollGridState extends State<_SyncedScrollGrid> {
  late ScrollController _gridHorizontalController;
  late ScrollController _namesVerticalController;
  late ScrollController _gridVerticalController;
  bool _isSyncingNames = false;
  bool _isSyncingGrid = false;
  bool _isSyncingHorizontal = false;
  bool _isSyncingFromHeader = false;

  @override
  void initState() {
    super.initState();
    _gridHorizontalController = ScrollController();
    _namesVerticalController = ScrollController();
    _gridVerticalController = ScrollController();

    // Sync horizontal scroll bidirectionally between header and body
    _gridHorizontalController.addListener(_onGridHorizontalScroll);
    widget.horizontalController.addListener(_onHeaderHorizontalScroll);
    
    // Sync vertical scroll between names and grid
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
    if (_isSyncingNames) return;
    _isSyncingGrid = true;
    
    if (_gridVerticalController.hasClients) {
      _gridVerticalController.jumpTo(_namesVerticalController.offset);
    }
    
    _isSyncingGrid = false;
  }

  void _onGridVerticalScroll() {
    if (_isSyncingGrid) return;
    _isSyncingNames = true;
    
    if (_namesVerticalController.hasClients) {
      _namesVerticalController.jumpTo(_gridVerticalController.offset);
    }
    
    _isSyncingNames = false;
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
    return Row(
      children: [
        // Fixed habit names column (vertical scroll synced with grid)
        SizedBox(
          width: widget.habitColumnWidth,
          child: ListView.builder(
            controller: _namesVerticalController,
            physics: const ClampingScrollPhysics(),
            itemCount: widget.habits.length,
            itemBuilder: (context, index) {
              return widget.buildHabitNameCell(widget.habits[index]);
            },
          ),
        ),
        // Scrollable completion grid (horizontal + vertical)
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
                itemCount: widget.habits.length,
                itemBuilder: (context, index) {
                  return widget.buildHabitRow(widget.habits[index]);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
