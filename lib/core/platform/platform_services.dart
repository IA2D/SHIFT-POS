abstract interface class PlatformServices {
  Future<String> deviceId();

  Future<void> restartApp();

  Future<PrintResult> printReceipt(String document);

  Future<List<PrinterInfo>> listPrinters();
}

class PrintResult {
  const PrintResult({
    required this.ok,
    this.error,
  });

  final bool ok;
  final String? error;
}

class PrinterInfo {
  const PrinterInfo({
    required this.id,
    required this.name,
    this.isDefault = false,
  });

  final String id;
  final String name;
  final bool isDefault;
}
