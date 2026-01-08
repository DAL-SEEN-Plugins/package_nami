import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:ecrlib/ecrlib.dart';
import 'package:ecrlib/src/model/register/request.dart';
import 'package:ecrlib/src/model/register/response.dart';
import 'package:ecrlib/src/model/transaction/request.dart';
import 'package:ecrlib/src/services/connection/logger.dart';
import 'package:ecrlib/src/utils/commonMethods.dart';
import 'package:ecrlib/src/utils/constants.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:logger/logger.dart';

abstract class ComEventListenerss {
  void onEvent(int eventId);
  void onSuccess(Object message);
  void onFailure(String errorMsg, int errorCode);
}

class AppToAppConnect {
  WebSocketChannel? _channel;
  final FileService fileService = FileService();
  final EncryptionUtil commonMethod = EncryptionUtil();

  final Logger logger = Logger();
  ConfigModel config = ConfigModel();
  String? _cashRegisterNumber;
  RegisterResponse? registerResponse;
  String? lastResponse;
  ComEventListenerss? _eventListenerss;

  Future<void> _establishConnection() async {
    String url = Constants.url;
    try {
      _channel = IOWebSocketChannel.connect(url);
      logger.i("AppToApp Connected to WebSocket");
      await fileService.writeToFile(
        "AppToApp Connected to WebSocket...",
        overrideLogLevel: LogLevel.INFO,
      );
    } catch (error) {
      logger.e("AppToApp Connection failed: $error");
      await fileService.writeToFile(
        "AppToApp Connection failed...",
        overrideLogLevel: LogLevel.ERROR,
      );
      throw Exception("AppToApp WebSocket connection failed");
    }
  }

  Future<void> _closeConnection() async {
    if (_channel != null) {
      try {
        await _channel!.sink.close();
        _channel = null;
        logger.i("AppToApp WebSocket connection closed");
        await fileService.writeToFile(
          "AppToApp WebSocket connection closed...",
          overrideLogLevel: LogLevel.INFO,
        );
        await fileService.writeToFile(
          ".......................................................",
          overrideLogLevel: LogLevel.INFO,
        );
      } catch (e) {
        logger.e("AppToApp Error closing WebSocket connection: $e");
        await fileService.writeToFile(
          "AppToApp Error closing WebSocket connection: $e",
          overrideLogLevel: LogLevel.ERROR,
        );
      }
    } else {
      logger.i("AppToApp WebSocket connection already closed");
    }
  }

  Future<int?> connect(String cashRegiNum) async {
    Completer<int?> completer = Completer<int?>();
    bool responseProcessed = false;
    try {
      await _establishConnection();

      _channel?.stream.listen(
        (data) async {
          if (!responseProcessed) {
            responseProcessed = true;
            try {
              String jsonString =
                  (data is List<int>) ? utf8.decode(data) : data;
              Map<String, dynamic> jsonResponse = jsonDecode(jsonString);

              logger.i("Received AppToApp Register response: $jsonResponse");
              await fileService.writeToFile(
                "Received AppToApp Register response: $jsonResponse",
                overrideLogLevel: LogLevel.INFO,
              );

              if (jsonResponse['trxnType'] == 17) {
                registerResponse = RegisterResponse.fromJson(jsonResponse);
                config
                  ..terminalId = registerResponse?.terminalId
                  ..terminalSlNo = registerResponse?.terminalSlNo;
                ConfigManager.setConfiguration(config);
              }

              if (!completer.isCompleted) completer.complete(0);
            } catch (e) {
              logger.e("AppToApp Invalid JSON received: $data, Error: $e");
              await fileService.writeToFile(
                "AppToApp Invalid JSON received...",
                overrideLogLevel: LogLevel.ERROR,
              );
              if (!completer.isCompleted) completer.complete(1);
            }
          }
        },
        onError: (error) async {
          logger.e("AppToApp WebSocket error: $error");
          await fileService.writeToFile(
            "AppToApp WebSocket error...",
            overrideLogLevel: LogLevel.ERROR,
          );
          if (!completer.isCompleted) completer.complete(1);
        },
        onDone: () async {
          logger.i("AppToApp WebSocket stream closed");
          await fileService.writeToFile(
            "AppToApp WebSocket stream closed...",
            overrideLogLevel: LogLevel.INFO,
          );
          _channel = null;
        },
      );

      await _register(cashRegiNum);

      await Future.delayed(Duration(seconds: 1));

      await _closeConnection();
      if (!completer.isCompleted) completer.complete(0);
    } catch (error) {
      logger.e("AppToApp Connection failed: $error");
      _channel = null;
      await fileService.writeToFile(
        "AppToApp Connection failed...",
        overrideLogLevel: LogLevel.ERROR,
      );
      if (!completer.isCompleted) completer.complete(1);
    }

    return completer.future;
  }

