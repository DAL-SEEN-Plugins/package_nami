import 'dart:async';

import 'package:bluetooth_classic/models/device.dart';
import 'package:ecrlib/ecrlib.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const MaterialApp(home: NamiECRDemo()));
}

class NamiECRDemo extends StatefulWidget {
  const NamiECRDemo({super.key});

  @override
  State<NamiECRDemo> createState() => _NamiECRDemoState();
}

class _NamiECRDemoState extends State<NamiECRDemo>
    implements ComEventListener, ComEventListeners, ComEventListenerss {
  // Services
  final TcpConnect _tcpConnect = TcpConnect();
  final BluetoothService _bluetoothService = BluetoothService();
  final AppToAppConnect _appToAppConnect = AppToAppConnect();

  // Config
  final TextEditingController _ipController =
      TextEditingController(text: "192.168.68.66");
  final TextEditingController _portController =
      TextEditingController(text: "6666");
  final TextEditingController _crnController =
      TextEditingController(text: "12345678");
  final TextEditingController _amountController =
      TextEditingController(text: "1.00");
  final TextEditingController _terminalIdController =
      TextEditingController(text: "TID001");

  // State
  String _selectedConnection = "TCP/IP"; // TCP/IP, Bluetooth, AppToApp
  bool _isConnected = false;
  String _logs = "";
  Device? _selectedBluetoothDevice;

  // Transaction Types
  // Mapping based on doc.md snippet context roughly, or standard ECR types.
  // Using simple map for demo.
  final Map<int, String> _transactionTypes = {
    0: "Purchase",
    1: "Purchase w/ Cashback",
    2: "Refund",
    3: "Pre-Auth",
    22: "Print Summary",
  };
  int _selectedTrxnType = 0;

  void _log(String message) {
    debugPrint(message);
    if (mounted) {
      setState(() {
        _logs =
            "${DateFormat('HH:mm:ss').format(DateTime.now())}: $message\n$_logs";
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // Bluetooth init is done lazily or we can call getDevices to prep permissions
  }

  @override
  void dispose() {
    super.dispose();
  }

  // --- Connection Methods ---

  Future<void> _connect() async {
    if (_crnController.text.length != 8) {
      _log("Error: CRN must be 8 digits");
      return;
    }

    _log("Connecting via $_selectedConnection...");

    int result = -1;

    try {
      if (_selectedConnection == "TCP/IP") {
        result = await _tcpConnect.connectTCP(
          _ipController.text,
          int.parse(_portController.text),
          _crnController.text,
        );
      } else if (_selectedConnection == "Bluetooth") {
        if (_selectedBluetoothDevice == null) {
          _log("Error: No Bluetooth device selected");
          _log("Please scan and select a device first.");
          return;
        }
        result = await _bluetoothService.connectDevice(
          _selectedBluetoothDevice!,
          _crnController.text,
        );
      } else if (_selectedConnection == "AppToApp") {
        result = (await _appToAppConnect.connect(_crnController.text)) ?? -1;
      }

      if (result == 0) {
        setState(() {
          _isConnected = true;
        });
        _log("Connected Successfully!");

        // Save config as per doc recommendation (simulated)
        ConfigModel config = ConfigModel();
        config.cashRegisterNumber = _crnController.text;
        config.terminalId = _terminalIdController.text;
        if (_selectedConnection == "TCP/IP") config.isTcpIpConnected = true;
        // ... set other flags
        await ConfigManager.setConfiguration(config);
      } else {
        _log("Connection Failed with code: $result");
      }
    } catch (e) {
      _log("Connection Exception: $e");
    }
  }

  Future<void> _disconnect() async {
    try {
      if (_selectedConnection == "TCP/IP") {
        _tcpConnect.disconnect();
      } else if (_selectedConnection == "Bluetooth") {
        _bluetoothService.disconnectDevice();
      } else if (_selectedConnection == "AppToApp") {
        await _appToAppConnect.disconnect();
      }
    } catch (e) {
      _log("Disconnect error: $e");
    }

    setState(() {
      _isConnected = false;
    });
    _log("Disconnected");
  }

  // --- Transaction Methods ---

  Future<void> _doTransaction() async {
    if (!_isConnected) {
      _log("Not connected!");
      return;
    }

    // 1. Prepare Data
    // Amount to 12 digit string. E.g. 10.25 -> 000000001025
    double amount = double.tryParse(_amountController.text) ?? 0.0;
    String amountStr = (amount * 100).toInt().toString().padLeft(12, '0');

    String uniqueNo = EncryptionUtil.getSixDigitUniqueNumber();
    String ecrRef = "${_crnController.text}$uniqueNo";
    String dateTime = EncryptionUtil.getFormattedDateTime();
    String printPref = "1"; // Enable printing

    // Construct formatting string based on type
    String reqDataStr = "";

    switch (_selectedTrxnType) {
      case 0: // Purchase
        // Transaction Request Format: date;amount;printPref;ecrRef;
        // IMPORTANT: The doc says "Purchase Example: date;amount;printPref;ecrRef;"
        // Note the semicolons.
        reqDataStr = "$dateTime;$amountStr;$printPref;$ecrRef;";
        break;
      case 22: // Print Summary
        reqDataStr = "$dateTime;$printPref;$ecrRef;";
        break;
      default:
        reqDataStr = "$dateTime;$amountStr;$printPref;$ecrRef;";
    }

    _log("Request Data (Plain): $reqDataStr");
    String hexReqData = EncryptionUtil.stringToHex(reqDataStr);

    // 2. Signature
    // Doc says: getSha256Hash(config!.ecrUniqueNo ?? "", config!.terminalId ?? "")
    // We need to ensure config is set or pass values.
    // But wait config is a singleton loaded from storage inside doTransaction usually?
    // No, we set it earlier in _connect.
    // Actually we must ensure the `ecrUniqueNo` in config matches what used in `ecrRef`.

    // Let's update config first manually to be safe or just pass values if we could.
    // The `commonMethods` `getSha256Hash` takes (ecrRef, terminalId).
    // Wait, `EncryptionUtil.getSha256Hash` implementation I read earlier took (ecrRef, terminalId).
    // But the DOC snippet says: getSha256Hash(config!.ecrUniqueNo, config!.terminalId).
    // Let's re-read commonMethods.dart heavily.
    // static String getSha256Hash(String ecrRef, String terminalId) { String combinedInput = ecrRef + terminalId; ... }
    // So it just combines them.
    // The user snippet says: config!.ecrUniqueNo.
    // The `ecrRef` variable in snippet was: "${config!.cashRegisterNumber}${EncryptionUtil.getSixDigitUniqueNumber()}".
    // AND `config!.ecrUniqueNo` was set to that unique number.

    // So... effective input to hash is `uniqueNumber + terminalId`.

    ConfigModel config =
        await ConfigManager.getConfiguration() ?? ConfigModel();
    config.ecrUniqueNo = uniqueNo;
    config.cashRegisterNumber = _crnController.text;
    config.terminalId = _terminalIdController.text;
    await ConfigManager.setConfiguration(config);

    String signature =
        EncryptionUtil.getSha256Hash(uniqueNo, _terminalIdController.text);

    _log("Signature: $signature");

    // 3. Dispatch
    try {
      if (_selectedConnection == "TCP/IP") {
        await _tcpConnect.doTransaction(
          reqData: hexReqData,
          txnType: _selectedTrxnType,
          signature: signature,
          listener: this,
        );
      } else if (_selectedConnection == "Bluetooth") {
        await _bluetoothService.doTransaction(
          reqData: hexReqData,
          txnType: _selectedTrxnType,
          signature: signature,
          listener: this,
        );
      } else if (_selectedConnection == "AppToApp") {
        await _appToAppConnect.doTransaction(
          reqData: hexReqData,
          txnType: _selectedTrxnType,
          signature: signature,
          listener: this,
        );
      }
    } catch (e) {
      _log("Transaction Error: $e");
    }
  }

  // --- Listeners Implementation ---

  @override
  void onEvent(int eventId) {
    _log("Event Received: $eventId");
  }

  @override
  void onFailure(String errorMsg, int errorCode) {
    _log("Failure: $errorMsg (Code: $errorCode)");
  }

  @override
  void onSuccess(Object message) {
    // Message might be JSON or String.
    _log("Success: $message");
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("NamiECR Demo")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Connection Settings
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    DropdownButton<String>(
                      value: _selectedConnection,
                      items: ["TCP/IP", "Bluetooth", "AppToApp"]
                          .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedConnection = v!),
                      isExpanded: true,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                        controller: _crnController,
                        decoration: const InputDecoration(
                            labelText: "Cash Register Num (8 digits)")),
                    if (_selectedConnection == "TCP/IP") ...[
                      TextField(
                          controller: _ipController,
                          decoration:
                              const InputDecoration(labelText: "IP Address")),
                      TextField(
                          controller: _portController,
                          decoration: const InputDecoration(labelText: "Port")),
                    ],
                    if (_selectedConnection == "Bluetooth") ...[
                      ElevatedButton(
                        onPressed: () async {
                          _log("Getting Paired Devices...");
                          try {
                            await _bluetoothService.getDevices();
                            List<Device> devices = _bluetoothService.devices;
                            _log("Found ${devices.length} paired devices.");

                            if (devices.isNotEmpty) {
                              // Show dialog to pick
                              if (mounted) {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text("Select Device"),
                                    content: SizedBox(
                                      width: double.maxFinite,
                                      child: ListView.builder(
                                        shrinkWrap: true,
                                        itemCount: devices.length,
                                        itemBuilder: (ctx, i) => ListTile(
                                          title: Text(
                                              devices[i].name ?? "Unknown"),
                                          subtitle: Text(devices[i].address),
                                          onTap: () {
                                            setState(() {
                                              _selectedBluetoothDevice =
                                                  devices[i];
                                            });
                                            Navigator.pop(ctx);
                                            _log(
                                                "Selected: ${devices[i].name}");
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }
                            } else {
                              _log(
                                  "No paired devices found. Pair a device in system settings first.");
                            }
                          } catch (e) {
                            _log("Error getting devices: $e");
                          }
                        },
                        child: Text(_selectedBluetoothDevice == null
                            ? "Get Paired Devices"
                            : "Device: ${_selectedBluetoothDevice!.name}"),
                      )
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                            child: ElevatedButton(
                                onPressed: _isConnected ? null : _connect,
                                child: const Text("Connect"))),
                        const SizedBox(width: 10),
                        Expanded(
                            child: ElevatedButton(
                                onPressed: !_isConnected ? null : _disconnect,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red),
                                child: const Text("Disconnect"))),
                      ],
                    )
                  ],
                ),
              ),
            ),

            // Transaction
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListView(
                    children: [
                      const Text("Transaction",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      TextField(
                          controller: _amountController,
                          decoration:
                              const InputDecoration(labelText: "Amount (1.00)"),
                          keyboardType: TextInputType.number),
                      DropdownButton<int>(
                        value: _selectedTrxnType,
                        items: _transactionTypes.entries
                            .map((e) => DropdownMenuItem(
                                value: e.key, child: Text(e.value)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedTrxnType = v!),
                        isExpanded: true,
                      ),
                      TextField(
                          controller: _terminalIdController,
                          decoration:
                              const InputDecoration(labelText: "Terminal ID")),
                      const SizedBox(height: 10),
                      ElevatedButton(
                          onPressed: _isConnected ? _doTransaction : null,
                          child: const Text("Initiate Transaction")),
                    ],
                  ),
                ),
              ),
            ),

            // Logs
            const Text("Logs:", style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: Container(
                width: double.infinity,
                color: Colors.black12,
                padding: const EdgeInsets.all(8),
                child: SingleChildScrollView(
                  child: Text(_logs,
                      style:
                          const TextStyle(fontFamily: 'Courier', fontSize: 12)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
