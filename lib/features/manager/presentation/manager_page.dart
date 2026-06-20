import 'package:flutter/material.dart';

import '../../../app/app_state_scope.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/widgets/page_header.dart';
import '../../orders/domain/order.dart';
import '../application/manager_dashboard_service.dart';

class ManagerPage extends StatefulWidget {
  const ManagerPage({
    required this.config,
    super.key,
  });

  final AppConfig config;

  @override
  State<ManagerPage> createState() => _ManagerPageState();
}

class _ManagerPageState extends State<ManagerPage> {
  Future<ManagerDashboardSummary>? _summaryFuture;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_reload);
  }

  void _reload() {
    final service = ManagerDashboardService(
      orderRepository: AppStateScope.of(context).orderRepository,
    );
    setState(() {
      _summaryFuture = service.loadSummary();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: FutureBuilder<ManagerDashboardSummary>(
        future: _summaryFuture,
        builder: (context, snapshot) {
          final summary = snapshot.data;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'لوحة المدير',
                subtitle: 'ملخص مباشر من بيانات التشغيل الحالية.',
                trailing: IconButton(
                  tooltip: 'تحديث',
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                ),
              ),
              const SizedBox(height: 24),
              if (summary == null)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else ...[
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _MetricCard(title: 'كل الطلبات', value: summary.orderCount.toString()),
                    _MetricCard(title: 'طلبات مدفوعة', value: summary.paidOrderCount.toString()),
                    _MetricCard(title: 'صالة غير مدفوعة', value: summary.unpaidDineInCount.toString()),
                    _MetricCard(title: 'مبيعات مدفوعة', value: summary.salesTotal.toStringAsFixed(2)),
                  ],
                ),
                const SizedBox(height: 24),
                Text('آخر الطلبات', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Expanded(child: _RecentOrdersTable(orders: summary.recentOrders)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      height: 110,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 10),
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentOrdersTable extends StatelessWidget {
  const _RecentOrdersTable({required this.orders});

  final List<Order> orders;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const Center(child: Text('لا توجد طلبات بعد.'));
    }

    return SingleChildScrollView(
      child: DataTable(
        columns: const [
          DataColumn(label: Text('رقم')),
          DataColumn(label: Text('النوع')),
          DataColumn(label: Text('الحالة')),
          DataColumn(label: Text('الإجمالي')),
        ],
        rows: orders
            .map(
              (order) => DataRow(
                cells: [
                  DataCell(Text('#${order.orderNumber}')),
                  DataCell(Text(_orderTypeLabel(order))),
                  DataCell(Text(_orderStatusLabel(order))),
                  DataCell(Text(order.totals.total.toStringAsFixed(2))),
                ],
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  String _orderTypeLabel(Order order) {
    return switch (order.type) {
      final type when type.name == 'takeaway' => 'تيك أواي',
      final type when type.name == 'dineIn' => 'صالة',
      final type when type.name == 'delivery' => 'دليفري',
      _ => order.type.name,
    };
  }

  String _orderStatusLabel(Order order) {
    return switch (order.status) {
      OrderStatus.unpaid => 'غير مدفوع',
      OrderStatus.paid => 'مدفوع',
      OrderStatus.cancelled => 'ملغي',
    };
  }
}
