import '../../../shared/domain/money.dart';

class OrderLine {
  const OrderLine({
    required this.menuItemId,
    required this.nameAr,
    required this.unitPrice,
    required this.quantity,
    this.sizeLabelAr,
    this.unitLabel,
    this.noteAr,
  });

  final String menuItemId;
  final String nameAr;
  final double unitPrice;
  final double quantity;
  final String? sizeLabelAr;
  final String? unitLabel;
  final String? noteAr;

  double get total => Money.round(unitPrice * quantity);
}
