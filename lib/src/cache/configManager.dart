import 'dart:convert';
import 'package:ecrlib/src/model/config/index.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConfigManager {
  static const String _configKey = "config_data";

  static Future<int> setConfiguration(ConfigModel config) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    ConfigModel? storedConfig =
        await getConfiguration() ?? ConfigModel(); // Ensure it's not null

    ConfigModel configData = ConfigModel(
      tcpIP:
          config.tcpIP ??
          storedConfig.tcpIP, // Prioritize new config if available
      tcpPort: config.tcpPort ?? storedConfig.tcpPort,
      cashRegisterNumber:
          config.cashRegisterNumber ?? storedConfig.cashRegisterNumber,
      terminalSlNo: config.terminalSlNo ?? storedConfig.terminalSlNo,
      terminalId: config.terminalId ?? storedConfig.terminalId,
      ecrUniqueNo: config.ecrUniqueNo ?? storedConfig.ecrUniqueNo,
      isTransactionInProgress:
          config.isTransactionInProgress ??
          storedConfig.isTransactionInProgress,
      logLevel: config.logLevel ?? storedConfig.logLevel,
      retetionDays: config.retetionDays ?? storedConfig.retetionDays,
      connectionType: config.connectionType ?? storedConfig.connectionType,
      device: config.device ?? storedConfig.device,
      bluetoothName: config.bluetoothName ?? storedConfig.bluetoothName,
      isBluetoothConnected:
          config.isBluetoothConnected ?? storedConfig.isBluetoothConnected,
      isTcpIpConnected:
          config.isTcpIpConnected ?? storedConfig.isTcpIpConnected,
      isApptoAppConnected:
          config.isApptoAppConnected ?? storedConfig.isApptoAppConnected,
    );

    String configJson = jsonEncode(configData.toJson());
    await prefs.setString(_configKey, configJson);
    return 0;
  }

  static Future<ConfigModel?> getConfiguration() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? configJson = prefs.getString(_configKey);

    if (configJson == null) {
      print("No stored configuration found");
      return null;
    }

    try {
      return ConfigModel.fromJson(jsonDecode(configJson));
    } catch (e) {
      print("Error decoding config: $e");
      return null;
    }
  }
}
