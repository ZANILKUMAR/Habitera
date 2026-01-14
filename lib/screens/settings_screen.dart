import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/theme_provider.dart';
import '../providers/habit_provider.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../utils/file_saver.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _devTapCount = 0;
  bool _developerModeEnabled = false;

  void _onVersionTap() {
    setState(() {
      _devTapCount++;
      if (_devTapCount >= 7 && !_developerModeEnabled) {
        _developerModeEnabled = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔧 Developer options enabled!'),
            duration: Duration(seconds: 2),
          ),
        );
      } else if (_devTapCount < 7 && _devTapCount >= 4) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${7 - _devTapCount} taps to enable developer options'),
            duration: const Duration(milliseconds: 500),
          ),
        );
      }
    });
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
                ListTile(
                  title: const Text('Version'),
                  subtitle: const Text('1.0.0'),
                  onTap: _onVersionTap,
                ),
                const ListTile(
                  title: Text('Build habits. Shape your life.'),
                  subtitle: Text('Habitera'),
                ),
                const SizedBox(height: 16),
                
                // Developer Options Section (hidden until 7 taps on version)
                if (_developerModeEnabled) ...[
                  Text(
                    '🔧 Developer Options',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Permission Status Tile
                  FutureBuilder<bool>(
                    future: NotificationService().areNotificationsEnabled(),
                    builder: (context, snapshot) {
                      final enabled = snapshot.data ?? false;
                      return ListTile(
                        leading: Icon(
                          enabled ? Icons.check_circle : Icons.warning,
                          color: enabled ? Colors.green : Colors.orange,
                        ),
                        title: const Text('Notification Permission'),
                        subtitle: Text(enabled 
                          ? 'Notifications are enabled' 
                          : 'Notifications are disabled - tap to enable'),
                        onTap: enabled ? null : () async {
                          final result = await NotificationService().requestPermissions();
                          if (context.mounted) {
                            if (result['notifications'] == true) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Notifications enabled!')),
                              );
                              setState(() {});
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enable notifications in Settings → Apps → Habitera → Notifications'),
                                  duration: Duration(seconds: 4),
                                ),
                              );
                            }
                          }
                        },
                      );
                    },
                  ),
                  
                  // Exact Alarm Permission (Android 12+)
                  FutureBuilder<bool>(
                    future: NotificationService().canScheduleExactAlarms(),
                    builder: (context, snapshot) {
                      final enabled = snapshot.data ?? false;
                      return ListTile(
                        leading: Icon(
                          enabled ? Icons.check_circle : Icons.warning,
                          color: enabled ? Colors.green : Colors.orange,
                        ),
                        title: const Text('Exact Alarm Permission'),
                        subtitle: Text(enabled 
                          ? 'Exact alarms are allowed' 
                          : 'Required for precise reminders - tap to enable'),
                        onTap: enabled ? null : () async {
                          await NotificationService().requestPermissions();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please allow exact alarms in the settings that opens'),
                                duration: Duration(seconds: 3),
                              ),
                            );
                            setState(() {});
                          }
                        },
                      );
                    },
                  ),
                  
                  const Divider(),
                  
                  ListTile(
                    leading: const Icon(Icons.notifications_active),
                    title: const Text('Test Instant Notification'),
                    subtitle: const Text('Send a notification immediately'),
                    onTap: () async {
                      try {
                        final enabled = await NotificationService().areNotificationsEnabled();
                        if (!enabled) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enable notifications first'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                          return;
                        }
                        
                        await NotificationService().sendTestNotification();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Test notification sent! Check your notification tray.'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.timer),
                    title: const Text('Test Scheduled Notification'),
                    subtitle: const Text('Schedule notification for 1 minute from now'),
                    onTap: () async {
                      try {
                        final enabled = await NotificationService().areNotificationsEnabled();
                        if (!enabled) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enable notifications first'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                          return;
                        }
                        
                        final canSchedule = await NotificationService().canScheduleExactAlarms();
                        
                        final result = await NotificationService().sendTestScheduledNotification();
                        if (context.mounted) {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(result['scheduled'] == true 
                                ? '✅ Notification Scheduled' 
                                : '❌ Scheduling Failed'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Exact Alarms Permission: ${canSchedule ? "✅ Yes" : "❌ No"}'),
                                  const SizedBox(height: 8),
                                  Text('Current Time: ${result['currentTime']}'),
                                  Text('Scheduled For: ${result['scheduledFor']}'),
                                  Text('Timezone: ${result['timezone']}'),
                                  const SizedBox(height: 8),
                                  Text('Scheduled: ${result['scheduled']}'),
                                  Text('Pending Count: ${result['totalPending']}'),
                                  if (result['error'] != null)
                                    Text('Error: ${result['error']}', 
                                      style: const TextStyle(color: Colors.red)),
                                  const SizedBox(height: 12),
                                  if (result['scheduled'] == true)
                                    const Text('Wait 1 minute for notification...', 
                                      style: TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.schedule),
                    title: const Text('Pending Reminders'),
                    subtitle: const Text('View scheduled notifications'),
                    onTap: () async {
                      final pending = await NotificationService().getPendingNotifications();
                      if (context.mounted) {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Pending Reminders'),
                            content: SizedBox(
                              width: double.maxFinite,
                              child: pending.isEmpty
                                  ? const Text('No pending reminders scheduled.')
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: pending.length,
                                      itemBuilder: (context, index) {
                                        final n = pending[index];
                                        return ListTile(
                                          title: Text(n.title ?? 'No title'),
                                          subtitle: Text(n.body ?? 'No body'),
                                        );
                                      },
                                    ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
                  
                  ListTile(
                    leading: const Icon(Icons.developer_mode, color: Colors.orange),
                    title: const Text('Hide Developer Options'),
                    onTap: () {
                      setState(() {
                        _developerModeEnabled = false;
                        _devTapCount = 0;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Developer options hidden')),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                ],
                
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
              try {
                await db.clearAllData();
                
                // Force refresh all providers
                ref.invalidate(habitsProvider);
                ref.invalidate(dailyStatsProvider);
                ref.invalidate(heatmapProvider);
                
                // Small delay to ensure database operations complete
                await Future.delayed(const Duration(milliseconds: 100));

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All data cleared')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error clearing data: $e')),
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
}
