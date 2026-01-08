import 'package:ecrlib/src/services/connection/tcpip.dart';

abstract class TcpConnection {
  Future<int> connectTCP(String ip, int port, String cashRegiNum);
  Future<void> checkTCPStatus(ComEventListener listener, int interval);
  void disconnect();
}
