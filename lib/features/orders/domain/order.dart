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
    this.discountType,
    this.discountValue,
    this.cashPaid,
    this.cardPaid,
    this.cashReceived,
    this.changeDue,
    this.customerName,
    this.customerPhone,
    this.customerAddress,
    this.cashierId,
    this.cashierName,
    this.shiftId,
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
  final DiscountType? discountType;
  final double? discountValue;
  final double? cashPaid;
  final double? cardPaid;
  final double? cashReceived;
  final double? changeDue;
  final String? customerName;
  final String? customerPhone;
  final String? customerAddress;
  final String? cashierId;
  final String? cashierName;
  final String? shiftId;

  bool get isUnpaidDineIn {
    return type == OrderType.dineIn && status == OrderStatus.unpaid;
  }

  Order markPaid({
    required PaymentMethod method,
    required DateTime paidAt,
    double? cashPaid,
    double? cardPaid,
    double? cashReceived,
    double? changeDue,
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
      discountType: discountType,
      discountValue: discountValue,
      cashPaid: cashPaid ?? this.cashPaid,
      cardPaid: cardPaid ?? this.cardPaid,
      cashReceived: cashReceived ?? this.cashReceived,
      changeDue: changeDue ?? this.changeDue,
      customerName: customerName,
      customerPhone: customerPhone,
      customerAddress: customerAddress,
      cashierId: cashierId,
      cashierName: cashierName,
      shiftId: shiftId,
    );
  }

  Order cancel() {
    return Order(
      id: id,
      orderNumber: orderNumber,
      type: type,
      lines: lines,
      totals: totals,
      status: OrderStatus.cancelled,
      createdAt: createdAt,
      tableId: tableId,
      tableNameAr: tableNameAr,
      noteAr: noteAr,
      paidAt: paidAt,
      paymentMethod: paymentMethod,
      discountType: discountType,
      discountValue: discountValue,
      cashPaid: cashPaid,
      cardPaid: cardPaid,
      cashReceived: cashReceived,
      changeDue: changeDue,
      customerName: customerName,
      customerPhone: customerPhone,
      customerAddress: customerAddress,
      cashierId: cashierId,
      cashierName: cashierName,
      shiftId: shiftId,
    );
  }
}

enum OrderStatus {
  unpaid,
  paid,
  cancelled,
}
