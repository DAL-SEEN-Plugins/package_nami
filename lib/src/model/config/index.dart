import 'package:bluetooth_classic/models/device.dart';

import '../../enums.dart';

class ConfigModel {
  String? tcpIP;
  int? tcpPort;
  String? cashRegisterNumber;
  String? terminalSlNo;
  String? terminalId;
  String? ecrUniqueNo;
  String? bluetoothName;
  bool? isTransactionInProgress = false;
  LogLevel? logLevel = LogLevel.INFO;
  int? retetionDays = 2;
  String? connectionType;
  Device? device;
  bool? isBluetoothConnected = false;
  bool? isTcpIpConnected = false;
  bool? isApptoAppConnected = false;

  ConfigModel({
    this.tcpIP,
    this.tcpPort,
    this.cashRegisterNumber,
    this.terminalSlNo,
    this.terminalId,
    this.ecrUniqueNo,
    this.bluetoothName,
    this.isTransactionInProgress,
    this.logLevel,
    this.retetionDays,
    this.connectionType,
    this.device,
    this.isBluetoothConnected,
    this.isTcpIpConnected,
    this.isApptoAppConnected,
  });

  factory ConfigModel.fromJson(Map<String, dynamic> json) {
    return ConfigModel(
      tcpIP: json["tcpIP"] as String?,
      tcpPort: (json["tcpPort"] as num?)?.toInt(),
      cashRegisterNumber: json["cashRegisterNumber"] as String?,
      terminalSlNo: json["terminalSlNo"] as String?,
      terminalId: json["terminalId"] as String?,
      ecrUniqueNo: json["ecrUniqueNo"] as String?,
      isTransactionInProgress: json["isTransactionInProgress"] as bool?,
      bluetoothName: json["bluetoothName"] as String?,
      logLevel: LogLevel.values.firstWhere(
        (e) => e.toString().split('.').last == json['logLevel'],
        orElse: () => LogLevel.INFO,
      ),
      retetionDays: json['retetionDays'],
      connectionType: json["connectionType"] as String?,
      device: Device(address: json['address'] ?? '', name: json['name']),
      isBluetoothConnected: json["isBluetoothConnected"] as bool?,
      isTcpIpConnected: json["isTcpIpConnected"] as bool?,
      isApptoAppConnected: json["isApptoAppConnected"] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "tcpIP": tcpIP,
      "tcpPort": tcpPort,
      "cashRegisterNumber": cashRegisterNumber,
      "terminalSlNo": terminalSlNo,
      "terminalId": terminalId,
      "ecrUniqueNo": ecrUniqueNo,
      "isTransactionInProgress": isTransactionInProgress,
      "bluetoothName": bluetoothName,
      "logLevel": logLevel?.toString().split('.').last,
      "retetionDays": retetionDays,
      "connectionType": connectionType,
      "address": device?.address,
      "name": device?.name,
      "isBluetoothConnected": isBluetoothConnected,
      "isTcpIpConnected": isTcpIpConnected,
      "isApptoAppConnected": isApptoAppConnected,
    };
  }
}
