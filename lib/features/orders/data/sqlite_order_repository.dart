import '../../../core/database/database_gateway.dart';
import '../../../core/database/database_tables.dart';
import '../domain/order.dart';
import '../domain/order_enums.dart';
import '../domain/order_line.dart';
import '../domain/order_pricing.dart';
import '../domain/order_repository.dart';

class SqliteOrderRepository implements OrderRepository {
  SqliteOrderRepository(this._database);

  final DatabaseGateway _database;
  int _nextOrderNumber = 1;

  Future<void> initialize() async {
    final orders = await listOrders();
    for (final order in orders) {
      if (order.orderNumber >= _nextOrderNumber) {
        _nextOrderNumber = order.orderNumber + 1;
      }
    }
  }

  @override
  Future<Order> save(Order order) async {
    await _database.save(DatabaseTables.orders, order.id, _toRow(order));
    if (order.orderNumber >= _nextOrderNumber) {
      _nextOrderNumber = order.orderNumber + 1;
    }
    return order;
  }

  @override
  Future<Order?> getById(String id) async {
    final rows = await _database.query(
      DatabaseTables.orders,
      filters: {'id': id},
    );
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  @override
  Future<List<Order>> listOrders() async {
    final orders =
        (await _database.query(DatabaseTables.orders)).map(_fromRow).toList();
    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return orders;
  }

  @override
  Future<List<Order>> listUnpaidDineInOrders() async {
    return (await listOrders())
        .where((order) => order.isUnpaidDineIn)
        .toList(growable: false);
  }

  @override
  Future<int> nextOrderNumber() async => _nextOrderNumber++;

  Map<String, Object?> _toRow(Order order) => {
        'orderNumber': order.orderNumber,
        'type': order.type.name,
        'lines': order.lines
            .map(
              (line) => {
                'menuItemId': line.menuItemId,
                'nameAr': line.nameAr,
                'unitPrice': line.unitPrice,
                'quantity': line.quantity,
                'sizeLabelAr': line.sizeLabelAr,
                'unitLabel': line.unitLabel,
                'noteAr': line.noteAr,
              },
            )
            .toList(),
        'totals': {
          'subtotal': order.totals.subtotal,
          'discountAmount': order.totals.discountAmount,
          'taxAmount': order.totals.taxAmount,
          'serviceAmount': order.totals.serviceAmount,
          'deliveryFee': order.totals.deliveryFee,
          'total': order.totals.total,
        },
        'status': order.status.name,
        'createdAt': order.createdAt.toIso8601String(),
        'tableId': order.tableId,
        'tableNameAr': order.tableNameAr,
        'noteAr': order.noteAr,
        'paidAt': order.paidAt?.toIso8601String(),
        'paymentMethod': order.paymentMethod?.name,
        'discountType': order.discountType?.name,
        'discountValue': order.discountValue,
        'cashPaid': order.cashPaid,
        'cardPaid': order.cardPaid,
        'cashReceived': order.cashReceived,
        'changeDue': order.changeDue,
        'customerName': order.customerName,
        'customerPhone': order.customerPhone,
        'customerAddress': order.customerAddress,
        'cashierId': order.cashierId,
        'cashierName': order.cashierName,
        'shiftId': order.shiftId,
      };

  Order _fromRow(Map<String, Object?> row) {
    final totals = Map<String, Object?>.from(row['totals']! as Map);
    final paymentMethod = row['paymentMethod'] as String?;
    final discountType = row['discountType'] as String?;
    return Order(
      id: row['id']! as String,
      orderNumber: row['orderNumber']! as int,
      type: OrderType.values.byName(row['type']! as String),
      lines: (row['lines']! as List<Object?>)
          .map((value) => Map<String, Object?>.from(value! as Map))
          .map(
            (line) => OrderLine(
              menuItemId: line['menuItemId']! as String,
              nameAr: line['nameAr']! as String,
              unitPrice: (line['unitPrice']! as num).toDouble(),
              quantity: (line['quantity']! as num).toDouble(),
              sizeLabelAr: line['sizeLabelAr'] as String?,
              unitLabel: line['unitLabel'] as String?,
              noteAr: line['noteAr'] as String?,
            ),
          )
          .toList(),
      totals: OrderTotals(
        subtotal: (totals['subtotal']! as num).toDouble(),
        discountAmount: (totals['discountAmount']! as num).toDouble(),
        taxAmount: (totals['taxAmount']! as num).toDouble(),
        serviceAmount: (totals['serviceAmount']! as num).toDouble(),
        deliveryFee: (totals['deliveryFee']! as num).toDouble(),
        total: (totals['total']! as num).toDouble(),
      ),
      status: OrderStatus.values.byName(row['status']! as String),
      createdAt: DateTime.parse(row['createdAt']! as String),
      tableId: row['tableId'] as String?,
      tableNameAr: row['tableNameAr'] as String?,
      noteAr: row['noteAr'] as String?,
      paidAt: _date(row['paidAt']),
      paymentMethod: paymentMethod == null
          ? null
          : PaymentMethod.values.byName(paymentMethod),
      discountType: discountType == null
          ? null
          : DiscountType.values.byName(discountType),
      discountValue: (row['discountValue'] as num?)?.toDouble(),
      cashPaid: (row['cashPaid'] as num?)?.toDouble(),
      cardPaid: (row['cardPaid'] as num?)?.toDouble(),
      cashReceived: (row['cashReceived'] as num?)?.toDouble(),
      changeDue: (row['changeDue'] as num?)?.toDouble(),
      customerName: row['customerName'] as String?,
      customerPhone: row['customerPhone'] as String?,
      customerAddress: row['customerAddress'] as String?,
      cashierId: row['cashierId'] as String?,
      cashierName: row['cashierName'] as String?,
      shiftId: row['shiftId'] as String?,
    );
  }

  DateTime? _date(Object? value) =>
      value is String ? DateTime.parse(value) : null;
}
