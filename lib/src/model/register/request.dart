class RegisterRequest {
  final String cashRegisterNumber;
  final int trxnType;

  RegisterRequest({required this.cashRegisterNumber, required this.trxnType});

  Map<String, dynamic> toJson() {
    return {'cashRegisterNumber': cashRegisterNumber, 'trxnType': trxnType};
  }

  factory RegisterRequest.fromJson(Map<String, dynamic> json) {
    return RegisterRequest(
      cashRegisterNumber: json['cashRegisterNumber'],
      trxnType: json['trxnType'],
    );
  }
}
