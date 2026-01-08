import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:ecrlib/ecrlib.dart';
import 'package:ecrlib/src/services/connection/logger.dart';
import 'package:intl/intl.dart';

class EncryptionUtil {
  static final EncryptionUtil _instance = EncryptionUtil._();
  factory EncryptionUtil() => _instance;
  EncryptionUtil._();
  static const String _key = "F293A091D0104091BFD51F24CD02E4C6";
  final FileService fileService = FileService();

  static String encryptDecrypt(String input) {
    List<int> keyBytes = _key.codeUnits;
    List<int> result = List.generate(input.length, (i) {
      return input.codeUnitAt(i) ^ keyBytes[i % keyBytes.length];
    });

    return String.fromCharCodes(result);
  }

  static String getSha256Hash(String ecrRef, String terminalId) {
    String combinedInput = ecrRef + terminalId;
    List<int> bytes = utf8.encode(combinedInput);
    Digest sha256Hash = sha256.convert(bytes);
    return sha256Hash.toString();
  }

  static String stringToHex(String input) {
    List<int> bytes = utf8.encode(input);
    String hexString =
        bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return hexString;
  }

  static String hexToString(String hex) {
    List<int> bytes = [];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return String.fromCharCodes(bytes);
  }

  Future<void> writeToFileInCatch(String connectionType, String type) async {
    await fileService.writeToFile(
      "$connectionType Failed to send: $type",
      overrideLogLevel: LogLevel.ERROR,
    );
  }

  static String getFormattedDateTime() {
    DateTime now = DateTime.now();
    final DateFormat formatter = DateFormat('ddMMyyHHmmss');
    return formatter.format(now);
  }

  static String getDateMonthYearDate() {
    DateTime now = DateTime.now();
    final DateFormat formatter = DateFormat('ddMMyy');
    return formatter.format(now);
  }

  static String getSixDigitUniqueNumber() {
    int timestamp = DateTime.now().millisecondsSinceEpoch;
    String number = (timestamp % 1000000).toString().padLeft(6, '0');
    return number;
  }
}
