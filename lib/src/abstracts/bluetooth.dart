import 'package:bluetooth_classic/models/device.dart';
import 'package:ecrlib/ecrlib.dart';

abstract class BluetoothConnection {
  Future<void> getDevices();
  Future<int> connectDevice(Device device, String cashRegiNum );
  Future<void> disconnectDevice();
  Future<void> sendRequest(Map<String, dynamic> requestData, String requestType);
  Future<void> checkBluetoothStatus(ComEventListeners listener, int interval);
}