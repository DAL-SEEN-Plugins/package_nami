class RegisterResponse {
  final String terminalSlNo;
  final String terminalId;
  final String cashRegisterNumber;
  final bool? isDemoMode;
  final int? pType;
  final int trxnType;

  RegisterResponse({
    required this.terminalSlNo,
    required this.terminalId,
    required this.cashRegisterNumber,
    required this.isDemoMode,
    required this.pType,
    required this.trxnType,
  });

  // Factory constructor to create a RegisterResponse object from JSON
  factory RegisterResponse.fromJson(Map<String, dynamic> json) {
    return RegisterResponse(
      terminalSlNo: json['terminalSlNo'] ?? '',
      terminalId: json['terminalId'] ?? '',
      cashRegisterNumber: json['cashRegisterNumber'] ?? '',
      isDemoMode: json['isDemoMode'] ?? false,
      pType: json['pType'] ?? 0,
      trxnType: json['trxnType'] ?? 0,
    );
  }

  // Method to convert RegisterResponse object to JSON
  Map<String, dynamic> toJson() {
    return {
      'terminalSlNo': terminalSlNo,
      'terminalId': terminalId,
      'cashRegisterNumber': cashRegisterNumber,
      'isDemoMode': isDemoMode,
      'pType': pType,
      'trxnType': trxnType,
    };
  }
}
