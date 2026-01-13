import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/habit.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../providers/habit_provider.dart';

const List<String> habitColors = [
  '#FF6B6B',
  '#FFA94D',
  '#FFD93D',
  '#6BCB77',
  '#4D96FF',
  '#A78BFA',
  '#FF88CC',
  '#4ECDC4',
];

const List<String> habitIcons = [
  '🏃',
  '📚',
  '🧘',
  '💪',
  '🚴',
  '🎨',
  '🎵',
  '💻',
  '🥗',
  '😴',
  '🚶',
  '⛹️',
];

class AddHabitScreen extends ConsumerStatefulWidget {
  final String? habitId;

  const AddHabitScreen({
    super.key,
    this.habitId,
  });

  @override
  ConsumerState<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends ConsumerState<AddHabitScreen> {
  late TextEditingController titleController;
  late TextEditingController descriptionController;
  late TextEditingController questionController;
  late DatabaseService _db;
  late NotificationService _notificationService;

  String frequency = 'daily';
  int everyXDaysValue = 2; // For everyXDays
  int timesPerWeekValue = 3; // For timesPerWeek
  int timesPerMonthValue = 10; // For timesPerMonth
  List<int> selectedWeekDays = [1, 3, 5]; // Mon, Wed, Fri for specificDays
  String selectedColor = habitColors[0];
  String selectedIcon = habitIcons[0];
  bool hasReminder = false;
  TimeOfDay selectedTime = const TimeOfDay(hour: 9, minute: 0);
  Habit? existingHabit;
  bool isLoading = true;
  bool _showMoreOptions = true;

  final List<String> weekDayNames = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun'
  ];

  @override
  void initState() {
    super.initState();
    _db = DatabaseService();
    _notificationService = NotificationService();
    titleController = TextEditingController();
    descriptionController = TextEditingController();
    questionController = TextEditingController();

    if (widget.habitId != null) {
      _loadHabit();
    } else {
      isLoading = false;
    }
  }

