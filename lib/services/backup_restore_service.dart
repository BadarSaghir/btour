import 'dart:io';
import 'package:btour/database/database_helper.dart'; // Adjust import path
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart'; // For sharing backup

class BackupRestoreService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // --- Request Storage Permissions ---
  // --- Request Storage Permissions (Enhanced) ---
  Future<bool> _requestPermissions() async {
    // Permissions are primarily needed on Android for external storage access
    if (!Platform.isAndroid) {
      print(
        "Platform is not Android, assuming permissions are handled by picker.",
      );
      return true; // No explicit permissions needed usually on iOS for picker
    }

    print("Checking storage permission status on Android...");
    PermissionStatus status = await Permission.storage.status;
    print("Initial storage permission status: $status");

    // If not granted, request it
    if (!status.isGranted) {
      print("Storage permission not granted. Requesting...");
      status = await Permission.storage.request();
      print("Permission status after request: $status");
    }

    // Handle the outcome
    if (status.isGranted) {
      print("Storage permission granted.");
      return true;
    } else if (status.isPermanentlyDenied) {
      print(
        "Storage permission permanently denied. Asking user to open settings.",
      );
      // Optionally show a dialog explaining *why* permission is needed before opening settings
      await openAppSettings(); // Opens the app's settings page
      return false; // Return false as permission is still not granted *now*
    } else if (status.isDenied) {
      print("Storage permission denied by user.");
      // Optionally show a dialog explaining why permission is needed
      return false;
    } else {
      // Handle other potential statuses like restricted
      print("Storage permission has an unexpected status: $status");
      return false;
    }
  }

  // --- Backup Database ---
  /// Creates a backup of the database file.
  /// Returns the path of the backup file if successful, null otherwise.
  Future<String?> backupDatabase() async {
    if (!await _requestPermissions()) {
      print("Backup failed: Permissions not granted.");
      return null;
    }

    try {
      final dbPath = await _dbHelper.getCurrentDatabasePath();
      if (dbPath == null) {
        print("Backup failed: Could not get database path.");
        return null;
      }

      final dbFile = File(dbPath);
      if (!await dbFile.exists()) {
        print("Backup failed: Database file does not exist at $dbPath.");
        return null;
      }

      // --- Choose Backup Location ---
      // Option 1: Let user choose directory
      String? outputDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Backup Folder',
      );

      // Option 2: Directly save to Downloads (might need broader permissions)
      // Directory? downloadsDir = await getDownloadsDirectory();
      // String? outputDirectory = downloadsDir?.path;

      if (outputDirectory == null) {
        print("Backup cancelled by user.");
        return null; // User canceled picker
      }

      // --- Create Backup Filename ---
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final backupFilename = 'backup_tours_expenses_$timestamp.db';
      final backupFilePath = p.join(outputDirectory, backupFilename);

      print("Current DB path: $dbPath");
      print("Attempting to backup to: $backupFilePath");

      // --- Copy the file ---
      await dbFile.copy(backupFilePath);

      print("Database backup successful: $backupFilePath");
      return backupFilePath; // Return path on success
    } catch (e) {
      print("Error during database backup: $e");
      return null;
    }
  }

  // --- Restore Database ---
  /// Restores the database from a selected backup file.
  /// Returns true if successful, false otherwise.
  /// IMPORTANT: Requires app restart after successful restore.
  Future<bool> restoreDatabase() async {
    // Permissions might be needed if reading from a restricted location,
    // but file_picker often handles this. Let's assume picker works.
    if (!await _requestPermissions()) {
      print("Restore failed: Permissions not granted.");
      return false;
    }

    try {
      // --- Select Backup File ---
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any, // Allow any file, user needs to pick correctly
        // Or filter: type: FileType.custom, allowedExtensions: ['db'],
        dialogTitle: 'Select Database Backup File (.db)',
      );

      if (result == null || result.files.single.path == null) {
        print("Restore cancelled by user.");
        return false; // User canceled picker or path is missing
      }

      final backupFilePath = result.files.single.path!;
      final backupFile = File(backupFilePath);

      if (!await backupFile.exists()) {
        print(
          "Restore failed: Selected backup file does not exist: $backupFilePath",
        );
        return false;
      }
      // Basic check: is it likely a SQLite file? (Optional)
      // Could check magic bytes or just the extension
      if (!backupFilePath.toLowerCase().endsWith('.db')) {
        print(
          "Warning: Selected file '$backupFilePath' might not be a valid database backup (.db).",
        );
        return false;
        // Optionally, ask for confirmation here before proceeding
      }

      // --- Get Current Database Path ---
      final currentDbPath = await _dbHelper.getCurrentDatabasePath();
      if (currentDbPath == null) {
        print("Restore failed: Could not determine current database path.");
        return false;
      }
      final currentDbFile = File(currentDbPath);

      // --- CRITICAL: Close the database connection ---
      print("Closing current database connection before restore...");
      await _dbHelper.close();
      print("Database connection closed.");

      // --- Replace the database file ---
      print("Attempting to restore from: $backupFilePath");
      print("Replacing current DB at: $currentDbPath");

      // It's often safer to delete the old one first, then copy.
      if (await currentDbFile.exists()) {
        print("Deleting old database file...");
        await currentDbFile.delete();
        print("Old database file deleted.");
      }

      print("Copying backup file to database location...");
      await backupFile.copy(currentDbPath);
      print("Backup file copied successfully.");

      print("Database restore successful from: $backupFilePath");
      print(
        "IMPORTANT: Please restart the application for changes to take effect.",
      );
      return true; // Success
    } catch (e) {
      print("Error during database restore: $e");
      // Attempt to re-initialize DB helper might be needed if state is inconsistent
      // but usually restart is the safest.
      return false;
    }
  }

  // --- Share Backup File (Helper) ---
  Future<void> shareBackupFile(String filePath) async {
    try {
      final file = XFile(filePath); // share_plus uses XFile
      final result = await Share.shareXFiles([
        file,
      ], text: 'Database Backup (${p.basename(filePath)})');

      if (result.status == ShareResultStatus.success) {
        print('Backup file shared successfully.');
      } else {
        print('Sharing failed/dismissed: ${result.status}');
      }
    } catch (e) {
      print('Error sharing file: $e');
    }
  }
}
