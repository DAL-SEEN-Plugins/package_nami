import 'dart:io';
import 'package:ecrlib/src/utils/constants.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:ecrlib/ecrlib.dart';

class FileService {
  final Logger logger = Logger();
  ConfigModel config = ConfigModel();

  Future<File> _getLocalFile() async {
    try {
   Directory directory;

    if (Platform.isAndroid) {
      final directories = await getExternalStorageDirectories(
        type: StorageDirectory.documents,
      );
      directory = directories?.first ?? await getApplicationDocumentsDirectory();
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final filePath = '${directory.path}/NamiECRFlutterLib_log_data_$date.txt';
      final file = File(filePath);

      if (!await file.exists()) {
        await file.create(recursive: true);
      }

      await _deleteOldLogs(directory);
      return file;
    } catch (e) {
      logger.e("Error getting log file: $e");
      rethrow;
    }
  }

  Future<void> writeToFile(String content, {LogLevel? overrideLogLevel}) async {
    config = (await ConfigManager.getConfiguration()) ?? ConfigModel();
    try {
      final file = await _getLocalFile();
      final timestamp = DateFormat(Constants.TimeFormat).format(DateTime.now());

      if (config.logLevel == LogLevel.DEBUG ||
          config.logLevel == overrideLogLevel) {
        await file.writeAsString(
          '[$timestamp] [$overrideLogLevel] $content\n',
          mode: FileMode.append,
          flush: true,
        );
        logger.i("Log Saved: [$timestamp] [$overrideLogLevel] $content");
      } else {
        print("Skipped log...... $overrideLogLevel");
      }
    } catch (e) {
      logger.e("Error Writing Log: $e");
    }
  }

  Future<void> _deleteOldLogs(Directory directory) async {
    final now = DateTime.now();
    try {
      await for (var entity in directory.list()) {
        if (entity is File && entity.path.contains('log_data_')) {
          final match = RegExp(Constants.kLogFileRegex).firstMatch(entity.path);

          if (match != null) {
            final logDate = DateTime.parse(match.group(1)!);
            if (config.retetionDays != null &&
                now.difference(logDate).inDays > config.retetionDays!) {
              await entity.delete();
              logger.i("Deleted old log file: ${entity.path}");
            }
          }
        }
      }
    } catch (e) {
      logger.e("Error deleting old logs: $e");
    }
  }
}