  void _loadHabit() async {
    final habit = await _db.getHabitById(widget.habitId!);
    if (habit != null) {
      setState(() {
        existingHabit = habit;
        titleController.text = habit.title;
        
        // Parse description: format is "QUESTION|||NOTES" or just notes
        if (habit.description != null && habit.description!.contains('|||')) {
          final parts = habit.description!.split('|||');
          questionController.text = parts[0];
          descriptionController.text = parts.length > 1 ? parts[1] : '';
        } else {
          descriptionController.text = habit.description ?? '';
        }
        
        frequency = habit.frequency.toString().split('.').last;

        // Load custom values based on frequency
        if (habit.customDays != null) {
          switch (habit.frequency) {
            case HabitFrequency.everyXDays:
              everyXDaysValue = habit.customDays!;
              break;
            case HabitFrequency.timesPerWeek:
              timesPerWeekValue = habit.customDays!;
              break;
            case HabitFrequency.timesPerMonth:
              timesPerMonthValue = habit.customDays!;
              break;
            case HabitFrequency.specificDays:
              // customDays stores as bitmask: Mon=1, Tue=2, Wed=4, Thu=8, Fri=16, Sat=32, Sun=64
              selectedWeekDays = [];
              for (int i = 0; i < 7; i++) {
                if ((habit.customDays! & (1 << i)) != 0) {
                  selectedWeekDays.add(i);
                }
              }
              break;
            default:
              break;
          }
        }

        selectedColor = habit.color ?? habitColors[0];
        selectedIcon = habit.icon ?? habitIcons[0];
        hasReminder = habit.reminderTime != null;
        if (habit.reminderTime != null) {
          final parts = habit.reminderTime!.split(':');
          selectedTime = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }
        isLoading = false;
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _timeToString(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Theme.of(context).colorScheme.surface,
              hourMinuteShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              dayPeriodShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => selectedTime = picked);
    }
  }

  int? _getCustomDaysValue() {
    switch (frequency) {
      case 'everyXDays':
        return everyXDaysValue;
      case 'timesPerWeek':
        return timesPerWeekValue;
      case 'timesPerMonth':
        return timesPerMonthValue;
      case 'specificDays':
        // Store as bitmask
        int bitmask = 0;
        for (int day in selectedWeekDays) {
          bitmask |= (1 << day);
        }
        return bitmask;
      default:
        return null;
    }
  }

  void _saveHabit() async {
    if (titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a habit title')),
      );
      return;
    }

    try {
      // Combine question and notes into description field
      String? combinedDescription;
      final question = questionController.text.trim();
      final notes = descriptionController.text.trim();
      
      if (question.isNotEmpty || notes.isNotEmpty) {
        if (question.isNotEmpty && notes.isNotEmpty) {
          combinedDescription = '$question|||$notes';
        } else if (question.isNotEmpty) {
          combinedDescription = '$question|||';
        } else {
          combinedDescription = notes;
        }
      }
      
      final habit = Habit(
        id: existingHabit?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        title: titleController.text,
        description: combinedDescription,
        frequency: HabitFrequency.values.firstWhere(
          (f) => f.toString().split('.').last == frequency,
        ),
        customDays: _getCustomDaysValue(),
        color: selectedColor,
        icon: selectedIcon,
        reminderTime: hasReminder ? _timeToString(selectedTime) : null,
        createdAt: existingHabit?.createdAt ?? DateTime.now(),
        archivedAt: existingHabit?.archivedAt,
      );

      if (existingHabit != null) {
        await _db.updateHabit(habit);
      } else {
        await _db.createHabit(habit);
      }

      // Handle notifications
      if (hasReminder) {
        await _notificationService.scheduleReminder(habit);
      } else if (existingHabit?.reminderTime != null) {
        // Cancel existing reminder if turned off
        await _notificationService.cancelReminder(habit.id);
      }

      // Invalidate providers to refresh the habits list
      ref.invalidate(habitsProvider);
      ref.invalidate(dailyStatsProvider);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  void _deleteHabit() async {
    if (existingHabit == null) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Habit?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await _notificationService.cancelReminder(existingHabit!.id);
      await _db.deleteHabit(existingHabit!.id);
      ref.invalidate(habitsProvider);
      ref.invalidate(dailyStatsProvider);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    questionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(existingHabit == null ? 'New Habit' : 'Edit Habit'),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saveHabit,
            child: Text(
              existingHabit == null ? 'Create' : 'Save',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title Input - Matching style with other controls
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Center(
                  child: TextField(
                    controller: titleController,
                    autofocus: existingHabit == null,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Habit name',
                      hintStyle: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Question field - Matching style with other controls
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Center(
                  child: TextField(
                    controller: questionController,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontStyle: FontStyle.italic,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Add a reflective question (optional)',
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        fontStyle: FontStyle.italic,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Icon & Color Row - Both as buttons
              _buildIconColorRow(theme),

              const SizedBox(height: 20),

              // Frequency - Compact card
              _buildCompactFrequencySelector(theme),

              const SizedBox(height: 16),

              // More Options - Expandable
              _buildMoreOptionsSection(theme),

              const Spacer(),

              // Delete button for existing habits (at bottom)
              if (existingHabit != null)
                Center(
                  child: TextButton(
                    onPressed: _deleteHabit,
                    child: Text(
                      'Delete Habit',
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconColorRow(ThemeData theme) {
    final selectedColorValue = Color(int.parse(selectedColor.replaceFirst('#', '0xff')));
    
    return Row(
      children: [
        // Icon selector button
        Expanded(
          child: GestureDetector(
            onTap: _showIconPicker,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Text(selectedIcon, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Icon',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Color selector button
        Expanded(
          child: GestureDetector(
            onTap: _showColorPicker,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: selectedColorValue,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Color',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactFrequencySelector(ThemeData theme) {
    return InkWell(
      onTap: _showFrequencyPicker,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getFrequencyIcon(),
                color: theme.colorScheme.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getFrequencyTitle(),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _getFrequencySubtitle(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreOptionsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Expandable header
        InkWell(
          onTap: () => setState(() => _showMoreOptions = !_showMoreOptions),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  _showMoreOptions
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_right_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  'More options',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Expandable content
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _showMoreOptions
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description - Matching style with other controls
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      hintText: 'Add a note (optional)',
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    maxLines: 2,
                    minLines: 1,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),

                const SizedBox(height: 12),

                // Reminder toggle
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.notifications_outlined,
                        size: 20,
                        color: hasReminder
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          hasReminder
                              ? 'Reminder at ${_formatTimeOfDay(selectedTime)}'
                              : 'Set a reminder',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (hasReminder)
                        GestureDetector(
                          onTap: _pickTime,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              'Change',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      Switch(
                        value: hasReminder,
                        onChanged: (value) async {
                          setState(() => hasReminder = value);
                          if (value) {
                            await _pickTime();
                          }
                        },
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showIconPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Choose an icon',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 6,
              shrinkWrap: true,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: habitIcons.map((icon) {
                final isSelected = selectedIcon == icon;
                return GestureDetector(
                  onTap: () {
                    setState(() => selectedIcon = icon);
                    Navigator.pop(context);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                          : null,
                    ),
                    child: Center(
                      child: Text(icon, style: const TextStyle(fontSize: 28)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showColorPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Choose a color',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: habitColors.map((color) {
                final colorValue = Color(int.parse(color.replaceFirst('#', '0xff')));
                final isSelected = selectedColor == color;
                return GestureDetector(
                  onTap: () {
                    setState(() => selectedColor = color);
                    Navigator.pop(context);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: colorValue,
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected
                          ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 3)
                          : null,
                      boxShadow: isSelected
                          ? [BoxShadow(color: colorValue.withValues(alpha: 0.5), blurRadius: 12)]
                          : null,
                    ),
                    child: isSelected
                        ? const Center(
                            child: Icon(Icons.check, color: Colors.white, size: 28),
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  IconData _getFrequencyIcon() {
    switch (frequency) {
      case 'daily':
        return Icons.calendar_today_rounded;
      case 'everyXDays':
        return Icons.repeat_rounded;
      case 'timesPerWeek':
        return Icons.date_range_rounded;
      case 'timesPerMonth':
        return Icons.calendar_month_rounded;
      case 'specificDays':
        return Icons.view_week_rounded;
      default:
        return Icons.calendar_today_rounded;
    }
  }

  String _getFrequencyTitle() {
    switch (frequency) {
      case 'daily':
        return 'Every Day';
      case 'everyXDays':
        return 'Every $everyXDaysValue Days';
      case 'timesPerWeek':
        return '$timesPerWeekValue Times Per Week';
      case 'timesPerMonth':
        return '$timesPerMonthValue Times Per Month';
      case 'specificDays':
        return 'Specific Days';
      default:
        return 'Every Day';
    }
  }

  String _getFrequencySubtitle() {
    switch (frequency) {
      case 'daily':
        return 'Complete this habit every day';
      case 'everyXDays':
        return 'Complete every $everyXDaysValue days';
      case 'timesPerWeek':
        return 'Flexible - any $timesPerWeekValue days';
      case 'timesPerMonth':
        return 'Flexible - any $timesPerMonthValue days';
      case 'specificDays':
        return selectedWeekDays.isEmpty
            ? 'Tap to select days'
            : selectedWeekDays.map((d) => weekDayNames[d]).join(', ');
      default:
        return 'Complete this habit every day';
    }
  }

  void _showFrequencyPicker() {
    // Temporary values for the popup
    String tempFrequency = frequency;
    int tempEveryXDays = everyXDaysValue;
    int tempTimesPerWeek = timesPerWeekValue;
    int tempTimesPerMonth = timesPerMonthValue;
    List<int> tempSelectedDays = List.from(selectedWeekDays);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Frequency',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Frequency options
                        _buildPopupFrequencyOption(
                          'daily',
                          'Every Day',
                          Icons.calendar_today_rounded,
                          'Complete this habit daily',
                          tempFrequency,
                          (val) => setModalState(() => tempFrequency = val),
                        ),
                        _buildPopupFrequencyOption(
                          'everyXDays',
                          'Every X Days',
                          Icons.repeat_rounded,
                          'Every $tempEveryXDays days',
                          tempFrequency,
                          (val) => setModalState(() => tempFrequency = val),
                        ),
                        if (tempFrequency == 'everyXDays') ...[
                          const SizedBox(height: 12),
                          _buildPopupNumberSelector(
                            value: tempEveryXDays,
                            min: 2,
                            max: 30,
                            label: 'Every how many days?',
                            onChanged: (val) =>
                                setModalState(() => tempEveryXDays = val),
                          ),
                          const SizedBox(height: 12),
                        ],
                        _buildPopupFrequencyOption(
                          'timesPerWeek',
                          'Times Per Week',
                          Icons.date_range_rounded,
                          '$tempTimesPerWeek times per week',
                          tempFrequency,
                          (val) => setModalState(() => tempFrequency = val),
                        ),
                        if (tempFrequency == 'timesPerWeek') ...[
                          const SizedBox(height: 12),
                          _buildPopupNumberSelector(
                            value: tempTimesPerWeek,
                            min: 1,
                            max: 7,
                            label: 'How many times per week?',
                            onChanged: (val) =>
                                setModalState(() => tempTimesPerWeek = val),
                          ),
                          const SizedBox(height: 12),
                        ],
                        _buildPopupFrequencyOption(
                          'timesPerMonth',
                          'Times Per Month',
                          Icons.calendar_month_rounded,
                          '$tempTimesPerMonth times per month',
                          tempFrequency,
                          (val) => setModalState(() => tempFrequency = val),
                        ),
                        if (tempFrequency == 'timesPerMonth') ...[
                          const SizedBox(height: 12),
                          _buildPopupNumberSelector(
                            value: tempTimesPerMonth,
                            min: 1,
                            max: 31,
                            label: 'How many times per month?',
                            onChanged: (val) =>
                                setModalState(() => tempTimesPerMonth = val),
                          ),
                          const SizedBox(height: 12),
                        ],
                        _buildPopupFrequencyOption(
                          'specificDays',
                          'Specific Days',
                          Icons.view_week_rounded,
                          tempSelectedDays.isEmpty
                              ? 'Select days of the week'
                              : tempSelectedDays
                                  .map((d) => weekDayNames[d])
                                  .join(', '),
                          tempFrequency,
                          (val) => setModalState(() => tempFrequency = val),
                        ),
                        if (tempFrequency == 'specificDays') ...[
                          const SizedBox(height: 16),
                          Text(
                            'Select days of the week',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: List.generate(7, (index) {
                              final isSelected =
                                  tempSelectedDays.contains(index);
                              return FilterChip(
                                label: Text(weekDayNames[index]),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setModalState(() {
                                    if (selected) {
                                      tempSelectedDays.add(index);
                                      tempSelectedDays.sort();
                                    } else {
                                      tempSelectedDays.remove(index);
                                    }
                                  });
                                },
                                selectedColor: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                checkmarkColor:
                                    Theme.of(context).colorScheme.primary,
                              );
                            }),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // Apply Button
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          frequency = tempFrequency;
                          everyXDaysValue = tempEveryXDays;
                          timesPerWeekValue = tempTimesPerWeek;
                          timesPerMonthValue = tempTimesPerMonth;
                          selectedWeekDays = tempSelectedDays;
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child:
                          const Text('Apply', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPopupFrequencyOption(
    String value,
    String title,
    IconData icon,
    String subtitle,
    String currentValue,
    ValueChanged<String> onChanged,
  ) {
    final isSelected = currentValue == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isSelected
                                ? Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer
                                    .withValues(alpha: 0.8)
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPopupNumberSelector({
    required int value,
    required int min,
    required int max,
    required String label,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: value > min ? () => onChanged(value - 1) : null,
                icon: const Icon(Icons.remove_circle_outline_rounded),
                iconSize: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 24),
              Text(
                value.toString(),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(width: 24),
              IconButton(
                onPressed: value < max ? () => onChanged(value + 1) : null,
                icon: const Icon(Icons.add_circle_outline_rounded),
                iconSize: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
