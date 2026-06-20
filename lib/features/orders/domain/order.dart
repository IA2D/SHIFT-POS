import 'order_enums.dart';
import 'order_line.dart';
import 'order_pricing.dart';

class Order {
  const Order({
    required this.id,
    required this.orderNumber,
    required this.type,
    required this.lines,
    required this.totals,
    required this.status,
    required this.createdAt,
    this.tableId,
    this.tableNameAr,
    this.noteAr,
    this.paidAt,
    this.paymentMethod,
  });

  final String id;
  final int orderNumber;
  final OrderType type;
  final List<OrderLine> lines;
  final OrderTotals totals;
  final OrderStatus status;
  final DateTime createdAt;
  final String? tableId;
  final String? tableNameAr;
  final String? noteAr;
  final DateTime? paidAt;
  final PaymentMethod? paymentMethod;

  bool get isUnpaidDineIn {
    return type == OrderType.dineIn && status == OrderStatus.unpaid;
  }

  Order markPaid({
    required PaymentMethod method,
    required DateTime paidAt,
  }) {
    return Order(
      id: id,
      orderNumber: orderNumber,
      type: type,
      lines: lines,
      totals: totals,
      status: OrderStatus.paid,
      createdAt: createdAt,
      tableId: tableId,
      tableNameAr: tableNameAr,
      noteAr: noteAr,
      paidAt: paidAt,
      paymentMethod: method,
    );
  }
}

enum OrderStatus {
  unpaid,
  paid,
  cancelled,
}
