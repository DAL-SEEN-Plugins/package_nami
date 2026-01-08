class HealthCheckResponse {
  final String cashRegisterNumber;
  final String terminalId;
  final String terminalSlNo;
  final int trxnType;
  final bool isDemoMode;
  final bool isPayAppActive;
  final int pType;

  HealthCheckResponse({
    required this.cashRegisterNumber,
    required this.terminalId,
    required this.terminalSlNo,
    required this.trxnType,
    required this.isDemoMode,
    required this.isPayAppActive,
    required this.pType,
  });

  factory HealthCheckResponse.fromJson(Map<String, dynamic> json) {
    return HealthCheckResponse(
      cashRegisterNumber: json["cashRegisterNumber"],
      terminalId: json["terminalId"],
      terminalSlNo: json["terminalSlNo"],
      trxnType: json["trxnType"],
      isDemoMode: json["isDemoMode"],
      isPayAppActive: json["isPayAppActive"],
      pType: json["pType"],
    );
  }
}
