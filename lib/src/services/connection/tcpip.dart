import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:ecrlib/ecrlib.dart';
import 'package:ecrlib/src/abstracts/tcp_connection.dart';
import 'package:ecrlib/src/cache/configManager.dart';
import 'package:ecrlib/src/model/config/index.dart';
import 'package:ecrlib/src/model/transaction/request.dart';
import 'package:ecrlib/src/services/connection/logger.dart';
import 'package:ecrlib/src/utils/commonMethods.dart';
import 'package:logger/logger.dart';
import 'package:ecrlib/src/model/healthCheck/request.dart';
import 'package:ecrlib/src/model/register/request.dart';
import 'package:ecrlib/src/model/register/response.dart';

abstract class ComEventListener {
  void onEvent(int eventId);
  void onSuccess(Object message);
  void onFailure(String errorMsg, int errorCode);
}

class TcpConnect implements TcpConnection {
  static final TcpConnect _instance = TcpConnect._();
  factory TcpConnect() => _instance;
  TcpConnect._();

  final Logger logger = Logger(printer: PrettyPrinter());
  ConfigModel config = ConfigModel();
  final FileService fileService = FileService();

  Socket? _socket;
  String? _ip;
  int? _port;
  String? _cashRegisterNumber;
  RegisterResponse? _registerResponse;
  Timer? _healthCheckTimer;
  ComEventListener? _eventListener;
  // Map to store callbacks based on transaction ID
  final Map<String, Function(Map<String, dynamic>)> _successCallbacks = {};
  final Map<String, Function(String, int)> _failureCallbacks = {};

  @override
  Future<int> connectTCP(String ip, int port, String cashRegiNum) async {
    if (_socket != null) {
      logger.i('TCP/IP Already connected');
      return 0;
    }

    _ip = ip;
    _port = port;
    _cashRegisterNumber = cashRegiNum;

    try {
      _socket = await Socket.connect(
        ip,
        port,
        // onBadCertificate: (_) => true,
        timeout: Duration(seconds: 10),
      );

      _setupSocketListeners();
      if (_registerResponse == null) {
        _register(cashRegiNum);
      }

      logger.i('TCP/IP Connected to $ip:$port');
      await fileService.writeToFile(
        "TCP/IP Connected to $ip:$port",
        overrideLogLevel: LogLevel.INFO,
      );

      return 0;
    } catch (e) {
      logger.e('TCP/IP Connection failed', error: e);
      await fileService.writeToFile(
        "TCP/IP Connection failed: $e",
        overrideLogLevel: LogLevel.ERROR,
      );
      return 1;
    }
  }

