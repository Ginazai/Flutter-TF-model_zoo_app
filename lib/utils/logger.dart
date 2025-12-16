import 'dart:io';
import 'package:path_provider/path_provider.dart';

class Logger {
  static File? _logFile;

  // Initialize the logger (call this once when your app starts)
  static Future<void> init() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      _logFile = File('${directory.path}/logs.txt');

      // Create the file if it doesn't exist
      if (!await _logFile!.exists()) {
        await _logFile!.create();
      }
    } catch (e) {
      print('Failed to initialize logger: $e');
    }
  }

  // Log a message with timestamp
  static Future<void> log(String message) async {
    try {
      if (_logFile == null) {
        await init();
      }

      final timestamp = DateTime.now().toIso8601String();
      final logEntry = '[$timestamp] $message\n';

      // Append to the log file
      await _logFile!.writeAsString(logEntry, mode: FileMode.append);

      // Also print to console for debugging
      print(logEntry.trim());
    } catch (e) {
      print('Failed to write log: $e');
    }
  }

  // Clear all logs
  static Future<void> clear() async {
    try {
      if (_logFile != null && await _logFile!.exists()) {
        await _logFile!.writeAsString('');
      }
    } catch (e) {
      print('Failed to clear logs: $e');
    }
  }

  // Get the log file path
  static String? getLogFilePath() {
    return _logFile?.path;
  }

  // Read all logs
  static Future<String> readLogs() async {
    try {
      if (_logFile != null && await _logFile!.exists()) {
        return await _logFile!.readAsString();
      }
      return 'No logs available';
    } catch (e) {
      return 'Failed to read logs: $e';
    }
  }
}

// Usage example:
void main() async {
  // Initialize the logger
  await Logger.init();

  // Log messages from anywhere in your code
  await Logger.log('App started');
  await Logger.log('User logged in');
  await Logger.log('Data fetched successfully');

  // Read logs
  print('\n--- All Logs ---');
  print(await Logger.readLogs());

  // Get log file path
  print('\nLog file location: ${Logger.getLogFilePath()}');
}