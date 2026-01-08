import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:bluetooth_classic/bluetooth_classic.dart';
import 'package:bluetooth_classic/models/device.dart';
import 'package:ecrlib/ecrlib.dart';
import 'package:ecrlib/src/abstracts/bluetooth.dart';
import 'package:ecrlib/src/model/healthCheck/request.dart';
import 'package:ecrlib/src/model/healthCheck/response.dart';
import 'package:ecrlib/src/model/register/request.dart';
import 'package:ecrlib/src/model/register/response.dart';
import 'package:ecrlib/src/model/transaction/request.dart';
import 'package:ecrlib/src/services/connection/logger.dart';
import 'package:ecrlib/src/utils/commonMethods.dart';
import 'package:ecrlib/src/utils/constants.dart';
import 'package:logger/logger.dart';
import 'package:ecrlib/src/utils/jsonUtils.dart';
// import 'package:ecrlib/src/model/device/index.dart';

abstract class ComEventListeners {
  void onEvent(int eventId);
  void onSuccess(Object message);
  void onFailure(String errorMsg, int errorCode);
}

class BluetoothService implements BluetoothConnection {
  final BluetoothClassic _bluetoothClassicPlugin = BluetoothClassic();
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  final Logger logger = Logger(printer: PrettyPrinter());
  final FileService fileService = FileService();

  BluetoothService._internal() {
    _startListening();
  }

  List<Device> _devices = [];

  List<Device> get devices => _devices;

  int _deviceStatus = Constants.disconnected;
  String _statusText = Constants.statusDisconnected;
  Device _connectedDevice = Device(address: '', name: '');
  Timer? _healthCheckTimer;
  RegisterResponse? registerResponse;
  ConfigModel config = ConfigModel();
  ComEventListeners? _eventListener;
  String? _cashRegisterNumber;

  void _startListening() {
    _bluetoothClassicPlugin.onDeviceStatusChanged().listen((status) {
      _deviceStatus = status;
      _statusText = getDeviceStatusText(status);
    });

    _bluetoothClassicPlugin.onDeviceDataReceived().listen((Uint8List data) {
      logger.i('Bluetooth data lenght${data.length}');
      handleReceivedData(data);
    });
  }

  @override
  Future<void> getDevices() async {
    final granted = await _bluetoothClassicPlugin.initPermissions();
    if (!granted) {
      throw Exception(Constants.bluetoothPermissionError);
    }
    if (_devices.isEmpty) {
      final pairedDevices = await _bluetoothClassicPlugin.getPairedDevices();
      _devices =
          pairedDevices
              .map(
                (device) => Device(address: device.address, name: device.name),
              )
              .toList();
    }
  }

  @override
  Future<int> connectDevice(dynamic device, String cashRegiNum) async {
    try {
      await _bluetoothClassicPlugin.connect(device?.address, Constants.uuid);

      logger.i(Constants.Deviceconnectedsuccss);
      await fileService.writeToFile(
        "Bluetooth Device ${device.name} connected successfully",
        overrideLogLevel: LogLevel.INFO,
      );

      if (_deviceStatus != Constants.connected) {
        throw Exception(Constants.Deviceconnectfailed);
      }
      _cashRegisterNumber = cashRegiNum;
      _connectedDevice = device;

      _deviceStatus = Constants.connected;
      _statusText = Constants.statusConnected;
      if (config.terminalSlNo == null) {
        _register(cashRegiNum);
      }
      return 0;
    } catch (e) {
      logger.e("Bluetooth Device not connected $e");
      await fileService.writeToFile(
        "Bluetooth Device not connected...",
        overrideLogLevel: LogLevel.ERROR,
      );
      return 1;
    }
  }

  Future<void> _register(String cashRegiNum) async {
    _cashRegisterNumber = cashRegiNum;
    final request = RegisterRequest(
      cashRegisterNumber: cashRegiNum,
      trxnType: 17,
    );
    logger.i("Bluetooth  cash register: $cashRegiNum");
    _send(request.toJson(), 'register');
  }

