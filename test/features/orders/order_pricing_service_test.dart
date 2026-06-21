import 'package:flutter_test/flutter_test.dart';
import 'package:shift_pos/features/orders/application/order_pricing_service.dart';
import 'package:shift_pos/features/orders/domain/order_enums.dart';
import 'package:shift_pos/features/orders/domain/order_line.dart';
import 'package:shift_pos/features/orders/domain/order_pricing.dart';

void main() {
  const service = OrderPricingService();

  test('calculates subtotal, tax, service, and delivery for delivery orders',
      () {
    final totals = service.calculate(
      const OrderPricingInput(
        orderType: OrderType.delivery,
        taxRate: 14,
        serviceRate: 10,
        deliveryFee: 25,
        lines: [
          OrderLine(
              menuItemId: 'pizza',
              nameAr: 'بيتزا',
              unitPrice: 100,
              quantity: 2),
          OrderLine(
              menuItemId: 'cola', nameAr: 'كولا', unitPrice: 20, quantity: 1),
        ],
      ),
    );

    expect(totals.subtotal, 220);
    expect(totals.taxAmount, 30.8);
    expect(totals.serviceAmount, 22);
    expect(totals.deliveryFee, 25);
    expect(totals.total, 297.8);
  });

  test('applies percent discount before tax and service', () {
    final totals = service.calculate(
      const OrderPricingInput(
        orderType: OrderType.takeaway,
        taxRate: 10,
        serviceRate: 5,
        discountType: DiscountType.percent,
        discountValue: 20,
        lines: [
          OrderLine(
              menuItemId: 'grill',
              nameAr: 'مشويات',
              unitPrice: 200,
              quantity: 1),
        ],
      ),
    );

    expect(totals.subtotal, 200);
    expect(totals.discountAmount, 40);
    expect(totals.taxAmount, 16);
    expect(totals.serviceAmount, 8);
    expect(totals.deliveryFee, 0);
    expect(totals.total, 184);
  });

  test('caps amount discount at subtotal', () {
    final totals = service.calculate(
      const OrderPricingInput(
        orderType: OrderType.dineIn,
        discountType: DiscountType.amount,
        discountValue: 500,
        lines: [
          OrderLine(
              menuItemId: 'item', nameAr: 'صنف', unitPrice: 100, quantity: 1),
        ],
      ),
    );

    expect(totals.discountAmount, 100);
    expect(totals.total, 0);
  });
}
