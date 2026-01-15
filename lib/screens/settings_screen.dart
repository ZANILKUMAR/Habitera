import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/theme_provider.dart';
import '../providers/habit_provider.dart';
import '../services/database_service.dart';
import '../utils/file_saver.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notePromptOnTap = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final db = DatabaseService();
    final settings = await db.getSettings();
    if (mounted) {
      setState(() {
        _notePromptOnTap = settings.notePromptOnTap;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final db = DatabaseService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Theme Section
                Text(
                  'Appearance',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Dark Mode'),
                  subtitle: const Text('Switch to dark theme'),
                  value: themeMode == ThemeMode.dark,
                  onChanged: (value) {
                    ref.read(themeModeProvider.notifier).setTheme(
                        value ? ThemeMode.dark : ThemeMode.light);
                  },
                  secondary: Icon(
                    themeMode == ThemeMode.dark
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                  ),
                ),
                const SizedBox(height: 32),

                // Check-in Behavior Section
                Text(
                  'Check-in Behavior',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Tap for Notes'),
                  subtitle: Text(
                    _notePromptOnTap
                        ? 'Tap opens notes • Hold to quick check-in'
                        : 'Tap for quick check-in • Hold to add notes',
                  ),
                  value: _notePromptOnTap,
                  onChanged: (value) async {
                    setState(() {
                      _notePromptOnTap = value;
                    });
                    final settings = await db.getSettings();
                    await db.updateSettings(
                      settings.copyWith(notePromptOnTap: value),
                    );
                    ref.invalidate(settingsProvider);
                  },
                  secondary: Icon(
                    _notePromptOnTap
                        ? Icons.edit_note_rounded
                        : Icons.check_circle_rounded,
                  ),
                ),
                const SizedBox(height: 32),

                // Data Section
                Text(
                  'Data',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.upload_rounded),
                  title: const Text('Export Data'),
                  subtitle: const Text('Save habits as CSV file'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () async {
                    try {
                      final csvData = await db.exportHabitsToCSV();
                      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
                      final fileName = 'habitera_backup_$timestamp.csv';
                      
                      final bytes = Uint8List.fromList(utf8.encode(csvData));
                      
                      if (kIsWeb) {
                        // Use web-specific download
                        await saveFileWeb(fileName, bytes);
                      } else {
                        // Use FilePicker for desktop/mobile
                        await FilePicker.platform.saveFile(
                          dialogTitle: 'Save Habitera Backup',
                          fileName: fileName,
                          type: FileType.custom,
                          allowedExtensions: ['csv'],
                          bytes: bytes,
                        );
                      }
                      
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Data exported successfully')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error exporting: $e')),
                        );
                      }
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: const Text('Import Data'),
                  subtitle: const Text('Restore from CSV backup file'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () async {
                    try {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['csv'],
                        withData: true,
                      );
                      
                      if (result != null && result.files.isNotEmpty) {
                        final file = result.files.first;
                        
                        if (file.bytes == null) {
                          throw Exception('Could not read file data');
                        }
                        
                        // Use utf8.decode for proper encoding on all platforms
                        final csvContent = utf8.decode(file.bytes!);
                        
                        // Parse CSV to count habits and completions
                        final counts = _parseCSVCounts(csvContent);
                        
                        if (context.mounted) {
                          // Show confirmation dialog
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Confirm Import'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('File: ${file.name}'),
                                  const SizedBox(height: 16),
                                  const Text('This file contains:'),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.checklist_rounded, size: 20),
                                      const SizedBox(width: 8),
                                      Text('${counts['habits']} habits'),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.done_all_rounded, size: 20),
                                      const SizedBox(width: 8),
                                      Text('${counts['completions']} completion records'),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Existing habits will be updated. New habits and completions will be added.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Import'),
                                ),
                              ],
                            ),
                          );
                          
                          if (confirmed == true && context.mounted) {
                            final imported = await db.importFromCSV(csvContent);
                            ref.invalidate(habitsProvider);
                            ref.invalidate(dailyStatsProvider);
                            ref.invalidate(heatmapProvider);
                            
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Imported ${imported['habits']} habits and ${imported['completions']} completions',
                                  ),
                                ),
                              );
                            }
                          }
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Import failed: $e')),
                        );
                      }
                    }
                  },
                ),
                const Divider(height: 32),
                ListTile(
                  leading: const Icon(Icons.restart_alt, color: Colors.red),
                  title: const Text('Reset App',
                      style: TextStyle(color: Colors.red)),
                  subtitle: const Text('Clear data and restore default habits'),
                  onTap: () async {
                    _showClearDataDialog(context, db, ref);
                  },
                ),
                const SizedBox(height: 32),

                // About Section
                Text(
                  'About',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                const ListTile(
                  title: Text('Version'),
                  subtitle: Text('1.0.0'),
                ),
                const ListTile(
                  title: Text('Build habits. Shape your life.'),
                  subtitle: Text('Habitera'),
                ),
                const SizedBox(height: 16),
                
                // Contact Section
                Text(
                  'Contact',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('Email'),
                  subtitle: const Text('contact.aktechsource@gmail.com'),
                  onTap: () {
                    // Could launch email app
                  },
                ),
                // ListTile(
                //   leading: const Icon(Icons.language_outlined),
                //   title: const Text('Website'),
                //   subtitle: const Text('www.aktechsource.com'),
                //   onTap: () {
                //     // Could launch browser
                //   },
                // ),
                ListTile(
                  leading: const Icon(Icons.feedback_outlined),
                  title: const Text('Send Feedback'),
                  subtitle: const Text('Help us improve Habitera'),
                  onTap: () {
                    // Could open feedback form
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog(
      BuildContext context, DatabaseService db, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset App?'),
        content: const Text(
          'This will reset the app to its initial state:\n\n'
          '• All habits and history will be deleted\n'
          '• Default habits will be restored\n'
          '• Your settings will be preserved\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await db.clearAllData();
                
                // Wait for database to be ready again (it closes on mobile)
                await Future.delayed(const Duration(milliseconds: 200));
                
                // Re-initialize database connection by accessing it
                await db.database;
                
                // Increment the refresh provider to trigger all dependent providers to reload
                ref.read(dataRefreshProvider.notifier).state++;
                
                // Also invalidate providers explicitly
                ref.invalidate(habitsProvider);
                ref.invalidate(dailyStatsProvider);
                ref.invalidate(heatmapProvider);
                ref.invalidate(habitCompletionCountsProvider);
                ref.invalidate(streaksProvider);
                ref.invalidate(completionStateProvider);
                ref.invalidate(settingsProvider);
                
                // Additional delay to ensure all updates propagate
                await Future.delayed(const Duration(milliseconds: 100));

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('App reset to initial state')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error resetting app: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  /// Parses a CSV file and returns the count of habits and completions
  Map<String, int> _parseCSVCounts(String csvContent) {
    final lines = csvContent.split('\n');
    int habitsCount = 0;
    int completionsCount = 0;
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

      if (currentSection == 'habits') {
        habitsCount++;
      } else if (currentSection == 'completions') {
        completionsCount++;
      }
    }

    return {
      'habits': habitsCount,
      'completions': completionsCount,
    };
  }
}