  void _send(Map<String, dynamic> json, String type) async {
    try {
      String jsonString = jsonEncode(json);
      logger.i('${Constants.registerRequestSent} $jsonString');
      await fileService.writeToFile(
        "Sent Bluetooth Register Request $jsonString",
        overrideLogLevel: LogLevel.INFO,
      );
      Uint8List byteData = Uint8List.fromList(utf8.encode(jsonString));
      await _bluetoothClassicPlugin.write(utf8.decode(byteData));
    } catch (e) {
      logger.e("Failed to send $type: $e");
      await fileService.writeToFile(
        "Bluetooth Failed to send $type: $e",
        overrideLogLevel: LogLevel.ERROR,
      );
    }
  }

  Uint8List _buffer = Uint8List(0);
  int? _expectedLength;

  Future<void> handleReceivedData(Uint8List data) async {
    _buffer = Uint8List.fromList([..._buffer, ...data]);
    config.isTransactionInProgress = false;
    await ConfigManager.setConfiguration(config);

    while (true) {
      if (_expectedLength == null) {
        if (_buffer.length >= 4) {
          // 🔑 FIX: decode header as ASCII (safe for numeric length fields)
          String lengthStr =
              ascii.decode(_buffer.sublist(0, 4), allowInvalid: true).trim();
          _expectedLength = int.tryParse(lengthStr);

          if (_expectedLength == null || _expectedLength! <= 0) {
            logger.e("Bluetooth Invalid Data Length Received: '$lengthStr'");
            _eventListener?.onEvent(1003);
            await fileService.writeToFile(
              "Bluetooth Invalid Data Length Received: '$lengthStr'",
              overrideLogLevel: LogLevel.ERROR,
            );

            _buffer = Uint8List(0);
            return;
          }
          _buffer = _buffer.sublist(4);
        } else {
          return;
        }
      }

      if (_buffer.length >= _expectedLength!) {
        Uint8List message = _buffer.sublist(0, _expectedLength!);

        // 🔑 FIX: safely decode payload
        String utf8String;
        try {
          utf8String = utf8.decode(message, allowMalformed: true);
        } catch (e) {
          logger.e("Bluetooth Payload Decode Error: $e");
          // fallback: show raw hex if decode fails
          utf8String = message
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join(" ");
        }

        processCompleteData(utf8String);

        _buffer = _buffer.sublist(_expectedLength!);
        _expectedLength = null;
      } else {
        logger.i(
          "Bluetooth [Flutter] Waiting for More Data... Current Buffer: ${_buffer.length}/${_expectedLength}",
        );
        return;
      }
    }
  }

  Future<int> ensureSocketOpen() async {
    try {
      if (_deviceStatus == Constants.connected) {
        _eventListener?.onEvent(1000);
        return 1;
      } else {
        await connectDevice(_connectedDevice, _cashRegisterNumber!);
        return 0;
      }
    } catch (e) {
      logger.e("Bluetooth Failed to reopen socket: $e");
      await fileService.writeToFile(
        "Bluetooth Failed to reopen socket: $e",
        overrideLogLevel: LogLevel.ERROR,
      );
      _eventListener?.onEvent(1003);
      return 1;
    }
  }

  @override
  Future<void> checkBluetoothStatus(
    ComEventListeners listener,
    int interval,
  ) async {
    _eventListener = listener;

    _sendHealthCheckRequest();

    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(Duration(seconds: interval), (_) async {
      if (config.isTransactionInProgress == true) {
        logger.i('Bluetooth Transaction in progress, skipping health check');
      } else {
        logger.i('Bluetooth Sending health check...');
        _sendHealthCheckRequest();
      }
    });
  }

