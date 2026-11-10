class PaymentSettings {
  const PaymentSettings({
    required this.mPesaNumber,
    required this.bankAccount,
    required this.bankName,
    required this.invoicePrefix,
    required this.taxRate,
    required this.vat,
  });

  final String? mPesaNumber;
  final String? bankAccount;
  final String? bankName;
  final String? invoicePrefix;
  final double taxRate; // percentage, e.g., 16.0 for 16%
  final double vat; // percentage

  PaymentSettings copyWith({
    String? mPesaNumber,
    String? bankAccount,
    String? bankName,
    String? invoicePrefix,
    double? taxRate,
    double? vat,
  }) => PaymentSettings(
    mPesaNumber: mPesaNumber ?? this.mPesaNumber,
    bankAccount: bankAccount ?? this.bankAccount,
    bankName: bankName ?? this.bankName,
    invoicePrefix: invoicePrefix ?? this.invoicePrefix,
    taxRate: taxRate ?? this.taxRate,
    vat: vat ?? this.vat,
  );

  Map<String, dynamic> toJson() => {
    'mPesaNumber': mPesaNumber,
    'bankAccount': bankAccount,
    'bankName': bankName,
    'invoicePrefix': invoicePrefix,
    'taxRate': taxRate,
    'vat': vat,
  };

  factory PaymentSettings.fromJson(Map<String, dynamic> json) =>
      PaymentSettings(
        mPesaNumber: json['mPesaNumber'] as String?,
        bankAccount: json['bankAccount'] as String?,
        bankName: json['bankName'] as String?,
        invoicePrefix: json['invoicePrefix'] as String?,
        taxRate: (json['taxRate'] as num?)?.toDouble() ?? 0.0,
        vat: (json['vat'] as num?)?.toDouble() ?? 0.0,
      );

  factory PaymentSettings.defaults() => const PaymentSettings(
    mPesaNumber: null,
    bankAccount: null,
    bankName: null,
    invoicePrefix: 'INV',
    taxRate: 0.0,
    vat: 0.0,
  );
}
