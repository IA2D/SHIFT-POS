import '../../menu/domain/menu_item.dart';
import '../../orders/domain/order_line.dart';

class CartLine {
  const CartLine({
    required this.menuItemId,
    required this.nameAr,
    required this.unitPrice,
    required this.quantity,
  });

  factory CartLine.fromMenuItem(MenuItem item) {
    return CartLine(
      menuItemId: item.id,
      nameAr: item.nameAr,
      unitPrice: item.price,
      quantity: 1,
    );
  }

  final String menuItemId;
  final String nameAr;
  final double unitPrice;
  final double quantity;

  CartLine copyWith({
    double? quantity,
  }) {
    return CartLine(
      menuItemId: menuItemId,
      nameAr: nameAr,
      unitPrice: unitPrice,
      quantity: quantity ?? this.quantity,
    );
  }

  OrderLine toOrderLine() {
    return OrderLine(
      menuItemId: menuItemId,
      nameAr: nameAr,
      unitPrice: unitPrice,
      quantity: quantity,
    );
  }
}