  Future<void> _sendHealthCheckRequest() async {
    int a = await ensureSocketOpen();
    if (a == 1) {
      return;
    } else {
      final request = HealthCheckRequest(
        cashRegisterNumber: _cashRegisterNumber!,
        terminalId: registerResponse?.terminalId ?? "",
        terminalSlno: registerResponse?.terminalSlNo ?? "",
        trxnType: 25,
        isDemoMode: false,
      );

      try {
        await sendRequest(request.toJson(), 'Health Check');
      } catch (e) {
        logger.e('Bluetooth Failed to send Bluetooth Health Check: $e');
        await fileService.writeToFile(
          "Bluetooth Failed to send Bluetooth Health Check: $e",
          overrideLogLevel: LogLevel.ERROR,
        );
        _eventListener?.onEvent(1003);
      }
    }
  }

  void _sessionTimeout() {
    if (config.isTransactionInProgress == true) {
      Future.delayed(Duration(seconds: 120), () async {
        logger.e("Transaction timeout: No response received in 2 minutes");
        await fileService.writeToFile(
          "Transaction timeout: No response in 2 minutes",
          overrideLogLevel: LogLevel.ERROR,
        );
        _eventListener?.onFailure(
          "Transaction timed out after 2 minutes",
          4000,
        );
        config.isTransactionInProgress = false;
      });
    }
  }

  @override
  Future<void> sendRequest(
    Map<String, dynamic> requestData,
    String requestType,
  ) async {
    try {
      Uint8List jsonBytes = Uint8List.fromList(
        utf8.encode(jsonEncode(requestData)),
      );
      await _bluetoothClassicPlugin.write(utf8.decode(jsonBytes));
      logger.i("Bluetooth request sent: $requestData");
      await fileService.writeToFile(
        "Health Check bluetooth request sent: $requestData",
        overrideLogLevel: LogLevel.INFO,
      );
    } catch (e) {
      logger.e("Bluetooth Failed to send $requestType request: $e");
      await fileService.writeToFile(
        "Bluetooth Failed to send Bluetooth request: $e",
        overrideLogLevel: LogLevel.ERROR,
      );
    }
  }

  void _sendTransaction(Map<String, dynamic> json, String type) async {
    try {
      String jsonString = jsonEncode(json);
      logger.i('Sending $type: $jsonString');
      String hexString = EncryptionUtil.stringToHex(jsonString);
      String xorData = EncryptionUtil.encryptDecrypt(hexString);
      Uint8List bytes = Uint8List.fromList(xorData.codeUnits);
      await _bluetoothClassicPlugin.write(utf8.decode(bytes));
      logger.i('Sent $type via Bluetooth');
    } catch (e) {
      logger.e('Failed to send $type via Bluetooth: $e');
      await fileService.writeToFile(
        "Failed to send $type via Bluetooth: $e",
        overrideLogLevel: LogLevel.ERROR,
      );
    }
  }

  @override
  Future<void> doTransaction({
    required String reqData,
    required int txnType,
    required String signature,
    required ComEventListeners listener,
  }) async {
    _eventListener = listener;
    config = (await ConfigManager.getConfiguration()) ?? ConfigModel();

    if (_deviceStatus != Constants.connected) {
      logger.e("Bluetooth is not connected. Attempting to reconnect...");
      await fileService.writeToFile(
        "Bluetooth is not connected. Attempting to reconnect...",
        overrideLogLevel: LogLevel.ERROR,
      );

      final result = await connectDevice(
        _connectedDevice,
        _cashRegisterNumber!,
      );
      if (result != 0) {
        _eventListener?.onEvent(1010);
        return;
      }
    }

    try {
      final transactionRequest = TransactionRequest(
        cashRegisterNo: _cashRegisterNumber!,
        reqData: reqData,
        trxnType: txnType,
        terminalID: config.terminalId ?? "",
        isDemoMode: true,
        szSignature: signature,
      );

      _sendTransaction(transactionRequest.toJson(), 'transaction');
      _sessionTimeout();
      logger.i(
        "Sent Bluetooth Transaction Request: ${transactionRequest.toJson()}",
      );
      await fileService.writeToFile(
        "Sent Bluetooth Transaction Request: ${transactionRequest.toJson()}",
        overrideLogLevel: LogLevel.INFO,
      );
    } catch (e) {
      logger.e(" Error in Bluetooth transaction: $e");
      await fileService.writeToFile(
        "Error in Bluetooth transaction: $e",
        overrideLogLevel: LogLevel.ERROR,
      );
      _eventListener?.onEvent(1010);
    }
  }

