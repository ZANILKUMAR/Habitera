// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Habit _$HabitFromJson(Map<String, dynamic> json) => Habit(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      frequency: $enumDecode(_$HabitFrequencyEnumMap, json['frequency']),
      customDays: (json['customDays'] as num?)?.toInt(),
      color: json['color'] as String?,
      icon: json['icon'] as String?,
      reminderTime: json['reminderTime'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      archivedAt: json['archivedAt'] == null
          ? null
          : DateTime.parse(json['archivedAt'] as String),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$HabitToJson(Habit instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'frequency': _$HabitFrequencyEnumMap[instance.frequency]!,
      'customDays': instance.customDays,
      'color': instance.color,
      'icon': instance.icon,
      'reminderTime': instance.reminderTime,
      'createdAt': instance.createdAt.toIso8601String(),
      'archivedAt': instance.archivedAt?.toIso8601String(),
      'sortOrder': instance.sortOrder,
    };

const _$HabitFrequencyEnumMap = {
  HabitFrequency.daily: 'daily',
  HabitFrequency.everyXDays: 'everyXDays',
  HabitFrequency.timesPerWeek: 'timesPerWeek',
  HabitFrequency.timesPerMonth: 'timesPerMonth',
  HabitFrequency.specificDays: 'specificDays',
};

Completion _$CompletionFromJson(Map<String, dynamic> json) => Completion(
      id: json['id'] as String,
      habitId: json['habitId'] as String,
      date: DateTime.parse(json['date'] as String),
      completedAt: DateTime.parse(json['completedAt'] as String),
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$CompletionToJson(Completion instance) =>
    <String, dynamic>{
      'id': instance.id,
      'habitId': instance.habitId,
      'date': instance.date.toIso8601String(),
      'completedAt': instance.completedAt.toIso8601String(),
      'notes': instance.notes,
    };

HabitStreak _$HabitStreakFromJson(Map<String, dynamic> json) => HabitStreak(
      habitId: json['habitId'] as String,
      current: (json['current'] as num).toInt(),
      longest: (json['longest'] as num).toInt(),
      lastCompletionDate: json['lastCompletionDate'] == null
          ? null
          : DateTime.parse(json['lastCompletionDate'] as String),
    );

Map<String, dynamic> _$HabitStreakToJson(HabitStreak instance) =>
    <String, dynamic>{
      'habitId': instance.habitId,
      'current': instance.current,
      'longest': instance.longest,
      'lastCompletionDate': instance.lastCompletionDate?.toIso8601String(),
    };

DailyStats _$DailyStatsFromJson(Map<String, dynamic> json) => DailyStats(
      date: DateTime.parse(json['date'] as String),
      totalHabits: (json['totalHabits'] as num).toInt(),
      completedHabits: (json['completedHabits'] as num).toInt(),
      percentage: (json['percentage'] as num).toDouble(),
    );

Map<String, dynamic> _$DailyStatsToJson(DailyStats instance) =>
    <String, dynamic>{
      'date': instance.date.toIso8601String(),
      'totalHabits': instance.totalHabits,
      'completedHabits': instance.completedHabits,
      'percentage': instance.percentage,
    };
