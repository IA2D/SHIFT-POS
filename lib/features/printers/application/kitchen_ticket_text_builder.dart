import '../../orders/domain/order.dart';
import '../../orders/domain/order_line.dart';
import '../domain/kitchen_printer.dart';

class KitchenTicketTextBuilder {
  const KitchenTicketTextBuilder();

  String build(
    Order order,
    KitchenPrinter printer,
    List<OrderLine> lines,
  ) {
    final visibility = printer.visibility;
    return [
      printer.name,
      'ORDER #${order.orderNumber}',
      if (visibility.showOrderType) 'Type: ${order.type.name}',
      if (visibility.showTable && (order.tableNameAr ?? '').isNotEmpty)
        'Table: ${order.tableNameAr}',
      if (visibility.showCashier && (order.cashierName ?? '').isNotEmpty)
        'Cashier: ${order.cashierName}',
      if (visibility.showCustomer && (order.customerName ?? '').isNotEmpty)
        'Customer: ${order.customerName}',
      '-' * 32,
      ...lines.expand(
        (line) => [
          '${line.quantity.toStringAsFixed(2)} x ${line.nameAr}',
          if ((line.sizeLabelAr ?? '').isNotEmpty) '  ${line.sizeLabelAr}',
          if (visibility.showItemNotes && (line.noteAr ?? '').isNotEmpty)
            '  Note: ${line.noteAr}',
        ],
      ),
      if (visibility.showOrderNote && (order.noteAr ?? '').isNotEmpty) ...[
        '-' * 32,
        'ORDER NOTE: ${order.noteAr}',
      ],
      '-' * 32,
      '${order.createdAt}',
    ].join('\r\n');
  }
}
