import 'package:flutter_test/flutter_test.dart';
import 'package:shift_pos/features/orders/domain/order.dart';
import 'package:shift_pos/features/orders/domain/order_enums.dart';
import 'package:shift_pos/features/orders/domain/order_line.dart';
import 'package:shift_pos/features/orders/domain/order_pricing.dart';
import 'package:shift_pos/features/printers/application/kitchen_ticket_text_builder.dart';
import 'package:shift_pos/features/printers/domain/kitchen_printer.dart';

void main() {
  test('honors kitchen ticket visibility flags', () {
    final text = const KitchenTicketTextBuilder().build(
      Order(
        id: '1',
        orderNumber: 7,
        type: OrderType.dineIn,
        lines: const [],
        totals: const OrderTotals(
          subtotal: 10,
          discountAmount: 0,
          taxAmount: 0,
          serviceAmount: 0,
          deliveryFee: 0,
          total: 10,
        ),
        status: OrderStatus.unpaid,
        createdAt: DateTime.utc(2026, 6, 21),
        tableNameAr: 'Table 2',
        cashierName: 'Ahmed',
        noteAr: 'Fast',
      ),
      const KitchenPrinter(
        id: 'grill',
        name: 'Grill',
        deviceName: 'Printer',
        visibility: KitchenPrinterVisibility(
          showTable: false,
          showCashier: false,
          showOrderNote: true,
          showItemNotes: false,
        ),
      ),
      const [
        OrderLine(
          menuItemId: 'kofta',
          nameAr: 'Kofta',
          unitPrice: 10,
          quantity: 1,
          noteAr: 'No onion',
        ),
      ],
    );

    expect(text, contains('ORDER #7'));
    expect(text, contains('1.00 x Kofta'));
    expect(text, contains('ORDER NOTE: Fast'));
    expect(text, isNot(contains('Table 2')));
    expect(text, isNot(contains('Ahmed')));
    expect(text, isNot(contains('No onion')));
  });
}
