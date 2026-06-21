import 'package:flutter_test/flutter_test.dart';
import 'package:shift_pos/features/orders/domain/order.dart';
import 'package:shift_pos/features/orders/domain/order_enums.dart';
import 'package:shift_pos/features/orders/domain/order_line.dart';
import 'package:shift_pos/features/orders/domain/order_pricing.dart';
import 'package:shift_pos/features/receipt/application/receipt_text_builder.dart';
import 'package:shift_pos/features/settings/domain/pos_settings.dart';

void main() {
  test('honors receipt section order, visibility, and compact mode', () {
    final text = const ReceiptTextBuilder().build(
      Order(
        id: 'order-1',
        orderNumber: 42,
        type: OrderType.takeaway,
        lines: const [
          OrderLine(
            menuItemId: 'item-1',
            nameAr: 'Kofta',
            unitPrice: 50,
            quantity: 2,
            noteAr: 'No onion',
          ),
        ],
        totals: const OrderTotals(
          subtotal: 100,
          discountAmount: 0,
          taxAmount: 14,
          serviceAmount: 0,
          deliveryFee: 0,
          total: 114,
        ),
        status: OrderStatus.paid,
        createdAt: DateTime.utc(2026, 6, 21),
        paymentMethod: PaymentMethod.cash,
        cashPaid: 114,
      ),
      const PosSettings(
        restaurantNameAr: 'SHIFT',
        currencySymbol: 'EGP',
        taxRate: 14,
        serviceRate: 0,
        deliveryFee: 0,
        receiptSectionOrder: [
          ReceiptSection.items,
          ReceiptSection.totals,
          ReceiptSection.restaurant,
          ReceiptSection.payment,
        ],
        receiptHiddenSections: {ReceiptSection.restaurant},
        receiptShowItemNotes: false,
        receiptCompactMode: true,
      ),
    );

    expect(text, startsWith('2.00 x Kofta'));
    expect(text, contains('-' * 24));
    expect(text, contains('TOTAL: 114.00 EGP'));
    expect(text, contains('Payment: Cash'));
    expect(text, isNot(contains('No onion')));
    expect(text, isNot(contains('SHIFT')));
  });
}
