class PosSettings {
  const PosSettings({
    required this.restaurantNameAr,
    required this.currencySymbol,
    required this.taxRate,
    required this.serviceRate,
    required this.deliveryFee,
    this.phoneNumber,
    this.receiptFooterAr,
    this.primaryColor = '#008C95',
    this.pinEnabled = false,
    this.autoLockMinutes = 5,
    this.maxCashierDiscountPct,
    this.keyboardShortcuts = const {
      'newOrder': 'ctrl+n',
      'checkoutCash': 'f2',
      'checkoutCard': 'f3',
      'holdOrder': 'f4',
      'focusSearch': 'ctrl+f',
      'openManager': 'ctrl+m',
      'logout': 'ctrl+shift+l',
    },
    this.networkMode = NetworkMode.standalone,
    this.masterServerPort = 47831,
    this.receiptPrintRoute = ReceiptPrintRoute.side,
    this.receiptSectionOrder = ReceiptSection.values,
    this.receiptHiddenSections = const {},
    this.receiptShowItemNotes = true,
    this.receiptCompactMode = false,
    this.receiptLogoEnabled = false,
    this.receiptLogoDataUrl,
    this.receiptLogoMode = ReceiptLogoMode.image,
    this.receiptLogoThreshold = 176,
    this.receiptLogoWidth = 96,
    this.receiptLogoInvert = false,
    this.receiptLogoAlign = ReceiptLogoAlign.center,
    this.receiptLogoMaxWidthPercent = 100,
    this.defaultReceiptPrinter,
    this.defaultReportPrinter,
    this.backupDirectory,
    this.backupDirectories = const [],
    this.autoBackupEnabled = false,
    this.autoBackupIntervalDays = 1,
    this.autoBackupOnClose = false,
    this.backupRetentionDays = 7,
    this.lastAutoBackupAt,
  });

  final String restaurantNameAr;
  final String currencySymbol;
  final double taxRate;
  final double serviceRate;
  final double deliveryFee;
  final String? phoneNumber;
  final String? receiptFooterAr;
  final String primaryColor;
  final bool pinEnabled;
  final int autoLockMinutes;
  final double? maxCashierDiscountPct;
  final Map<String, String> keyboardShortcuts;
  final NetworkMode networkMode;
  final int masterServerPort;
  final ReceiptPrintRoute receiptPrintRoute;
  final List<ReceiptSection> receiptSectionOrder;
  final Set<ReceiptSection> receiptHiddenSections;
  final bool receiptShowItemNotes;
  final bool receiptCompactMode;
  final bool receiptLogoEnabled;
  final String? receiptLogoDataUrl;
  final ReceiptLogoMode receiptLogoMode;
  final int receiptLogoThreshold;
  final int receiptLogoWidth;
  final bool receiptLogoInvert;
  final ReceiptLogoAlign receiptLogoAlign;
  final int receiptLogoMaxWidthPercent;
  final String? defaultReceiptPrinter;
  final String? defaultReportPrinter;
  final String? backupDirectory;
  final List<String> backupDirectories;
  final bool autoBackupEnabled;
  final int autoBackupIntervalDays;
  final bool autoBackupOnClose;
  final int backupRetentionDays;
  final DateTime? lastAutoBackupAt;

