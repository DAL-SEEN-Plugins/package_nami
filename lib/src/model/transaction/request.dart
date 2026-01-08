class TransactionRequest {
  String cashRegisterNo;
  String reqData;
  int trxnType;
  String terminalID;
  bool isDemoMode;
  String szSignature;

  TransactionRequest({
    required this.cashRegisterNo,
    required this.reqData,
    required this.trxnType,
    required this.terminalID,
    required this.isDemoMode,
    required this.szSignature,
  });

  factory TransactionRequest.fromJson(Map<String, dynamic> json) {
    return TransactionRequest(
      cashRegisterNo: json['cashRegisterNo'],
      reqData: json['reqData'],
      trxnType: json['trxnType'],
      terminalID: json['terminalID'],
      isDemoMode: json['isDemoMode'],
      szSignature: json['szSignature'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cashRegisterNo': cashRegisterNo,
      'reqData': reqData,
      'trxnType': trxnType,
      'terminalID': terminalID,
      'isDemoMode': isDemoMode,
      'szSignature': szSignature,
    };
  }
}