  @override
  Future<void> disconnectDevice() async {
    await _bluetoothClassicPlugin.disconnect();
    _deviceStatus = Constants.disconnected;
    _statusText = Constants.statusDisconnected;
  }

  String getDeviceStatusText(int status) {
    switch (status) {
      case Constants.connected:
        return Constants.statusConnected;
      case Constants.connecting:
        return Constants.statusConnecting;
      case Constants.disconnected:
        return Constants.statusDisconnected;
      default:
        return Constants.statusUnckown;
    }
  }

  Future<void> processCompleteData(String utf8String) async {
    try {
      logger.d('Bluetooth Raw UTF-8 Data: $utf8String');

      if (!isJson(utf8String)) {
        utf8String = EncryptionUtil.encryptDecrypt(utf8String);
        logger.d('Bluetooth Decrypted Data: $utf8String');
      }

      Map<String, dynamic> response = jsonDecode(utf8String);
      logger.d('BluetoothParsed JSON Response: $response');

      if (response.containsKey('responseBody')) {
        String decryptedText = EncryptionUtil.hexToString(
          response['responseBody'],
        );
        decryptedText = decryptedText.replaceAll('ï¿½', ';');
        logger.i('Received Bluetooth Transaction response: $decryptedText');
        await fileService.writeToFile(
          "Received Bluetooth Transaction response: $decryptedText",
          overrideLogLevel: LogLevel.INFO,
        );
        await fileService.writeToFile(
          ".......................................................",
          overrideLogLevel: LogLevel.INFO,
        );

        _eventListener?.onSuccess(decryptedText);
      } else if (response['trxnType'] == 17) {
        registerResponse = RegisterResponse.fromJson(response);
        config
          ..terminalId = registerResponse?.terminalId
          ..terminalSlNo = registerResponse?.terminalSlNo;
        ConfigManager.setConfiguration(config);
        logger.i('Received Bluetooth Register response: $response');
        await fileService.writeToFile(
          "Received Bluetooth Register response: $response",
          overrideLogLevel: LogLevel.INFO,
        );
        await fileService.writeToFile(
          ".......................................................",
          overrideLogLevel: LogLevel.INFO,
        );
      } else if (response['trxnType'] == 25) {
        logger.i('Received Bluetooth Health Check response: $response');
        await fileService.writeToFile(
          "Received Bluetooth Health Check response: $response",
          overrideLogLevel: LogLevel.INFO,
        );
        await fileService.writeToFile(
          ".......................................................",
          overrideLogLevel: LogLevel.INFO,
        );

        _eventListener?.onEvent(
          response['isPayAppActive'] == true ? 1000 : 3000,
        );
      } else {
        logger.e(
          'Unexpected Bluetooth Transaction Type: ${response['trxnType']}',
        );
        await fileService.writeToFile(
          "Unexpected Bluetooth Transaction Type: ${response['trxnType']}",
          overrideLogLevel: LogLevel.ERROR,
        );
        _eventListener?.onFailure("Bluetooth Transaction failed", 1003);
      }
    } catch (e) {
      logger.e('Bluetooth Error processing data: $e');
      await fileService.writeToFile(
        "Bluetooth Error processing data: $e",
        overrideLogLevel: LogLevel.ERROR,
      );
    }
  }
}
