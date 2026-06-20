import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../shared/widgets/page_header.dart';

class PosPage extends StatelessWidget {
  const PosPage({
    required this.config,
    super.key,
  });

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeader(
            title: 'نقطة البيع',
            subtitle: 'بداية إعادة بناء واجهة الكاشير فوق core نظيف.',
          ),
          const SizedBox(height: 24),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.outline),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('سيتم بناء تدفق الطلبات هنا في مرحلة POS MVP.'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
