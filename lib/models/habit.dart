import 'package:json_annotation/json_annotation.dart';

part 'habit.g.dart';

@JsonSerializable()
class Habit {
  final String id;
  final String title;
  final String? description;
  final HabitFrequency frequency;
  final int? customDays; // For custom frequency (e.g., 3 = 3x per week)
  final String? color;
  final String? icon;
  final String? reminderTime; // HH:mm format
  final DateTime createdAt;
  final DateTime? archivedAt; // For soft delete

  Habit({
    required this.id,
    required this.title,
    this.description,
    required this.frequency,
    this.customDays,
    this.color,
    this.icon,
    this.reminderTime,
    required this.createdAt,
    this.archivedAt,
  });

  bool get isArchived => archivedAt != null;

  factory Habit.fromJson(Map<String, dynamic> json) => _$HabitFromJson(json);
  Map<String, dynamic> toJson() => _$HabitToJson(this);

  Habit copyWith({
    String? id,
    String? title,
    String? description,
    HabitFrequency? frequency,
    int? customDays,
    String? color,
    String? icon,
    String? reminderTime,
    DateTime? createdAt,
    DateTime? archivedAt,
  }) {
    return Habit(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      frequency: frequency ?? this.frequency,
      customDays: customDays ?? this.customDays,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      reminderTime: reminderTime ?? this.reminderTime,
      createdAt: createdAt ?? this.createdAt,
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }
}

enum HabitFrequency {
  @JsonValue('daily')
  daily, // Every day
  @JsonValue('everyXDays')
  everyXDays, // Every X days (e.g., every 2 days)
  @JsonValue('timesPerWeek')
  timesPerWeek, // X times per week
  @JsonValue('timesPerMonth')
  timesPerMonth, // X times per month
  @JsonValue('specificDays')
  specificDays, // Specific days of the week
}

@JsonSerializable()
class Completion {
  final String id;
  final String habitId;
  final DateTime date;
  final DateTime completedAt;
  final String? notes;

  Completion({
    required this.id,
    required this.habitId,
    required this.date,
    required this.completedAt,
    this.notes,
  });

  factory Completion.fromJson(Map<String, dynamic> json) =>
      _$CompletionFromJson(json);
  Map<String, dynamic> toJson() => _$CompletionToJson(this);
}

@JsonSerializable()
class HabitStreak {
  final String habitId;
  final int current;
  final int longest;
  final DateTime? lastCompletionDate;

  HabitStreak({
    required this.habitId,
    required this.current,
    required this.longest,
    this.lastCompletionDate,
  });

  factory HabitStreak.fromJson(Map<String, dynamic> json) =>
      _$HabitStreakFromJson(json);
  Map<String, dynamic> toJson() => _$HabitStreakToJson(this);
}

@JsonSerializable()
class DailyStats {
  final DateTime date;
  final int totalHabits;
  final int completedHabits;
  final double percentage;

  DailyStats({
    required this.date,
    required this.totalHabits,
    required this.completedHabits,
    required this.percentage,
  });

  factory DailyStats.fromJson(Map<String, dynamic> json) =>
      _$DailyStatsFromJson(json);
  Map<String, dynamic> toJson() => _$DailyStatsToJson(this);
}
