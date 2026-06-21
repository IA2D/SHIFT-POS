class KitchenPrinter {
  const KitchenPrinter({
    required this.id,
    required this.name,
    required this.deviceName,
    this.description,
    this.copies = 1,
    this.active = true,
    this.visibility = const KitchenPrinterVisibility(),
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String deviceName;
  final String? description;
  final int copies;
  final bool active;
  final KitchenPrinterVisibility visibility;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  KitchenPrinter copyWith({
    String? name,
    String? deviceName,
    String? description,
    int? copies,
    bool? active,
    KitchenPrinterVisibility? visibility,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return KitchenPrinter(
      id: id,
      name: name ?? this.name,
      deviceName: deviceName ?? this.deviceName,
      description: description ?? this.description,
      copies: copies ?? this.copies,
      active: active ?? this.active,
      visibility: visibility ?? this.visibility,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class KitchenPrinterVisibility {
  const KitchenPrinterVisibility({
    this.showOrderType = true,
    this.showTable = true,
    this.showCashier = true,
    this.showCustomer = true,
    this.showOrderNote = true,
    this.showItemNotes = true,
  });

  final bool showOrderType;
  final bool showTable;
  final bool showCashier;
  final bool showCustomer;
  final bool showOrderNote;
  final bool showItemNotes;

  KitchenPrinterVisibility copyWith({
    bool? showOrderType,
    bool? showTable,
    bool? showCashier,
    bool? showCustomer,
    bool? showOrderNote,
    bool? showItemNotes,
  }) {
    return KitchenPrinterVisibility(
      showOrderType: showOrderType ?? this.showOrderType,
      showTable: showTable ?? this.showTable,
      showCashier: showCashier ?? this.showCashier,
      showCustomer: showCustomer ?? this.showCustomer,
      showOrderNote: showOrderNote ?? this.showOrderNote,
      showItemNotes: showItemNotes ?? this.showItemNotes,
    );
  }
}

class SystemPrinter {
  const SystemPrinter({
    required this.name,
    required this.displayName,
    this.description,
    this.isDefault = false,
  });

  final String name;
  final String displayName;
  final String? description;
  final bool isDefault;
}