  Future<void> _register(String cashRegiNum) async {
    config = (await ConfigManager.getConfiguration()) ?? ConfigModel();
    final request = RegisterRequest(
      cashRegisterNumber: config.cashRegisterNumber ?? "",
      trxnType: 17,
    );
    try {
      _send(request.toJson(), 'Register');
    } catch (e) {
      logger.e("AppToApp Registration failed: $e");
      await fileService.writeToFile(
        "AppToApp Registration failed...",
        overrideLogLevel: LogLevel.ERROR,
      );
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
        _eventListenerss?.onFailure(
          "Transaction timed out after 2 minutes",
          4000,
        );
        config.isTransactionInProgress = false;
      });
    }
  }

  Future<void> _send(Map<String, dynamic> json, String type) async {
    try {
      String jsonString = jsonEncode(json);
      logger.i("Sent AppToApp Register Request: $jsonString");
      await fileService.writeToFile(
        "Sent AppToApp Register Request: $jsonString",
        overrideLogLevel: LogLevel.INFO,
      );

      _channel?.sink.add(utf8.encode(jsonString));
    } catch (e) {
      logger.e("Failed to send AppToApp Register: $type: $e");
      await fileService.writeToFile(
        "Failed to send AppToApp Register: $type: $e",
        overrideLogLevel: LogLevel.ERROR,
      );
    }
  }

  Future<void> doTransaction({
    required String reqData,
    required int txnType,
    required String signature,
    required ComEventListenerss listener,
  }) async {
    _eventListenerss = listener;
    config = (await ConfigManager.getConfiguration()) ?? ConfigModel();

    await _establishConnection();

    try {
      final transactionRequest = TransactionRequest(
        cashRegisterNo: _cashRegisterNumber ?? "",
        reqData: reqData,
        trxnType: txnType,
        terminalID: config.terminalId ?? "",
        isDemoMode: true,
        szSignature: signature,
      );

      logger.i(
        "Sent AppToApp Transaction Request: ${transactionRequest.toJson()}",
      );
      await fileService.writeToFile(
        "Sent AppToApp Transaction Request: ${transactionRequest.toJson()}",
        overrideLogLevel: LogLevel.INFO,
      );

      _sendTransaction(transactionRequest.toJson(), "transaction");
      _sessionTimeout();

      final Completer<void> completer = Completer<void>();

      _channel?.stream.listen(
        (data) async {
          try {
            String utf8String = utf8.decode(data);
            String xoredString = EncryptionUtil.encryptDecrypt(utf8String);
            logger.i('AppToApp Decrypted Text: $xoredString');

            if (xoredString.contains('responseBody')) {
              Map<String, dynamic> decodedJson = jsonDecode(xoredString);
              String encryptedText = EncryptionUtil.hexToString(
                decodedJson['responseBody'],
              );

              logger.i('AppToApp Decrypted: $encryptedText');

              encryptedText = encryptedText.replaceAll('ï¿½', ';');
              logger.i(
                'Received AppToApp transaction response: $encryptedText',
              );
              await fileService.writeToFile(
                "Received AppToApp transaction response: $encryptedText",
                overrideLogLevel: LogLevel.INFO,
              );

              _eventListenerss?.onSuccess(encryptedText);
            } else {
              final response = jsonDecode(utf8String);
              logger.i('Received: $response');
              await fileService.writeToFile(
                "Received non-transaction message: $response",
                overrideLogLevel: LogLevel.INFO,
              );
            }
            completer.complete();
            await _closeConnection();
          } catch (e) {
            logger.e("AppToApp Invalid JSON received: $data, Error: $e");
            await fileService.writeToFile(
              "AppToApp Invalid JSON received:  $data, Error: $e",
              overrideLogLevel: LogLevel.ERROR,
            );
            completer.completeError(e);
            await _closeConnection();
          }
        },
        onError: (error) async {
          logger.e("AppToApp WebSocket error: $error");
          await fileService.writeToFile(
            "AppToApp WebSocket error...",
            overrideLogLevel: LogLevel.ERROR,
          );

          _eventListenerss?.onFailure(
            "Transaction failed due to an error",
            500,
          );
          completer.completeError(error);
          await _closeConnection();
        },
        onDone: () async {
          logger.i("AppToApp WebSocket stream closed");
          await fileService.writeToFile(
            "AppToApp WebSocket stream closed...",
            overrideLogLevel: LogLevel.ERROR,
          );

          completer.complete();
          await _closeConnection();
        },
      );
    } catch (e) {
      logger.e("AppToApp Transaction error: $e");
      _eventListenerss?.onFailure(
        "Transaction failed due to an exception",
        500,
      );
      await _closeConnection();
    }
  }

  Future<void> _sendTransaction(Map<String, dynamic> json, String type) async {
    try {
      String jsonString = jsonEncode(json);
      String hexString = EncryptionUtil.stringToHex(jsonString);
      String xorData = EncryptionUtil.encryptDecrypt(hexString);
      _channel?.sink.add(Uint8List.fromList(xorData.codeUnits));
      logger.i('AppToApp Sent $type');
    } catch (e) {
      logger.e('Failed to send $type: $e');
      //await fileService.writeToFile("Failed to send $type",overrideLogLevel: LogLevel.ERROR,);
      commonMethod.writeToFileInCatch('AppToApp', type);
    }
  }

  Future<void> disconnect() async {
    await _closeConnection();
  }
}
