// ignore_for_file: require_trailing_commas

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_state_scope.dart';
import '../../orders/domain/order.dart';
import '../domain/dining_table.dart';
import '../domain/floor_plan.dart';

Future<DiningTable?> showFloorTablePickerDialog(
  BuildContext context, {
  required List<DiningTable> tables,
  DiningTable? selected,
}) {
  return showDialog<DiningTable>(
    context: context,
    builder: (_) => _FloorTablePickerDialog(
      tables: tables,
      selected: selected,
    ),
  );
}

class _FloorTablePickerDialog extends StatefulWidget {
  const _FloorTablePickerDialog({required this.tables, this.selected});

  final List<DiningTable> tables;
  final DiningTable? selected;

  @override
  State<_FloorTablePickerDialog> createState() =>
      _FloorTablePickerDialogState();
}

class _FloorTablePickerDialogState extends State<_FloorTablePickerDialog> {
  List<FloorPlanArea> _floors = const [];
  Set<String> _occupiedIds = const {};
  String? _activeFloorId;
  double _zoom = 1;
  bool _loading = true;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _load();
    }
  }

  Future<void> _load() async {
    final dependencies = AppStateScope.of(context);
    final results = await Future.wait([
      dependencies.tableRepository.listFloors(),
      dependencies.orderRepository.listUnpaidDineInOrders(),
    ]);
    if (!mounted) return;
    final floors = results[0] as List<FloorPlanArea>;
    final orders = results[1] as List<Order>;
    setState(() {
      _floors = floors;
      _occupiedIds =
          orders.map((order) => order.tableId).whereType<String>().toSet();
      _activeFloorId = widget.selected?.floorId ?? floors.firstOrNull?.id;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('اختيار الترابيزة'),
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      content: SizedBox(
        width: 940,
        height: 620,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (_floors.isNotEmpty) _toolbar(),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _hasVisualLayout ? _visualFloor() : _fallbackGrid(),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
      ],
    );
  }

  bool get _hasVisualLayout =>
      _floors.isNotEmpty &&
      widget.tables.any(
        (table) => table.floorId != null && table.x != null,
      );

  Widget _toolbar() {
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<String>(
              segments: _floors
                  .map((floor) => ButtonSegment(
                        value: floor.id,
                        label: Text(floor.nameAr),
                      ))
                  .toList(),
              selected: {_activeFloorId ?? _floors.first.id},
              onSelectionChanged: (value) =>
                  setState(() => _activeFloorId = value.first),
            ),
          ),
        ),
        IconButton(
          tooltip: 'تصغير',
          onPressed: _zoom <= 0.6
              ? null
              : () => setState(() => _zoom = (_zoom - 0.1).clamp(0.6, 1.8)),
          icon: const Icon(Icons.zoom_out),
        ),
        Text('${(_zoom * 100).round()}%'),
        IconButton(
          tooltip: 'تكبير',
          onPressed: _zoom >= 1.8
              ? null
              : () => setState(() => _zoom = (_zoom + 0.1).clamp(0.6, 1.8)),
          icon: const Icon(Icons.zoom_in),
        ),
      ],
    );
  }

  Widget _visualFloor() {
    final floor = _floors.firstWhere(
      (value) => value.id == _activeFloorId,
      orElse: () => _floors.first,
    );
    final tables = widget.tables
        .where((table) => table.active && table.floorId == floor.id)
        .toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final fit = math.min(
          1.0,
          math.min(
            (constraints.maxWidth - 20) / floor.width,
            (constraints.maxHeight - 20) / floor.height,
          ),
        );
        final scale = fit * _zoom;
        return Container(
          color: const Color(0xFFE8EAED),
          alignment: Alignment.center,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: SizedBox(
                width: floor.width * scale,
                height: floor.height * scale,
                child: Transform.scale(
                  alignment: Alignment.topLeft,
                  scale: scale,
                  child: SizedBox(
                    width: floor.width,
                    height: floor.height,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _PickerFloorPainter(walls: floor.walls),
                          ),
                        ),
                        for (final table in tables) ...[
                          for (final chair in _chairs(table))
                            Positioned(
                              left: chair.x - 11,
                              top: chair.y - 11,
                              child: IgnorePointer(
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: _statusColor(table)
                                        .withValues(alpha: 0.65),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            left: table.x ?? 0,
                            top: table.y ?? 0,
                            child: Transform.rotate(
                              angle: table.rotation * math.pi / 180,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => Navigator.of(context).pop(table),
                                  child: Container(
                                    width: table.width,
                                    height: table.height,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: _statusColor(table),
                                      shape: table.shape == TableShape.circle
                                          ? BoxShape.circle
                                          : BoxShape.rectangle,
                                      border: Border.all(
                                        color: table.id == widget.selected?.id
                                            ? const Color(0xFF1E3A8A)
                                            : Colors.white,
                                        width: 3,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          table.nameAr,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        if (_occupiedIds.contains(table.id))
                                          const Text(
                                            'مشغولة',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _fallbackGrid() {
    final sections = <String, List<DiningTable>>{};
    for (final table in widget.tables.where((value) => value.active)) {
      sections.putIfAbsent(table.sectionAr, () => []).add(table);
    }
    return ListView(
      children: [
        for (final entry in sections.entries) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              entry.key,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: entry.value
                .map((table) => SizedBox(
                      width: 130,
                      height: 74,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(table),
                        style: FilledButton.styleFrom(
                          backgroundColor: _statusColor(table),
                        ),
                        child: Text(table.nameAr),
                      ),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  Color _statusColor(DiningTable table) {
    if (table.id == widget.selected?.id) return const Color(0xFF1D4ED8);
    if (_occupiedIds.contains(table.id)) return const Color(0xFFB91C1C);
    return const Color(0xFF15803D);
  }

  List<TableChairPosition> _chairs(DiningTable table) {
    if (table.chairPositions.isNotEmpty) return table.chairPositions;
    final count = table.seats;
    if (count <= 0) return const [];
    final result = <TableChairPosition>[];
    final center = Offset(
      (table.x ?? 0) + table.width / 2,
      (table.y ?? 0) + table.height / 2,
    );
    final radius = math.max(table.width, table.height) / 2 + 16;
    for (var index = 0; index < count; index++) {
      final angle = 2 * math.pi * index / count - math.pi / 2;
      result.add(TableChairPosition(
        id: '${table.id}-$index',
        x: center.dx + radius * math.cos(angle),
        y: center.dy + radius * math.sin(angle),
      ));
    }
    return result;
  }
}

class _PickerFloorPainter extends CustomPainter {
  const _PickerFloorPainter({required this.walls});

  final List<FloorWall> walls;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    for (final wall in walls) {
      canvas.drawLine(
        Offset(wall.x1, wall.y1),
        Offset(wall.x2, wall.y2),
        Paint()
          ..color = const Color(0xFF555555)
          ..strokeWidth = wall.thickness
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PickerFloorPainter oldDelegate) =>
      oldDelegate.walls != walls;
}
