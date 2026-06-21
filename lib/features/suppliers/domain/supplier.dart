class Supplier {
  const Supplier({
    required this.id,
    required this.nameAr,
    this.phone,
    this.noteAr,
    this.active = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String nameAr;
  final String? phone;
  final String? noteAr;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Supplier copyWith({
    String? id,
    String? nameAr,
    String? phone,
    String? noteAr,
    bool? active,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Supplier(
      id: id ?? this.id,
      nameAr: nameAr ?? this.nameAr,
      phone: phone ?? this.phone,
      noteAr: noteAr ?? this.noteAr,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
