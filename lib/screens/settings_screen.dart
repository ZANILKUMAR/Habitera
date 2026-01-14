import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/theme_provider.dart';
import '../providers/habit_provider.dart';
import '../services/database_service.dart';
import '../utils/file_saver.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Clear All Data',
                      style: TextStyle(color: Colors.red)),
                  subtitle: const Text('Delete all habits and progress'),
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
                ListTile(
                  leading: const Icon(Icons.language_outlined),
                  title: const Text('Website'),
                  subtitle: const Text('www.aktechsource.com'),
                  onTap: () {
                    // Could launch browser
                  },
                ),
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
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will permanently delete all your habits and completion history. '
          'Your settings will be preserved.\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await db.clearAllData();
              ref.invalidate(habitsProvider);
              ref.invalidate(dailyStatsProvider);
              ref.invalidate(heatmapProvider);

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All data cleared')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}
