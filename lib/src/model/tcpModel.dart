abstract class TcpRequestModel {
  static Map<String, dynamic> getHandshakePayload() {
    return {
      'pType': 1,
      'msgType': 7,
      'isDemoMode': true,
      'cashierId': '12345678',
    };
  }
}