  PosSettings copyWith({
    String? restaurantNameAr,
    String? currencySymbol,
    double? taxRate,
    double? serviceRate,
    double? deliveryFee,
    String? phoneNumber,
    String? receiptFooterAr,
    String? primaryColor,
    bool? pinEnabled,
    int? autoLockMinutes,
    double? maxCashierDiscountPct,
    Map<String, String>? keyboardShortcuts,
    NetworkMode? networkMode,
    int? masterServerPort,
    ReceiptPrintRoute? receiptPrintRoute,
    List<ReceiptSection>? receiptSectionOrder,
    Set<ReceiptSection>? receiptHiddenSections,
    bool? receiptShowItemNotes,
    bool? receiptCompactMode,
    bool? receiptLogoEnabled,
    String? receiptLogoDataUrl,
    ReceiptLogoMode? receiptLogoMode,
    int? receiptLogoThreshold,
    int? receiptLogoWidth,
    bool? receiptLogoInvert,
    ReceiptLogoAlign? receiptLogoAlign,
    int? receiptLogoMaxWidthPercent,
    String? defaultReceiptPrinter,
    String? defaultReportPrinter,
    String? backupDirectory,
    List<String>? backupDirectories,
    bool? autoBackupEnabled,
    int? autoBackupIntervalDays,
    bool? autoBackupOnClose,
    int? backupRetentionDays,
    DateTime? lastAutoBackupAt,
  }) {
    return PosSettings(
      restaurantNameAr: restaurantNameAr ?? this.restaurantNameAr,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      taxRate: taxRate ?? this.taxRate,
      serviceRate: serviceRate ?? this.serviceRate,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      receiptFooterAr: receiptFooterAr ?? this.receiptFooterAr,
      primaryColor: primaryColor ?? this.primaryColor,
      pinEnabled: pinEnabled ?? this.pinEnabled,
      autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
      maxCashierDiscountPct:
          maxCashierDiscountPct ?? this.maxCashierDiscountPct,
      keyboardShortcuts: keyboardShortcuts ?? this.keyboardShortcuts,
      networkMode: networkMode ?? this.networkMode,
      masterServerPort: masterServerPort ?? this.masterServerPort,
      receiptPrintRoute: receiptPrintRoute ?? this.receiptPrintRoute,
      receiptSectionOrder: receiptSectionOrder ?? this.receiptSectionOrder,
      receiptHiddenSections:
          receiptHiddenSections ?? this.receiptHiddenSections,
      receiptShowItemNotes: receiptShowItemNotes ?? this.receiptShowItemNotes,
      receiptCompactMode: receiptCompactMode ?? this.receiptCompactMode,
      receiptLogoEnabled: receiptLogoEnabled ?? this.receiptLogoEnabled,
      receiptLogoDataUrl: receiptLogoDataUrl ?? this.receiptLogoDataUrl,
      receiptLogoMode: receiptLogoMode ?? this.receiptLogoMode,
      receiptLogoThreshold: receiptLogoThreshold ?? this.receiptLogoThreshold,
      receiptLogoWidth: receiptLogoWidth ?? this.receiptLogoWidth,
      receiptLogoInvert: receiptLogoInvert ?? this.receiptLogoInvert,
      receiptLogoAlign: receiptLogoAlign ?? this.receiptLogoAlign,
      receiptLogoMaxWidthPercent:
          receiptLogoMaxWidthPercent ?? this.receiptLogoMaxWidthPercent,
      defaultReceiptPrinter:
          defaultReceiptPrinter ?? this.defaultReceiptPrinter,
      defaultReportPrinter: defaultReportPrinter ?? this.defaultReportPrinter,
      backupDirectory: backupDirectory ?? this.backupDirectory,
      backupDirectories: backupDirectories ?? this.backupDirectories,
      autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
      autoBackupIntervalDays:
          autoBackupIntervalDays ?? this.autoBackupIntervalDays,
      autoBackupOnClose: autoBackupOnClose ?? this.autoBackupOnClose,
      backupRetentionDays: backupRetentionDays ?? this.backupRetentionDays,
      lastAutoBackupAt: lastAutoBackupAt ?? this.lastAutoBackupAt,
    );
  }
}

enum NetworkMode { standalone, master, side }

enum ReceiptPrintRoute { side, master }

enum ReceiptSection {
  logo,
  restaurant,
  orderMeta,
  customer,
  items,
  totals,
  payment,
  footer,
}

enum ReceiptLogoMode { image, monochrome, ascii }

enum ReceiptLogoAlign { left, center, right }
