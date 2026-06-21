import '../../orders/domain/order.dart';
import '../../orders/domain/order_enums.dart';
import '../../settings/domain/pos_settings.dart';

class ReceiptTextBuilder {
  const ReceiptTextBuilder();

  String build(Order order, PosSettings settings) {
    final sections = <ReceiptSection, List<String>>{
      ReceiptSection.logo: const [],
      ReceiptSection.restaurant: [
        settings.restaurantNameAr,
        if ((settings.phoneNumber ?? '').isNotEmpty) settings.phoneNumber!,
      ],
      ReceiptSection.orderMeta: [
        'Order #${order.orderNumber}',
        '${order.createdAt}',
        'Type: ${order.type.name}',
        if ((order.tableNameAr ?? '').isNotEmpty) 'Table: ${order.tableNameAr}',
        if ((order.cashierName ?? '').isNotEmpty)
          'Cashier: ${order.cashierName}',
      ],
      ReceiptSection.customer: [
        if ((order.customerName ?? '').isNotEmpty)
          'Customer: ${order.customerName}',
        if ((order.customerPhone ?? '').isNotEmpty)
          'Phone: ${order.customerPhone}',
        if ((order.customerAddress ?? '').isNotEmpty)
          'Address: ${order.customerAddress}',
      ],
      ReceiptSection.items: [
        ...order.lines.expand(
          (line) => [
            '${line.quantity.toStringAsFixed(2)} x ${line.nameAr}  ${line.total.toStringAsFixed(2)}',
            if ((line.sizeLabelAr ?? '').isNotEmpty) '  ${line.sizeLabelAr}',
            if (settings.receiptShowItemNotes && (line.noteAr ?? '').isNotEmpty)
              '  ${line.noteAr}',
          ],
        ),
        if ((order.noteAr ?? '').isNotEmpty) 'Note: ${order.noteAr}',
      ],
      ReceiptSection.totals: [
        'Subtotal: ${order.totals.subtotal.toStringAsFixed(2)} ${settings.currencySymbol}',
        if (order.totals.discountAmount > 0)
          'Discount: -${order.totals.discountAmount.toStringAsFixed(2)}',
        if (order.totals.taxAmount > 0)
          'Tax: ${order.totals.taxAmount.toStringAsFixed(2)}',
        if (order.totals.serviceAmount > 0)
          'Service: ${order.totals.serviceAmount.toStringAsFixed(2)}',
        if (order.totals.deliveryFee > 0)
          'Delivery: ${order.totals.deliveryFee.toStringAsFixed(2)}',
        'TOTAL: ${order.totals.total.toStringAsFixed(2)} ${settings.currencySymbol}',
      ],
      ReceiptSection.payment: [
        'Status: ${order.status.name}',
        if (order.paymentMethod != null)
          'Payment: ${_paymentLabel(order.paymentMethod!)}',
        if ((order.cashPaid ?? 0) > 0)
          'Cash: ${order.cashPaid!.toStringAsFixed(2)}',
        if ((order.cardPaid ?? 0) > 0)
          'Card: ${order.cardPaid!.toStringAsFixed(2)}',
        if ((order.changeDue ?? 0) > 0)
          'Change: ${order.changeDue!.toStringAsFixed(2)}',
      ],
      ReceiptSection.footer: [
        if ((settings.receiptFooterAr ?? '').isNotEmpty)
          settings.receiptFooterAr!,
      ],
    };
    final divider = settings.receiptCompactMode ? '-' * 24 : '-' * 40;
    final output = <String>[];
    for (final section in settings.receiptSectionOrder) {
      if (settings.receiptHiddenSections.contains(section)) continue;
      final lines = sections[section] ?? const [];
      if (lines.isEmpty) continue;
      if (output.isNotEmpty) output.add(divider);
      output.addAll(lines);
    }
    return output.join('\r\n');
  }

  String _paymentLabel(PaymentMethod method) => switch (method) {
        PaymentMethod.cash => 'Cash',
        PaymentMethod.card => 'Card',
        PaymentMethod.split => 'Split',
      };
}
