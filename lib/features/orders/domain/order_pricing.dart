import 'order_enums.dart';
import 'order_line.dart';

class OrderPricingInput {
  const OrderPricingInput({
    required this.lines,
    required this.orderType,
    this.taxRate = 0,
    this.serviceRate = 0,
    this.deliveryFee = 0,
    this.discountType,
    this.discountValue = 0,
  });

  final List<OrderLine> lines;
  final OrderType orderType;
  final double taxRate;
  final double serviceRate;
  final double deliveryFee;
  final DiscountType? discountType;
  final double discountValue;
}

class OrderTotals {
  const OrderTotals({
    required this.subtotal,
    required this.discountAmount,
    required this.taxAmount,
    required this.serviceAmount,
    required this.deliveryFee,
    required this.total,
  });

  final double subtotal;
  final double discountAmount;
  final double taxAmount;
  final double serviceAmount;
  final double deliveryFee;
  final double total;
}
