import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import '../models/habit.dart';
import '../models/settings.dart';

// Web support
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;
  static bool _initialized = false;
  static bool _initializing = false;

  DatabaseService._internal();

  factory DatabaseService() {
    return _instance;
  }

  Future<Database> get database async {
    // Return existing database if available
    if (_database != null) {
      return _database!;
    }
    
    // Wait if another call is initializing
    while (_initializing) {
      await Future.delayed(const Duration(milliseconds: 10));
      if (_database != null) {
        return _database!;
      }
    }
    
    // Initialize
    _initializing = true;
    try {
      if (!_initialized) {
        if (kIsWeb) {
          databaseFactory = databaseFactoryFfiWeb;
        }
        _initialized = true;
      }
      _database ??= await _initDatabase();
      return _database!;
    } finally {
      _initializing = false;
    }
  }

  Future<Database> _initDatabase() async {
    String path;
    if (kIsWeb) {
      path = 'habitera.db';
    } else {
      path = join(await getDatabasesPath(), 'habitera.db');
    }
    return openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Check if we have any habits, if not, seed defaults
      final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM habits'),
      );
      if (count == 0) {
        await _seedDefaultHabits(db);
      }
    }
    if (oldVersion < 3) {
      // Add notes column to completions table
      await db.execute('ALTER TABLE completions ADD COLUMN notes TEXT');
    }
    if (oldVersion < 4) {
      // Add sortOrder column to habits table
      await db.execute('ALTER TABLE habits ADD COLUMN sortOrder INTEGER DEFAULT 0');
      // Initialize sort order based on creation date
      await db.execute('''
        UPDATE habits SET sortOrder = (
          SELECT COUNT(*) FROM habits h2 WHERE h2.createdAt <= habits.createdAt
        )
      ''');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Habits table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS habits(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        frequency TEXT NOT NULL,
        customDays INTEGER,
        color TEXT,
        icon TEXT,
        reminderTime TEXT,
        createdAt TEXT NOT NULL,
        archivedAt TEXT,
        sortOrder INTEGER DEFAULT 0
      )
    ''');

    // Completions table
    await db.execute('''
      CREATE TABLE completions(
        id TEXT PRIMARY KEY,
        habitId TEXT NOT NULL,
        date TEXT NOT NULL,
        completedAt TEXT NOT NULL,
        notes TEXT,
        FOREIGN KEY(habitId) REFERENCES habits(id)
      )
    ''');

    // Create index for faster queries
    await db.execute('''
      CREATE INDEX idx_completions_habitId ON completions(habitId)
    ''');

    await db.execute('''
      CREATE INDEX idx_completions_date ON completions(date)
    ''');

    // Settings table
    await db.execute('''
      CREATE TABLE settings(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Seed default habits
    await _seedDefaultHabits(db);
  }

  Future<void> _seedDefaultHabits(Database db) async {
    final defaultHabits = [
      {
        'id': 'default_wake_early',
        'title': 'Wake Up Early',
        'description': 'Did you wake up before 6 AM?|||Start your day at 6 AM for a productive morning',
        'frequency': 'daily',
        'color': '#FFA94D',
        'icon': '🌅',
        'reminderTime': '06:00',
      },
      {
        'id': 'default_exercise',
        'title': 'Exercise',
        'description': 'Did you exercise for at least 30 minutes?|||At least 30 minutes of physical activity',
        'frequency': 'daily',
        'color': '#FF6B6B',
        'icon': '💪',
        'reminderTime': '07:00',
      },
      {
        'id': 'default_meditate',
        'title': 'Meditate',
        'description': 'Did you meditate for 10 minutes?|||10 minutes of mindfulness meditation',
        'frequency': 'daily',
        'color': '#4ECDC4',
        'icon': '🧘',
        'reminderTime': '08:00',
      },
      {
        'id': 'default_read',
        'title': 'Read a Book',
        'description': 'Did you read for at least 20 minutes?|||Read for at least 20 minutes',
        'frequency': 'daily',
        'color': '#9B59B6',
        'icon': '📚',
        'reminderTime': null,
      },
      {
        'id': 'default_water',
        'title': 'Drink Water',
        'description': 'Did you drink 8 glasses of water today?|||Stay hydrated - drink 8 glasses of water',
        'frequency': 'daily',
        'color': '#3498DB',
        'icon': '💧',
        'reminderTime': null,
      },
      {
        'id': 'default_journal',
        'title': 'Journal',
        'description': 'Did you write in your journal today?|||Write down your thoughts and gratitude',
        'frequency': 'daily',
        'color': '#FFD93D',
        'icon': '📝',
        'reminderTime': '21:00',
      },
    ];

    final now = DateTime.now().toIso8601String();
    for (var habit in defaultHabits) {
      await db.insert('habits', {
        'id': habit['id'],
        'title': habit['title'],
        'description': habit['description'],
        'frequency': habit['frequency'],
        'customDays': null,
        'color': habit['color'],
        'icon': habit['icon'],
        'reminderTime': habit['reminderTime'],
        'createdAt': now,
        'archivedAt': null,
      });
    }
  }

  // Habits
  Future<List<Habit>> getAllHabits() async {
    final db = await database;
    final maps = await db.query(
      'habits',
      where: 'archivedAt IS NULL',
      orderBy: 'sortOrder ASC, createdAt ASC',
    );
    return List.generate(maps.length, (i) => _habitFromMap(maps[i]));
  }

  Future<Habit?> getHabitById(String id) async {
    final db = await database;
    final maps = await db.query(
      'habits',
      where: 'id = ? AND archivedAt IS NULL',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return _habitFromMap(maps.first);
  }

  Future<Habit> createHabit(Habit habit) async {
    try {
      final db = await database;
      await db.insert('habits', _habitToMap(habit));
      debugPrint('Habit created: ${habit.title} (id: ${habit.id})');
      return habit;
    } catch (e) {
      debugPrint('Error creating habit: $e');
      rethrow;
    }
  }

  Future<void> updateHabit(Habit habit) async {
    final db = await database;
    await db.update(
      'habits',
      _habitToMap(habit),
      where: 'id = ?',
      whereArgs: [habit.id],
    );
  }

  Future<void> deleteHabit(String id) async {
    final db = await database;
    await db.update(
      'habits',
      {'archivedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Updates the sort order for multiple habits in a single transaction
  Future<void> updateHabitSortOrders(List<String> habitIds) async {
    final db = await database;
    await db.transaction((txn) async {
      for (int i = 0; i < habitIds.length; i++) {
        await txn.update(
          'habits',
          {'sortOrder': i},
          where: 'id = ?',
          whereArgs: [habitIds[i]],
        );
      }
    });
    debugPrint('Updated sort order for ${habitIds.length} habits');
  }

  // Completions
  Future<Completion> recordCompletion(String habitId, DateTime date, {String? notes}) async {
    final db = await database;
    final completion = Completion(
      id: const Uuid().v4(),
      habitId: habitId,
      date: DateTime(date.year, date.month, date.day),
      completedAt: DateTime.now(),
      notes: notes,
    );
    await db.insert('completions', _completionToMap(completion));
    return completion;
  }

  Future<void> undoCompletion(String habitId, DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().split('T')[0];
    await db.delete(
      'completions',
      where: 'habitId = ? AND date LIKE ?',
      whereArgs: [habitId, '$dateStr%'],
    );
  }

  Future<Completion?> getCompletionForDate(String habitId, DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().split('T')[0];
    final maps = await db.query(
      'completions',
      where: 'habitId = ? AND date LIKE ?',
      whereArgs: [habitId, '$dateStr%'],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return _completionFromMap(maps.first);
  }

  Future<void> updateCompletionNotes(String habitId, DateTime date, String? notes) async {
    final db = await database;
    final dateStr = date.toIso8601String().split('T')[0];
    await db.update(
      'completions',
      {'notes': notes},
      where: 'habitId = ? AND date LIKE ?',
      whereArgs: [habitId, '$dateStr%'],
    );
  }

  Future<bool> isCompletedToday(String habitId) async {
    final db = await database;
    final today = DateTime.now();
    final todayStr =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    final result = await db.query(
      'completions',
      where: 'habitId = ? AND date LIKE ?',
      whereArgs: [habitId, '$todayStr%'],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<List<Completion>> getCompletionsForDate(DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().split('T')[0];
    final maps = await db.query(
      'completions',
      where: 'date LIKE ?',
      whereArgs: ['$dateStr%'],
    );
    return List.generate(maps.length, (i) => _completionFromMap(maps[i]));
  }

  Future<List<Completion>> getCompletionsForHabit(String habitId) async {
    final db = await database;
    final maps = await db.query(
      'completions',
      where: 'habitId = ?',
      whereArgs: [habitId],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => _completionFromMap(maps[i]));
  }

  Future<Map<String, int>> getHeatmapData(int monthsBack) async {
    final db = await database;
    final startDate = DateTime.now().subtract(Duration(days: monthsBack * 30));
    final startStr = startDate.toIso8601String().split('T')[0];

    // Get total habits count
    final totalHabits = Sqflite.firstIntValue(
          await db
              .rawQuery('SELECT COUNT(*) FROM habits WHERE archivedAt IS NULL'),
        ) ??
        0;

    if (totalHabits == 0) {
      return {};
    }

    final result = await db.rawQuery('''
      SELECT substr(date, 1, 10) as dateKey, COUNT(*) as count
      FROM completions
      WHERE date >= ?
      GROUP BY dateKey
    ''', [startStr]);

    final heatmap = <String, int>{};
    for (var row in result) {
      final date = row['dateKey'] as String;
      final count = row['count'] as int;
      final percentage = ((count / totalHabits) * 100).toInt();
      heatmap[date] = percentage;
    }
    return heatmap;
  }

  // Settings
  Future<AppSettings> getSettings() async {
    final db = await database;
    final maps = await db.query('settings');

    if (maps.isEmpty) {
      final defaults = AppSettings();
      for (var entry in defaults.toMap().entries) {
        await db.insert('settings', {
          'key': entry.key,
          'value': entry.value.toString(),
        });
      }
      return defaults;
    }

    final settingsMap = <String, dynamic>{};
    for (var map in maps) {
      settingsMap[map['key'] as String] = map['value'];
    }
    return AppSettings.fromMap(settingsMap);
  }

  Future<void> updateSettings(AppSettings settings) async {
    final db = await database;
    final map = settings.toMap();
    for (var entry in map.entries) {
      // Use INSERT OR REPLACE to handle both new and existing keys
      await db.rawInsert(
        'INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)',
        [entry.key, entry.value.toString()],
      );
    }
  }

  // Export/Import - CSV Format
  Future<String> exportHabitsToCSV() async {
    final db = await database;
    final habits = await db.query('habits');
    final completions = await db.query('completions');
    
    final buffer = StringBuffer();
    
    // Habits CSV section
    buffer.writeln('# HABITS');
    buffer.writeln('id,title,description,frequency,customDays,color,icon,reminderTime,createdAt,archivedAt');
    for (final habit in habits) {
      buffer.writeln(_escapeCSV([
        habit['id'] ?? '',
        habit['title'] ?? '',
        habit['description'] ?? '',
        habit['frequency'] ?? '',
        habit['customDays']?.toString() ?? '',
        habit['color'] ?? '',
        habit['icon'] ?? '',
        habit['reminderTime'] ?? '',
        habit['createdAt'] ?? '',
        habit['archivedAt'] ?? '',
      ]));
    }
    
    buffer.writeln();
    
    // Completions CSV section
    buffer.writeln('# COMPLETIONS');
    buffer.writeln('habitId,date,completedAt,notes');
    for (final completion in completions) {
      buffer.writeln(_escapeCSV([
        completion['habitId'] ?? '',
        completion['date'] ?? '',
        completion['completedAt'] ?? '',
        completion['notes'] ?? '',
      ]));
    }
    
    return buffer.toString();
  }
  
  String _escapeCSV(List<dynamic> values) {
    return values.map((value) {
      final str = value.toString();
      if (str.contains(',') || str.contains('"') || str.contains('\n')) {
        return '"${str.replaceAll('"', '""')}"';
      }
      return str;
    }).join(',');
  }
  
  List<String> _parseCSVLine(String line) {
    final result = <String>[];
    var current = StringBuffer();
    var inQuotes = false;
    
    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          current.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        result.add(current.toString());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }
    result.add(current.toString());
    
    return result;
  }

  Future<Map<String, int>> importFromCSV(String csvData) async {
    try {
      final db = await database;
      final lines = csvData.split('\n');
      
      int habitsImported = 0;
      int completionsImported = 0;
      String currentSection = '';
      
      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty) continue;
        
        if (line.startsWith('# HABITS')) {
          currentSection = 'habits';
          continue;
        } else if (line.startsWith('# COMPLETIONS')) {
          currentSection = 'completions';
          continue;
        }
        
        // Skip header lines
        if (line.startsWith('id,') || line.startsWith('habitId,')) continue;
        
        final values = _parseCSVLine(line);
        
        if (currentSection == 'habits' && values.length >= 9) {
          final habitId = values[0];
          
          // Handle archivedAt - check if it looks like a date (contains '-')
          // Old format had isArchived (0 or 1), new format has archivedAt (date or empty)
          String? archivedAt;
          if (values.length > 9 && values[9].isNotEmpty) {
            // Only use if it looks like a date (contains '-' like 2024-01-01)
            if (values[9].contains('-')) {
              archivedAt = values[9];
            }
            // Otherwise ignore (it's probably old isArchived field with 0 or 1)
          }
          
          final habitData = {
            'id': values[0],
            'title': values[1],
            'description': values[2].isEmpty ? null : values[2],
            'frequency': values[3],
            'customDays': values[4].isEmpty ? null : int.tryParse(values[4]),
            'color': values[5].isEmpty ? null : values[5],
            'icon': values[6].isEmpty ? null : values[6],
            'reminderTime': values[7].isEmpty ? null : values[7],
            'createdAt': values[8],
            'archivedAt': archivedAt,
          };
          
          // Check if habit already exists
          final existing = await db.query(
            'habits',
            where: 'id = ?',
            whereArgs: [habitId],
          );
          
          if (existing.isEmpty) {
            await db.insert('habits', habitData);
            habitsImported++;
          } else {
            // Update existing habit to fix any corrupted data
            await db.update(
              'habits',
              habitData,
              where: 'id = ?',
              whereArgs: [habitId],
            );
            habitsImported++;
          }
        } else if (currentSection == 'completions' && values.length >= 3) {
          final habitId = values[0];
          final date = values[1];
          
          // Check if completion already exists
          final existing = await db.query(
            'completions',
            where: 'habitId = ? AND date = ?',
            whereArgs: [habitId, date],
          );
          
          if (existing.isEmpty) {
            // Generate a unique id for the completion
            final completionId = const Uuid().v4();
            // Use completedAt from CSV or default to date
            final completedAt = values[2].isNotEmpty ? values[2] : date;
            await db.insert('completions', {
              'id': completionId,
              'habitId': values[0],
              'date': values[1],
              'completedAt': completedAt,
              'notes': values.length > 3 && values[3].isNotEmpty ? values[3] : null,
            });
            completionsImported++;
          }
        }
      }
      
      return {
        'habits': habitsImported,
        'completions': completionsImported,
      };
    } catch (e) {
      throw Exception('Failed to import CSV data: $e');
    }
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('completions');
    await db.delete('habits');
    // Don't delete settings - keep user preferences
    
    // Restore default habits (reset to first-time install state)
    await _seedDefaultHabits(db);
    
    // On mobile, close and reopen database to clear any cached data
    if (!kIsWeb) {
      await closeDatabase();
    }
    
    debugPrint('All data cleared and default habits restored');
  }

  /// Close the database connection (useful for testing or forcing refresh)
  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      debugPrint('Database connection closed');
    }
  }

  // Helper methods
  Habit _habitFromMap(Map<String, dynamic> map) {
    return Habit(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      frequency: HabitFrequency.values.firstWhere(
        (f) => f.toString().split('.').last == map['frequency'],
      ),
      customDays: map['customDays'] as int?,
      color: map['color'] as String?,
      icon: map['icon'] as String?,
      reminderTime: map['reminderTime'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      archivedAt: map['archivedAt'] != null
          ? DateTime.parse(map['archivedAt'] as String)
          : null,
      sortOrder: (map['sortOrder'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> _habitToMap(Habit habit) {
    return {
      'id': habit.id,
      'title': habit.title,
      'description': habit.description,
      'frequency': habit.frequency.toString().split('.').last,
      'customDays': habit.customDays,
      'color': habit.color,
      'icon': habit.icon,
      'reminderTime': habit.reminderTime,
      'createdAt': habit.createdAt.toIso8601String(),
      'archivedAt': habit.archivedAt?.toIso8601String(),
      'sortOrder': habit.sortOrder,
    };
  }

  Completion _completionFromMap(Map<String, dynamic> map) {
    return Completion(
      id: map['id'] as String,
      habitId: map['habitId'] as String,
      date: DateTime.parse(map['date'] as String),
      completedAt: DateTime.parse(map['completedAt'] as String),
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> _completionToMap(Completion completion) {
    return {
      'id': completion.id,
      'habitId': completion.habitId,
      'date': completion.date.toIso8601String(),
      'completedAt': completion.completedAt.toIso8601String(),
      'notes': completion.notes,
    };
  }
}