  void _setupSocketListeners() {
    _socket?.listen(
      (data) async {
        try {
          config.isTransactionInProgress = false;
          await ConfigManager.setConfiguration(config);
          String utf8String = utf8.decode(data);
          String xoredString = EncryptionUtil.encryptDecrypt(utf8String);
          logger.d('Decrypted Text: $xoredString');
          if (xoredString.contains('responseBody')) {
            Map<String, dynamic> decodedJson = jsonDecode(xoredString);
            print("Decoded JSON: $decodedJson");
            String encryptedText = EncryptionUtil.hexToString(
              decodedJson['responseBody'],
            ).replaceAll('ï¿½', ';');
            logger.i('Decrypted Text: $encryptedText');
            await fileService.writeToFile(
              " Received TCP/IP Transcation response: $encryptedText",
              overrideLogLevel: LogLevel.INFO,
            );
            await fileService.writeToFile(
              ".......................................................",
              overrideLogLevel: LogLevel.INFO,
            );
            _eventListener?.onSuccess(encryptedText);
          } else {
            final response = jsonDecode(utf8String);

            if (response['trxnType'] == 17) {
              _registerResponse = RegisterResponse.fromJson(response);
              config
                ..terminalId = _registerResponse?.terminalId
                ..terminalSlNo = _registerResponse?.terminalSlNo;
              ConfigManager.setConfiguration(config);
              logger.i('Received TCP/IP register response: $response');
              await fileService.writeToFile(
                "Received TCP/IP register response: $response",
                overrideLogLevel: LogLevel.INFO,
              );
              await fileService.writeToFile(
                ".......................................................",
                overrideLogLevel: LogLevel.INFO,
              );
            } else if (response['trxnType'] == 25) {
              await fileService.writeToFile(
                " Received TCP/IP Health Check response: $response",
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
              _eventListener?.onFailure("TCP/IP Transaction failed", 1003);
            }
          }
        } catch (e) {
          logger.e('TCP/IP Error processing socket data: $e');
          await fileService.writeToFile(
            "TCP/IP Error processing socket data: $e",
            overrideLogLevel: LogLevel.ERROR,
          );
        }
      },
      onDone: () async {
        logger.e('TCP/IP Socket closed by terminal.');
        await fileService.writeToFile(
          "TCP/IP Socket closed by terminal.",
          overrideLogLevel: LogLevel.ERROR,
        );
        _socket = null;
      },
      onError: (error) {
        logger.e('TCP/IP Socket error: $error');
        _cleanup('error');
      },
    );
  }

  void _register(String cashRegiNum) {
    final request = RegisterRequest(
      cashRegisterNumber: cashRegiNum,
      trxnType: 17,
    );
    _send(request.toJson(), 'register');
    fileService.writeToFile(
      "Sent TCP/IP register request>: ${request.toJson()}",
      overrideLogLevel: LogLevel.INFO,
    );
    logger.i('Sent TCP/IP register request: ${request.toJson()}');
  }

  @override
  Future<void> checkTCPStatus(ComEventListener listener, int interval) async {
    _eventListener = listener;

    if (_registerResponse == null) {
      logger.e('TCP/IP Missing registration');
      return;
    }

    _sendHealthCheck();

    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(Duration(seconds: interval), (_) async {
      print("config.isTransactionInProgress ${config.isTransactionInProgress}");
      if (config.isTransactionInProgress == true) {
        logger.i('TCP/IP Transaction in progress, skipping health check');
        await fileService.writeToFile(
          "TCP/IP Transaction in progress, skipping health check",
          overrideLogLevel: LogLevel.INFO,
        );
      } else {
        logger.i('TCP/IP Sending health check...');
        _sendHealthCheck();
      }
    });
    logger.d('TCP/IP Health check started ($interval sec)');
  }

  Future<void> _sendHealthCheck() async {
    EncryptionUtil.encryptDecrypt('test');
    if (_socket == null) {
      if (_ip == null || _port == null || _cashRegisterNumber == null) {
        logger.w('TCP/IP Missing connection details');
        _eventListener?.onEvent(1003);
        return;
      }
      final result = await connectTCP(_ip!, _port!, _cashRegisterNumber!);
      if (result != 0) {
        logger.e('TCP/IP Failed to reconnect for handshake');
        _eventListener?.onEvent(1003);
        return;
      }
    }

    final request = HealthCheckRequest(
      cashRegisterNumber: _cashRegisterNumber!,
      terminalId: _registerResponse!.terminalId,
      terminalSlno: _registerResponse!.terminalSlNo,
      trxnType: 25,
      isDemoMode: _registerResponse!.isDemoMode ?? false,
    );
    _send(request.toJson(), 'health check');
  }

  void _send(Map<String, dynamic> json, String type) {
    try {
      _socket?.add(utf8.encode(jsonEncode(json)));
      _socket?.flush();
      logger.i('TCP/IP Sent $type');
      fileService.writeToFile(
        "Sent TCP/IP Health Check Request: $json",
        overrideLogLevel: LogLevel.INFO,
      );
    } catch (e) {
      logger.e('TCP/IP Failed to send $type: $e');
      _cleanup('send error');
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

  void _sendTransaction(Map<String, dynamic> json, String type) {
    try {
      String jsonString = jsonEncode(json);

      String hexString = EncryptionUtil.stringToHex(jsonString);

      String xorData = EncryptionUtil.encryptDecrypt(hexString);

      Uint8List bytes = Uint8List.fromList(xorData.codeUnits);

      _socket?.add(bytes);
      _socket?.flush();
      logger.i('TCP/IP Sent $type');
      fileService.writeToFile(
        "Sent TCP/IP Transcation Request: $jsonString",
        overrideLogLevel: LogLevel.INFO,
      );
    } catch (e) {
      logger.e('TCP/IP Failed to send $type: $e');
      fileService.writeToFile(
        "TCP/IP Failed to send $type: $e",
        overrideLogLevel: LogLevel.ERROR,
      );
      _cleanup('send error');
    }
  }

  void _cleanup(String reason) {
    logger.d('📴 Socket $reason');
    _healthCheckTimer?.cancel();
    _socket?.close();
    _socket = null;
    _healthCheckTimer = null;
    _eventListener?.onEvent(1002);
  }

  Future<void> doTransaction({
    required String reqData,
    required int txnType,
    required String signature,
    required ComEventListener listener,
  }) async {
    _eventListener = listener;
    config = (await ConfigManager.getConfiguration()) ?? ConfigModel();

    if (_socket == null) {
      logger.i("TCP/IP Socket is not connected. Attempting to reconnect...");

      final result = await connectTCP(
        config.tcpIP!,
        config.tcpPort!,
        config.cashRegisterNumber!,
      );
      if (result != 0) {
        _eventListener?.onFailure(
          "TCP/IP Failed to reconnect for transaction",
          1003,
        );
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

      _sendTransaction(transactionRequest.toJson(), "transaction");
      _sessionTimeout();

      logger.i(
        "Sent TCP/IP Transaction Request: ${transactionRequest.toJson()}",
      );
      await fileService.writeToFile(
        "Sent TCP/IP Transaction Request: ${transactionRequest.toJson()}",
        overrideLogLevel: LogLevel.INFO,
      );
    } catch (e) {
      logger.e("TCP/IP Error in transaction: $e");
      _eventListener?.onFailure(
        "TCP/IP Transaction failed due to an exception",
        500,
      );
    }
  }

  @override
  void disconnect() {
    _registerResponse = null;
    _cashRegisterNumber = null;
    _cleanup("Disconnected");
  }
}
