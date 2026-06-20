import '../../../shared/domain/money.dart';
import '../domain/order_enums.dart';
import '../domain/order_pricing.dart';

class OrderPricingService {
  const OrderPricingService();

  OrderTotals calculate(OrderPricingInput input) {
    final subtotal = Money.round(
      input.lines.fold<double>(0, (sum, line) => sum + line.total),
    );
    final discount = _discountAmount(
      subtotal: subtotal,
      type: input.discountType,
      value: input.discountValue,
    );
    final taxableBase = Money.round(subtotal - discount);
    final tax = Money.round(taxableBase * (input.taxRate / 100));
    final service = Money.round(taxableBase * (input.serviceRate / 100));
    final delivery = input.orderType == OrderType.delivery
        ? Money.round(input.deliveryFee)
        : 0.0;
    final total = Money.round(taxableBase + tax + service + delivery);

    return OrderTotals(
      subtotal: subtotal,
      discountAmount: discount,
      taxAmount: tax,
      serviceAmount: service,
      deliveryFee: delivery,
      total: total,
    );
  }

  double _discountAmount({
    required double subtotal,
    required DiscountType? type,
    required double value,
  }) {
    if (type == null || value <= 0 || subtotal <= 0) return 0;

    final rawDiscount = switch (type) {
      DiscountType.amount => value,
      DiscountType.percent => subtotal * (value / 100),
    };

    return Money.round(rawDiscount.clamp(0, subtotal));
  }
}
