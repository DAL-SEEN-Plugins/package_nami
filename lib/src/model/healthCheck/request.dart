class HealthCheckRequest {
  final String cashRegisterNumber;
  final String terminalId;
  final String terminalSlno;
  final int trxnType;
  final bool isDemoMode;

  HealthCheckRequest({
    required this.cashRegisterNumber,
    required this.terminalId,
    required this.terminalSlno,
    required this.trxnType,
    required this.isDemoMode,
  });

  Map<String, dynamic> toJson() => {
    "cashRegisterNumber": cashRegisterNumber,
    "terminalId": terminalId,
    "terminalSlno": terminalSlno,
    "trxnType": trxnType,
    "isDemoMode": isDemoMode,
  };
}
