import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/habit_grid.dart';
import '../widgets/progress_ring.dart';
import '../widgets/empty_state.dart';
import '../providers/habit_provider.dart';
import 'add_habit_screen.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  void _onAddHabit() {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => const AddHabitScreen(),
      ),
    )
        .then((_) {
      ref.invalidate(habitsProvider);
      ref.invalidate(dailyStatsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final habitsAsync = ref.watch(habitsProvider);
    final dailyStatsAsync = ref.watch(dailyStatsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(habitsProvider);
            ref.invalidate(dailyStatsProvider);
            ref.invalidate(heatmapProvider);
          },
          child: Column(
            children: [
              // Header with date and progress
              _buildHeader(context, theme, dailyStatsAsync),

              // Habit grid
              Expanded(
                child: habitsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Error: $error'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            ref.invalidate(habitsProvider);
                            ref.invalidate(dailyStatsProvider);
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                  data: (habits) {
                    if (habits.isEmpty) {
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height - 200,
                          child: EmptyState(
                            icon: '🎯',
                            title: 'No habits yet',
                            subtitle: 'Create your first habit to start tracking',
                            actionLabel: 'Create Habit',
                            onAction: _onAddHabit,
                          ),
                        ),
                      );
                    }
                    return HabitGrid(
                      habits: habits,
                      daysToShow: 30,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: _onAddHabit,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ThemeData theme,
    AsyncValue<Map<String, dynamic>> dailyStatsAsync,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Date and greeting
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Habitera',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Text(
                  'Build habits. Shape your life.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          // Progress ring
          dailyStatsAsync.when(
            data: (stats) {
              final completed = stats['completedHabits'] as int;
              final total = stats['totalHabits'] as int;
              final percentage = stats['percentage'] as double;

              return Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$completed / $total',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'completed',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: ProgressRing(
                      percentage: percentage,
                      size: 48,
                    ),
                  ),
                ],
              );
            },
            loading: () => Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '- / -',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'loading...',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ),
            error: (_, __) => Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '0 / 0',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'completed',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: ProgressRing(
                    percentage: 0,
                    size: 48,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
