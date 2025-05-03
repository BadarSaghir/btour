import 'package:btour/services/backup_restore_service.dart'; // Adjust import
import 'package:flutter/material.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final BackupRestoreService _backupRestoreService = BackupRestoreService();
  bool _isBackingUp = false;
  bool _isRestoring = false;
  String _feedbackMessage = '';

  void _showSnackbar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.redAccent : Colors.green,
        ),
      );
    }
  }

  Future<void> _performBackup() async {
    setState(() {
      _isBackingUp = true;
      _feedbackMessage = 'Starting backup...';
    });

    String? backupPath;
    try {
      backupPath = await _backupRestoreService.backupDatabase();
      if (backupPath != null) {
        setState(() {
          _feedbackMessage = 'Backup successful!';
        });
        _showSnackbar('Backup successful!');
        // Ask user if they want to share the file
        // _askToShare(backupPath);
      } else {
        setState(() {
          _feedbackMessage = 'Backup failed or cancelled.';
        });
        _showSnackbar('Backup failed or cancelled.', isError: true);
      }
    } catch (e) {
      setState(() {
        _feedbackMessage = 'Backup error: $e';
      });
      _showSnackbar('Backup error occurred.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isBackingUp = false;
        });
      }
    }
  }

  void _askToShare(String filePath) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Share Backup?'),
            content: Text(
              'Do you want to share the backup file?\n\n${filePath.split('/').last}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _backupRestoreService.shareBackupFile(filePath);
                },
                child: const Text('Yes, Share'),
              ),
            ],
          ),
    );
  }

  Future<void> _performRestore() async {
    // Show confirmation dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Restore'),
            content: const Text(
              'Restoring will OVERWRITE all current data with the selected backup.\n\n'
              'This action cannot be undone.\n\n'
              'The app MAY NEED TO BE RESTARTED manually after restore.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                // Make restore button more prominent/warning
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Restore Now'),
              ),
            ],
          ),
    );

    if (confirmed != true) {
      setState(() => _feedbackMessage = 'Restore cancelled.');
      return;
    }

    setState(() {
      _isRestoring = true;
      _feedbackMessage = 'Starting restore... Select backup file.';
    });

    bool success = false;
    try {
      success = await _backupRestoreService.restoreDatabase();
      if (success) {
        setState(() {
          _feedbackMessage =
              'Restore successful!\nIMPORTANT: Please RESTART the app now.';
        });
        _showSnackbar('Restore successful! Restart the app.');
        // Show another dialog emphasizing restart
        _showRestartDialog();
      } else {
        setState(() {
          _feedbackMessage = 'Restore failed or cancelled. Check logs.';
        });
        _showSnackbar('Restore failed or cancelled.', isError: true);
      }
    } catch (e) {
      setState(() {
        _feedbackMessage = 'Restore error: $e';
      });
      _showSnackbar('Restore error occurred.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isRestoring = false;
        });
      }
    }
  }

  void _showRestartDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // User must acknowledge
      builder:
          (context) => AlertDialog(
            title: const Text('Restart Required'),
            content: const Text(
              'Database restore complete. To load the restored data correctly, please close and reopen the application.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore Data')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              icon:
                  _isBackingUp
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.backup),
              label: const Text('Backup Database'),
              onPressed: _isBackingUp || _isRestoring ? null : _performBackup,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon:
                  _isRestoring
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.restore),
              label: const Text('Restore from Backup'),
              onPressed: _isBackingUp || _isRestoring ? null : _performRestore,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            ),
            const SizedBox(height: 30),
            const Text(
              'Status:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _feedbackMessage.isEmpty ? 'Ready' : _feedbackMessage,
                style: TextStyle(
                  color:
                      _feedbackMessage.contains('failed') ||
                              _feedbackMessage.contains('error')
                          ? Colors.red
                          : Colors.black87,
                ),

                maxLines: 5,
              ),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const Text(
              'Notes:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              '- Backups are saved as .db files.\n'
              '- Store backups in a safe place outside this app.\n'
              '- Restoring REPLACES all current data.\n'
              '- App RESTART is required after restoring data.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
