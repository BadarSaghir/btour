import 'dart:io';
import 'dart:typed_data';
import 'package:btour/database/database_helper.dart'; // Adjust import path
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart'; // For sharing backup
import 'package:device_info_plus/device_info_plus.dart';

class BackupRestoreService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // --- Check Android SDK Version ---
  Future<int> _getAndroidSdkInt() async {
    if (Platform.isAndroid) {
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      return deviceInfo.version.sdkInt;
    }
    return 0; // Return 0 if not Android
  }

  // --- Request Permissions (Revised for Android Versions) ---
  Future<bool> _requestPermissions() async {
    if (!Platform.isAndroid) {
      print("Platform is not Android, skipping explicit permission request.");
      return true;
    }

    final sdkInt = await _getAndroidSdkInt();

    // Only request legacy storage permissions on Android < 13 (API 33)
    // Even then, SAF via file_picker is often preferred.
    // For API 30, 31, 32 WRITE_EXTERNAL_STORAGE has no effect.
    // For API 29 (Android 10), WRITE_EXTERNAL_STORAGE needed requestLegacyExternalStorage.
    // Let's simplify: We rely on FilePicker's SAF mechanism for >= 10/11.
    // Only request for Android 9 (API 28) and below if absolutely needed.
    if (sdkInt < 29) {
      // Android 9 (Pie) or lower
      print(
        "Android version ($sdkInt) < 29. Checking legacy storage permission.",
      );
      PermissionStatus status = await Permission.storage.status;
      print("Initial legacy storage permission status: $status");
      if (!status.isGranted) {
        print("Requesting legacy storage permission...");
        status = await Permission.storage.request();
        print("Permission status after request: $status");
      }
      if (!status.isGranted) {
        print("Legacy Storage permission denied.");
        // Guide to settings if permanently denied
        if (status.isPermanentlyDenied) {
          await openAppSettings();
        }
        return false;
      }
      print("Legacy Storage permission granted.");
      return true;
    } else {
      // On Android 10+ (API 29+), rely on FilePicker using SAF.
      // No explicit broad storage permission needed or effective for this task.
      print(
        "Android version ($sdkInt) >= 29. Relying on Storage Access Framework via FilePicker.",
      );
      return true;
    }
  }

  // --- Backup Database (Revised using file picker's 'save' suggestion) ---
  Future<String?> backupDatabase() async {
    // Note: _requestPermissions might only be relevant for Android < 10 now.
    // SAF handles permissions implicitly on newer versions via the picker.
    // if (!await _requestPermissions()) {
    //   print("Backup failed: Pre-check permissions failed (relevant for very old Android).");
    //   return null;
    // }

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
      final Uint8List fileBytes = await dbFile.readAsBytes();
      // --- Generate Suggested Filename ---
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final backupFilename = 'backup_btour_$timestamp.db';

      // --- Use FilePicker to get the SAVE location from the user ---
      // This invokes the SAF "Save As" dialog.
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Database Backup As...',
        fileName: backupFilename,
        bytes: fileBytes,
        // Optional: Specify allowed extensions if desired, though less critical for save
        type: FileType.custom,
        allowedExtensions: ['db'],
      );

      if (outputFile == null) {
        // User canceled the picker
        print("Backup cancelled by user (save file picker).");
        return null;
      }

      // IMPORTANT: The path returned by `saveFile` is where the user *wants* to save.
      // You still need to copy your actual database file content to this location.
      print("Current DB path: $dbPath");
      print("User selected save location: $outputFile");
      print("Attempting to copy DB to selected location...");

      try {
        // --- Copy the actual database file to the path chosen by the user ---

        // await dbFile.copy(outputFile);
        print("Database backup successful: $outputFile");
        return outputFile; // Return the path where the backup was actually saved
      } catch (e) {
        print("Error copying DB file to '$outputFile': $e");
        print(
          "This might happen if the path returned by saveFile is not directly writable (e.g., requires URI handling).",
        );
        return null;
        // If this fails consistently, a more complex SAF implementation using URIs might be needed.
      }
    } catch (e) {
      print("Error during database backup process: $e");
      return null;
    }
  }

  // --- Restore Database --- (Should generally work as `pickFiles` uses SAF for READ)

  // --- Restore Database (Revised with explicit extension check) ---
  Future<bool> restoreDatabase() async {
    try {
      print("Launching file picker for restore...");
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        // allowedExtensions: ["db"], // <-- CORRECTED: No dot before 'db'
        // type: FileType.custom,
        dialogTitle: 'Select Database Backup ',
        allowMultiple: false,
      );

      // Check if user cancelled
      if (result == null || result.files.single.path == null) {
        print("Restore cancelled by user or file path missing.");
        return false;
      }

      final backupFilePath = result.files.single.path!;
      print("User selected potential backup file: $backupFilePath");

      // ----- !!!!! ADD THIS CHECK !!!!! -----
      if (!backupFilePath.toLowerCase().endsWith('.db')) {
        print(
          "Restore failed: Selected file is not a .db file: $backupFilePath",
        );
        // Consider showing a user-friendly error message in your UI here
        // Example: _showSnackbar("Selected file must have a .db extension.", isError: true);
        return false;
      }
      // ----- End of added check -----

      final backupFile = File(backupFilePath);

      // Check if the selected file exists (might be redundant if picker is reliable, but safe)
      if (!await backupFile.exists()) {
        print(
          "Restore failed: Selected backup file does not exist (post-selection check): $backupFilePath",
        );
        return false;
      }
      print("Selected file exists and has .db extension.");

      // --- Get Current Database Path ---
      final currentDbPath = await _dbHelper.getCurrentDatabasePath();
      if (currentDbPath == null) {
        print("Restore failed: Could not determine current database path.");
        return false;
      }
      final currentDbFile = File(currentDbPath);
      print("Current database location: $currentDbPath");

      // --- CRITICAL: Close the database connection ---
      print("Closing current database connection before restore...");
      await _dbHelper.close();
      print("Database connection closed.");

      // --- Replace the database file ---
      print("Attempting to restore from: $backupFilePath");
      print("Replacing current DB at: $currentDbPath");

      // Delete old file first (wrapped in try/catch)
      try {
        if (await currentDbFile.exists()) {
          print("Deleting old database file...");
          await currentDbFile.delete();
          print("Old database file deleted.");
        }
      } catch (e) {
        print("Error deleting old database file '$currentDbPath': $e");
        // Stop if deletion fails to avoid potential issues
        return false;
      }

      // Copy the backup file (wrapped in try/catch)
      try {
        print("Copying backup file to database location...");
        await backupFile.copy(currentDbPath);
        print("Backup file copied successfully.");
      } catch (e) {
        print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
        print(
          "CRITICAL ERROR copying backup file '$backupFilePath' to '$currentDbPath': $e",
        );
        print(
          "Check permissions for reading source and writing destination. Check if source file is valid.",
        );
        print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
        // This is a critical failure point.
        return false; // Stop if copy fails
      }

      print("Database restore successful from: $backupFilePath");
      print(
        "IMPORTANT: Please restart the application for changes to take effect.",
      );
      return true; // Success
    } catch (e) {
      // Catch any other unexpected errors during the process
      print("Overall error during database restore process: $e");
      return false;
    }
  }

  // --- Share Backup File (Helper) ---
  Future<void> shareBackupFile(String filePath) async {
    // try {
    //   final file = XFile(filePath); // share_plus uses XFile
    //   final params = ShareParams(
    //     text: 'Database Backup (${p.basename(filePath)})',
    //     files: [file],
    //   );

    //   // Use the static method from the SharePlus instance directly
    //   final result = await SharePlus.instance.share(params);

    //   if (result.status == ShareResultStatus.success) {
    //     print('Backup file shared successfully.');
    //   } else {
    //     print('Sharing failed/dismissed: ${result.status}');
    //   }
    // } catch (e) {
    //   print('Error sharing file: $e');
    // }
  }
}
