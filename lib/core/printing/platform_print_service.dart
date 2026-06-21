import 'dart:io';

class PrintResult {
  const PrintResult({required this.ok, this.error});

  final bool ok;
  final String? error;
}

class PlatformPrintService {
  const PlatformPrintService();

  Future<PrintResult> printText(
    String text, {
    String? printerName,
    int copies = 1,
  }) async {
    if (!Platform.isWindows) {
      return const PrintResult(
        ok: false,
        error: 'Direct printing is currently available on Windows only.',
      );
    }

    final temporary = File(
      '${Directory.systemTemp.path}\\shift-pos-print-${DateTime.now().microsecondsSinceEpoch}.txt',
    );
    try {
      await temporary.writeAsString(text);
      for (var copy = 0; copy < copies.clamp(1, 5); copy++) {
        final hasPrinter = printerName != null && printerName.trim().isNotEmpty;
        final script = hasPrinter
            ? r'Get-Content -Encoding UTF8 -LiteralPath $args[0] | Out-Printer -Name $args[1]'
            : r'Get-Content -Encoding UTF8 -LiteralPath $args[0] | Out-Printer';
        final result = await Process.run(
          'powershell.exe',
          [
            '-NoProfile',
            '-NonInteractive',
            '-Command',
            script,
            temporary.path,
            if (hasPrinter) printerName.trim(),
          ],
        );
        if (result.exitCode != 0) {
          return PrintResult(ok: false, error: '${result.stderr}'.trim());
        }
      }
      return const PrintResult(ok: true);
    } on Object catch (error) {
      return PrintResult(ok: false, error: '$error');
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }
}
