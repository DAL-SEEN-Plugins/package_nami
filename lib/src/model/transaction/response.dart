import 'dart:convert';

class TransactionResponse {
  final String responseBody;
  final String cashRegisterNumber;
  final bool isDemoMode;
  final int pType;
  final int trxnType;

  TransactionResponse({
    required this.responseBody,
    required this.cashRegisterNumber,
    required this.isDemoMode,
    required this.pType,
    required this.trxnType,
  });

  // Factory constructor to create an instance from a JSON map
  factory TransactionResponse.fromJson(Map<String, dynamic> json) {
    return TransactionResponse(
      responseBody: json['responseBody'] as String,
      cashRegisterNumber: json['cashRegisterNumber'] as String,
      isDemoMode: json['isDemoMode'] as bool,
      pType: json['pType'] as int,
      trxnType: json['trxnType'] as int,
    );
  }

  // Method to convert the instance into a JSON map
  Map<String, dynamic> toJson() {
    return {
      'responseBody': responseBody,
      'cashRegisterNumber': cashRegisterNumber,
      'isDemoMode': isDemoMode,
      'pType': pType,
      'trxnType': trxnType,
    };
  }

  // Convert JSON string to TransactionResponse object
  static TransactionResponse fromJsonString(String jsonString) {
    return TransactionResponse.fromJson(json.decode(jsonString));
  }

  // Convert TransactionResponse object to JSON string
  String toJsonString() {
    return json.encode(toJson());
  }
}
