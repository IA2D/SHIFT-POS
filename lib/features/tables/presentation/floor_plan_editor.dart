// ignore_for_file: require_trailing_commas

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_state_scope.dart';
import '../../../shared/theme/app_theme.dart';
import '../domain/dining_table.dart';
import '../domain/floor_plan.dart';

class FloorPlanEditor extends StatefulWidget {
  const FloorPlanEditor({this.onChanged, super.key});

  final VoidCallback? onChanged;

  @override
  State<FloorPlanEditor> createState() => _FloorPlanEditorState();
}

class _FloorPlanEditorState extends State<FloorPlanEditor> {
  static const _grid = 20.0;
  static const _chairRadius = 11.0;
  static const _chairGap = 5.0;
  static const _tableColors = <Color>[
    Color(0xFF1A7A4A),
    Color(0xFF0E7490),
    Color(0xFF7C3AED),
    Color(0xFFB8430A),
    Color(0xFF1D4ED8),
    Color(0xFFBE185D),
    Color(0xFF374151),
    Color(0xFFB91C1C),
  ];

  List<FloorPlanArea> _floors = const [];
  List<DiningTable> _tables = const [];
  String? _activeFloorId;
  String? _selectedTableId;
  String? _selectedWallId;
  _FloorTool _tool = _FloorTool.select;
  bool _showGrid = true;
  bool _loading = true;
  bool _saving = false;
  double _zoom = 0.8;
  Offset? _wallStart;
  Offset? _wallEnd;
  Offset? _wallDragStart;
  FloorWall? _wallDragOriginal;
  bool _loaded = false;

  FloorPlanArea? get _activeFloor {
    for (final floor in _floors) {
      if (floor.id == _activeFloorId) return floor;
    }
    return null;
  }

  DiningTable? get _selectedTable {
    for (final table in _tables) {
      if (table.id == _selectedTableId) return table;
    }
    return null;
  }

  List<DiningTable> get _floorTables => _tables
      .where((table) => table.floorId == _activeFloorId && table.active)
      .toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _load();
    }
  }

  Future<void> _load() async {
    final repository = AppStateScope.of(context).tableRepository;
    final results = await Future.wait([
      repository.listFloors(includeInactive: true),
      repository.listTables(),
    ]);
    if (!mounted) return;
    final floors = results[0] as List<FloorPlanArea>;
    final loadedTables = results[1] as List<DiningTable>;
    var hydrated = false;
    final tables = loadedTables.map((table) {
      if (table.floorId != null &&
          table.chairPositions.isEmpty &&
          table.seats > 0) {
        hydrated = true;
        return table.copyWith(
          chairPositions: _defaultChairs(table, table.seats),
        );
      }
      return table;
    }).toList();
    if (hydrated) await repository.saveTables(tables);
    setState(() {
      _floors = floors;
      _tables = tables;
      _activeFloorId = floors.any((floor) => floor.id == _activeFloorId)
          ? _activeFloorId
          : floors.firstOrNull?.id;
      _loading = false;
    });
  }

  Future<void> _saveFloor(FloorPlanArea floor) async {
    setState(() => _saving = true);
    try {
      final saved =
          await AppStateScope.of(context).tableRepository.saveFloor(floor);
      if (!mounted) return;
      setState(() {
        final index = _floors.indexWhere((value) => value.id == saved.id);
        if (index < 0) {
          _floors = [..._floors, saved];
        } else {
          _floors = [..._floors]..[index] = saved;
        }
        _saving = false;
      });
      widget.onChanged?.call();
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _showError(error);
      }
    }
  }

  Future<void> _saveTable(DiningTable table) async {
    final next = table.copyWith(updatedAt: DateTime.now());
    final saved =
        await AppStateScope.of(context).tableRepository.saveTable(next);
    if (!mounted) return;
    setState(() {
      final index = _tables.indexWhere((value) => value.id == saved.id);
      if (index < 0) {
        _tables = [..._tables, saved];
      } else {
        _tables = [..._tables]..[index] = saved;
      }
    });
    widget.onChanged?.call();
  }

  void _replaceTable(DiningTable table) {
    final index = _tables.indexWhere((value) => value.id == table.id);
    if (index < 0) return;
    setState(() => _tables = [..._tables]..[index] = table);
  }

  void _replaceFloor(FloorPlanArea floor) {
    final index = _floors.indexWhere((value) => value.id == floor.id);
    if (index < 0) return;
    setState(() => _floors = [..._floors]..[index] = floor);
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تعذر حفظ مخطط الصالة: $error')),
    );
  }

  double _snap(double value) => (value / _grid).round() * _grid;

  Color _tableColor(String id) {
    final index = _floorTables.indexWhere((table) => table.id == id);
    return _tableColors[(index < 0 ? 0 : index) % _tableColors.length];
  }

  void _moveTable(DiningTable table, DragUpdateDetails details) {
    final floor = _activeFloor;
    if (floor == null) return;
    final dx = details.delta.dx / _zoom;
    final dy = details.delta.dy / _zoom;
    final x = ((table.x ?? 0) + dx)
        .clamp(0.0, math.max(0.0, floor.width - table.width))
        .toDouble();
    final y = ((table.y ?? 0) + dy)
        .clamp(0.0, math.max(0.0, floor.height - table.height))
        .toDouble();
    _replaceTable(
      table.copyWith(
        x: x,
        y: y,
        chairPositions: table.chairPositions
            .map((chair) => chair.copyWith(x: chair.x + dx, y: chair.y + dy))
            .toList(),
      ),
    );
  }

  Future<void> _finishMove(DiningTable table) async {
    final current = _tables.firstWhere((value) => value.id == table.id);
    final dx = _snap(current.x ?? 0) - (current.x ?? 0);
    final dy = _snap(current.y ?? 0) - (current.y ?? 0);
    final snapped = current.copyWith(
      x: _snap(current.x ?? 0),
      y: _snap(current.y ?? 0),
      chairPositions: current.chairPositions
          .map((chair) => chair.copyWith(x: chair.x + dx, y: chair.y + dy))
          .toList(),
    );
    _replaceTable(snapped);
    await _saveTable(snapped);
  }

  void _resizeTable(DiningTable table, DragUpdateDetails details) {
    final floor = _activeFloor;
    if (floor == null) return;
    final width = (table.width + details.delta.dx / _zoom)
        .clamp(40.0, math.max(40.0, floor.width - (table.x ?? 0)))
        .toDouble();
    final height = (table.height + details.delta.dy / _zoom)
        .clamp(40.0, math.max(40.0, floor.height - (table.y ?? 0)))
        .toDouble();
    _replaceTable(table.copyWith(width: width, height: height));
  }

  Future<void> _finishResize(DiningTable table) async {
    final current = _tables.firstWhere((value) => value.id == table.id);
    final resized = current.copyWith(
      width: _snap(current.width).clamp(40, 300).toDouble(),
      height: _snap(current.height).clamp(40, 300).toDouble(),
    );
    final laidOut = resized.copyWith(
      chairPositions: _defaultChairs(resized, resized.chairPositions.length),
      seats: resized.chairPositions.length,
    );
    _replaceTable(laidOut);
    await _saveTable(laidOut);
  }

  void _moveChair(
    DiningTable table,
    TableChairPosition chair,
    DragUpdateDetails details,
  ) {
    final floor = _activeFloor;
    if (floor == null) return;
    final x = (chair.x + details.delta.dx / _zoom).clamp(0.0, floor.width);
    final y = (chair.y + details.delta.dy / _zoom).clamp(0.0, floor.height);
    _replaceTable(
      table.copyWith(
        chairPositions: table.chairPositions
            .map((value) =>
                value.id == chair.id ? value.copyWith(x: x, y: y) : value)
            .toList(),
      ),
    );
  }

  Future<void> _finishChairMove(
    DiningTable table,
    TableChairPosition chair,
  ) async {
    final current = _tables.firstWhere((value) => value.id == table.id);
    final moved =
        current.chairPositions.firstWhere((value) => value.id == chair.id);
    DiningTable? nearest;
    var nearestDistance = double.infinity;
    for (final candidate in _floorTables) {
      final center = Offset(
        (candidate.x ?? 0) + candidate.width / 2,
        (candidate.y ?? 0) + candidate.height / 2,
      );
      final distance = (Offset(moved.x, moved.y) - center).distance;
      final threshold = math.max(candidate.width, candidate.height) / 2 + 40;
      if (distance <= threshold && distance < nearestDistance) {
        nearest = candidate;
        nearestDistance = distance;
      }
    }
    if (nearest != null && nearest.id != current.id) {
      final source = current.copyWith(
        seats: math.max(0, current.seats - 1),
        chairPositions: current.chairPositions
            .where((value) => value.id != chair.id)
            .toList(),
      );
      final target = nearest.copyWith(
        seats: nearest.seats + 1,
        chairPositions: [
          ...nearest.chairPositions,
          moved.copyWith(x: _snap(moved.x), y: _snap(moved.y)),
        ],
      );
      _replaceTable(source);
      _replaceTable(target);
      await AppStateScope.of(context)
          .tableRepository
          .saveTables([source, target]);
      widget.onChanged?.call();
      return;
    }
    final center = Offset(
      (current.x ?? 0) + current.width / 2,
      (current.y ?? 0) + current.height / 2,
    );
    var point = Offset(_snap(moved.x), _snap(moved.y));
    final vector = point - center;
    if (vector.distance > 80) {
      point = center + vector / vector.distance * 80;
    }
    final next = current.copyWith(
      chairPositions: current.chairPositions
          .map((value) => value.id == chair.id
              ? value.copyWith(x: point.dx, y: point.dy)
              : value)
          .toList(),
    );
    _replaceTable(next);
    await _saveTable(next);
  }

  List<TableChairPosition> _defaultChairs(DiningTable table, int count) {
    if (count <= 0) return const [];
    final x = table.x ?? 0;
    final y = table.y ?? 0;
    final result = <TableChairPosition>[];
    if (table.shape == TableShape.circle) {
      final center = Offset(x + table.width / 2, y + table.height / 2);
      final radius = table.width / 2 + _chairRadius + _chairGap;
      for (var index = 0; index < count; index++) {
        final angle = 2 * math.pi * index / count - math.pi / 2;
        result.add(TableChairPosition(
          id: 'chair-${table.id}-$index',
          x: center.dx + radius * math.cos(angle),
          y: center.dy + radius * math.sin(angle),
        ));
      }
      return result;
    }
    final sides = <int>[
      (count / 4).ceil(),
      (count / 4).ceil(),
      (count / 4).floor(),
      (count / 4).floor(),
    ];
    var total = sides.fold<int>(0, (sum, value) => sum + value);
    var cursor = 0;
    while (total > count) {
      sides[cursor++ % 4]--;
      total--;
    }
    while (total < count) {
      sides[cursor++ % 4]++;
      total++;
    }
    var id = 0;
    for (var side = 0; side < 4; side++) {
      for (var index = 0; index < sides[side]; index++) {
        final t = sides[side] == 1 ? 0.5 : index / (sides[side] - 1);
        final offset = switch (side) {
          0 => Offset(
              x + 12 + t * (table.width - 24), y - _chairRadius - _chairGap),
          1 => Offset(x + 12 + t * (table.width - 24),
              y + table.height + _chairRadius + _chairGap),
          2 => Offset(
              x - _chairRadius - _chairGap, y + 12 + t * (table.height - 24)),
          _ => Offset(x + table.width + _chairRadius + _chairGap,
              y + 12 + t * (table.height - 24)),
        };
        result.add(TableChairPosition(
          id: 'chair-${table.id}-${id++}',
          x: offset.dx,
          y: offset.dy,
        ));
      }
    }
    return result;
  }

  Future<void> _addChair() async {
    final table = _selectedTable;
    if (table == null) return;
    final next = table.copyWith(
      seats: table.chairPositions.length + 1,
      chairPositions: _defaultChairs(table, table.chairPositions.length + 1),
    );
    _replaceTable(next);
    await _saveTable(next);
  }

  Future<void> _toggleShape(TableShape shape) async {
    final table = _selectedTable;
    if (table == null) return;
    final next = table.copyWith(shape: shape);
    final laidOut = next.copyWith(
      chairPositions: _defaultChairs(next, next.chairPositions.length),
    );
    _replaceTable(laidOut);
    await _saveTable(laidOut);
  }

  Future<void> _rotateTable() async {
    final table = _selectedTable;
    if (table == null) return;
    final next = table.copyWith(rotation: (table.rotation + 90) % 360);
    _replaceTable(next);
    await _saveTable(next);
  }

  Future<void> _deleteSelected() async {
    final table = _selectedTable;
    final floor = _activeFloor;
    if (table != null) {
      await AppStateScope.of(context).tableRepository.deleteTable(table.id);
      if (!mounted) return;
      setState(() {
        _tables = _tables.where((value) => value.id != table.id).toList();
        _selectedTableId = null;
      });
      widget.onChanged?.call();
      return;
    }
    if (_selectedWallId != null && floor != null) {
      final next = floor.copyWith(
        walls: floor.walls.where((wall) => wall.id != _selectedWallId).toList(),
      );
      setState(() => _selectedWallId = null);
      await _saveFloor(next);
    }
  }

  void _wallPanStart(DragStartDetails details) {
    final point = details.localPosition;
    if (_tool == _FloorTool.select) {
      final wall = _wallAt(point);
      if (wall == null) return;
      setState(() {
        _selectedWallId = wall.id;
        _selectedTableId = null;
        _wallDragStart = point;
        _wallDragOriginal = wall;
      });
      return;
    }
    final snapped = Offset(_snap(point.dx), _snap(point.dy));
    setState(() {
      _wallStart = snapped;
      _wallEnd = snapped;
    });
  }

  void _wallPanUpdate(DragUpdateDetails details) {
    if (_tool == _FloorTool.select &&
        _wallDragStart != null &&
        _wallDragOriginal != null) {
      final floor = _activeFloor;
      if (floor == null) return;
      final delta = details.localPosition - _wallDragStart!;
      final original = _wallDragOriginal!;
      _replaceFloor(
        floor.copyWith(
          walls: floor.walls
              .map((wall) => wall.id == original.id
                  ? FloorWall(
                      id: wall.id,
                      x1: original.x1 + delta.dx,
                      y1: original.y1 + delta.dy,
                      x2: original.x2 + delta.dx,
                      y2: original.y2 + delta.dy,
                      thickness: wall.thickness,
                      color: wall.color,
                    )
                  : wall)
              .toList(),
        ),
      );
      return;
    }
    if (_tool != _FloorTool.wall || _wallStart == null) return;
    setState(() {
      _wallEnd = Offset(
        _snap(details.localPosition.dx),
        _snap(details.localPosition.dy),
      );
    });
  }

  Future<void> _wallPanEnd(DragEndDetails details) async {
    if (_tool == _FloorTool.select && _wallDragOriginal != null) {
      final floor = _activeFloor;
      setState(() {
        _wallDragStart = null;
        _wallDragOriginal = null;
      });
      if (floor != null) await _saveFloor(floor);
      return;
    }
    final floor = _activeFloor;
    final start = _wallStart;
    final end = _wallEnd;
    setState(() {
      _wallStart = null;
      _wallEnd = null;
    });
    if (_tool != _FloorTool.wall ||
        floor == null ||
        start == null ||
        end == null ||
        (end - start).distance < 10) {
      return;
    }
    await _saveFloor(
      floor.copyWith(
        walls: [
          ...floor.walls,
          FloorWall(
            id: 'wall-${DateTime.now().microsecondsSinceEpoch}',
            x1: start.dx,
            y1: start.dy,
            x2: end.dx,
            y2: end.dy,
          ),
        ],
      ),
    );
  }

  void _selectWall(Offset point) {
    if (_tool != _FloorTool.select) return;
    final selected = _wallAt(point)?.id;
    setState(() {
      _selectedWallId = selected;
      _selectedTableId = null;
    });
  }

  FloorWall? _wallAt(Offset point) {
    final floor = _activeFloor;
    if (floor == null) return null;
    for (final wall in floor.walls.reversed) {
      if (_distanceToSegment(
              point, Offset(wall.x1, wall.y1), Offset(wall.x2, wall.y2)) <=
          math.max(8, wall.thickness)) {
        return wall;
      }
    }
    return null;
  }

  double _distanceToSegment(Offset point, Offset start, Offset end) {
    final lengthSquared = (end - start).distanceSquared;
    if (lengthSquared == 0) return (point - start).distance;
    final t = (((point.dx - start.dx) * (end.dx - start.dx) +
                (point.dy - start.dy) * (end.dy - start.dy)) /
            lengthSquared)
        .clamp(0.0, 1.0);
    final projection = start + (end - start) * t;
    return (point - projection).distance;
  }

  Future<void> _showFloorDialog({FloorPlanArea? floor}) async {
    final name = TextEditingController(text: floor?.nameAr ?? '');
    final width = TextEditingController(text: '${floor?.width ?? 1200}');
    final height = TextEditingController(text: '${floor?.height ?? 800}');
    final saved = await showDialog<FloorPlanArea>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(floor == null ? 'إضافة منطقة' : 'تعديل المنطقة'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'اسم المنطقة'),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: width,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'العرض'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: height,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'الارتفاع'),
                  ),
                ),
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              final now = DateTime.now();
              Navigator.of(dialogContext).pop(
                FloorPlanArea(
                  id: floor?.id ?? 'floor-${now.microsecondsSinceEpoch}',
                  nameAr: name.text.trim(),
                  width: (double.tryParse(width.text) ?? 1200).clamp(400, 3000),
                  height:
                      (double.tryParse(height.text) ?? 800).clamp(300, 2400),
                  backgroundColor: floor?.backgroundColor,
                  walls: floor?.walls ?? const [],
                  sortOrder: floor?.sortOrder ?? _floors.length,
                  active: floor?.active ?? true,
                  createdAt: floor?.createdAt ?? now,
                  updatedAt: now,
                ),
              );
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (saved == null) return;
    await _saveFloor(saved);
    if (mounted) setState(() => _activeFloorId = saved.id);
  }

  Future<void> _deleteFloor() async {
    final floor = _activeFloor;
    if (floor == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف المنطقة'),
        content: Text('سيتم حذف "${floor.nameAr}" وكل الترابيزات داخلها.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await AppStateScope.of(context).tableRepository.deleteFloor(floor.id);
    if (!mounted) return;
    setState(() {
      _floors = _floors.where((value) => value.id != floor.id).toList();
      _tables = _tables.where((value) => value.floorId != floor.id).toList();
      _activeFloorId = _floors.firstOrNull?.id;
      _selectedTableId = null;
      _selectedWallId = null;
    });
    widget.onChanged?.call();
  }

  Future<void> _showTableDialog({Offset? drop, DiningTable? table}) async {
    final floor = _activeFloor;
    if (floor == null) return;
    final name = TextEditingController(text: table?.nameAr ?? '');
    final seats = TextEditingController(text: '${table?.seats ?? 4}');
    var shape = table?.shape ?? TableShape.rectangle;
    final saved = await showDialog<DiningTable>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(table == null ? 'إضافة ترابيزة' : 'تعديل الترابيزة'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'الاسم'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: seats,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'عدد الكراسي'),
                ),
                const SizedBox(height: 8),
                SegmentedButton<TableShape>(
                  segments: const [
                    ButtonSegment(
                      value: TableShape.rectangle,
                      icon: Icon(Icons.crop_square),
                      label: Text('مربع'),
                    ),
                    ButtonSegment(
                      value: TableShape.circle,
                      icon: Icon(Icons.circle_outlined),
                      label: Text('دائري'),
                    ),
                  ],
                  selected: {shape},
                  onSelectionChanged: (value) =>
                      setDialogState(() => shape = value.first),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isEmpty) return;
                final now = DateTime.now();
                final count = (int.tryParse(seats.text) ?? 4).clamp(0, 20);
                var next = DiningTable(
                  id: table?.id ?? 'table-${now.microsecondsSinceEpoch}',
                  nameAr: name.text.trim(),
                  sectionAr: floor.nameAr,
                  sortOrder: table?.sortOrder ?? _tables.length,
                  active: table?.active ?? true,
                  floorId: floor.id,
                  x: table?.x ?? _snap(drop?.dx ?? 120),
                  y: table?.y ?? _snap(drop?.dy ?? 120),
                  width: table?.width ?? 80,
                  height: table?.height ?? 80,
                  shape: shape,
                  seats: count,
                  rotation: table?.rotation ?? 0,
                  createdAt: table?.createdAt ?? now,
                  updatedAt: now,
                );
                next = next.copyWith(
                  chairPositions: _defaultChairs(next, count),
                );
                Navigator.of(dialogContext).pop(next);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    if (saved == null) return;
    await _saveTable(saved);
    if (mounted) setState(() => _selectedTableId = saved.id);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        _toolbar(),
        if (_floors.isEmpty)
          Expanded(
            child: Center(
              child: FilledButton.icon(
                onPressed: _showFloorDialog,
                icon: const Icon(Icons.add),
                label: const Text('إضافة منطقة'),
              ),
            ),
          )
        else
          Expanded(child: _workspace()),
      ],
    );
  }

  Widget _toolbar() {
    final selected = _selectedTable;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border, width: 2)),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final floor in _floors)
            ChoiceChip(
              label: Text(floor.nameAr),
              selected: floor.id == _activeFloorId,
              onSelected: (_) => setState(() {
                _activeFloorId = floor.id;
                _selectedTableId = null;
                _selectedWallId = null;
              }),
            ),
          IconButton.filledTonal(
            tooltip: 'إضافة منطقة',
            onPressed: _showFloorDialog,
            icon: const Icon(Icons.add),
          ),
          const SizedBox(width: 6),
          SegmentedButton<_FloorTool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: _FloorTool.select,
                icon: Icon(Icons.near_me_outlined),
                label: Text('تحديد'),
              ),
              ButtonSegment(
                value: _FloorTool.wall,
                icon: Icon(Icons.draw_outlined),
                label: Text('جدار'),
              ),
            ],
            selected: {_tool},
            onSelectionChanged: (value) => setState(() => _tool = value.first),
          ),
          IconButton(
            tooltip: 'الشبكة',
            onPressed: () => setState(() => _showGrid = !_showGrid),
            icon: Icon(_showGrid ? Icons.grid_on : Icons.grid_off),
          ),
          IconButton(
            tooltip: 'تصغير',
            onPressed: _zoom <= 0.4
                ? null
                : () => setState(() => _zoom = (_zoom - 0.1).clamp(0.4, 2)),
            icon: const Icon(Icons.zoom_out),
          ),
          Text('${(_zoom * 100).round()}%'),
          IconButton(
            tooltip: 'تكبير',
            onPressed: _zoom >= 2
                ? null
                : () => setState(() => _zoom = (_zoom + 0.1).clamp(0.4, 2)),
            icon: const Icon(Icons.zoom_in),
          ),
          if (selected != null) ...[
            IconButton(
              tooltip: 'مربع',
              onPressed: () => _toggleShape(TableShape.rectangle),
              icon: const Icon(Icons.crop_square),
            ),
            IconButton(
              tooltip: 'دائري',
              onPressed: () => _toggleShape(TableShape.circle),
              icon: const Icon(Icons.circle_outlined),
            ),
            IconButton(
              tooltip: 'تدوير',
              onPressed: _rotateTable,
              icon: const Icon(Icons.rotate_right),
            ),
            IconButton(
              tooltip: 'إضافة كرسي',
              onPressed: _addChair,
              icon: const Icon(Icons.event_seat_outlined),
            ),
            IconButton(
              tooltip: 'تعديل',
              onPressed: () => _showTableDialog(table: selected),
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
          if (selected != null || _selectedWallId != null)
            IconButton(
              tooltip: 'حذف المحدد',
              onPressed: _deleteSelected,
              icon: const Icon(Icons.delete_outline),
            ),
          if (_saving)
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _workspace() {
    final floor = _activeFloor!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 190,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(left: BorderSide(color: AppTheme.border)),
            ),
            child: ListView(
              padding: const EdgeInsets.all(10),
              children: [
                Text(floor.nameAr,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                Text('${_floorTables.length} ترابيزة'),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _showFloorDialog(floor: floor),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('تعديل المنطقة'),
                ),
                TextButton.icon(
                  onPressed: _deleteFloor,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('حذف المنطقة'),
                ),
                const Divider(),
                for (final table in _floorTables)
                  ListTile(
                    dense: true,
                    selected: table.id == _selectedTableId,
                    leading: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _tableColor(table.id),
                        shape: table.shape == TableShape.circle
                            ? BoxShape.circle
                            : BoxShape.rectangle,
                      ),
                    ),
                    title: Text(table.nameAr),
                    subtitle: Text('${table.chairPositions.length} كرسي'),
                    onTap: () => setState(() {
                      _selectedTableId = table.id;
                      _selectedWallId = null;
                    }),
                  ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _showTableDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('ترابيزة'),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Container(
            color: const Color(0xFFE8EAED),
            padding: const EdgeInsets.all(12),
            child: Scrollbar(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: SizedBox(
                    width: floor.width * _zoom,
                    height: floor.height * _zoom,
                    child: Transform.scale(
                      alignment: Alignment.topLeft,
                      scale: _zoom,
                      child: _canvas(floor),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _canvas(FloorPlanArea floor) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTapDown: _tool == _FloorTool.select
          ? (details) => _showTableDialog(drop: details.localPosition)
          : null,
      onTapUp: (details) => _selectWall(details.localPosition),
      onPanStart: _wallPanStart,
      onPanUpdate: _wallPanUpdate,
      onPanEnd: _wallPanEnd,
      child: SizedBox(
        width: floor.width,
        height: floor.height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _FloorPainter(
                  showGrid: _showGrid,
                  gridSize: _grid,
                  walls: floor.walls,
                  selectedWallId: _selectedWallId,
                  wallStart: _wallStart,
                  wallEnd: _wallEnd,
                ),
              ),
            ),
            for (final table in _floorTables) ...[
              for (final chair in table.chairPositions)
                Positioned(
                  left: chair.x - _chairRadius,
                  top: chair.y - _chairRadius,
                  child: GestureDetector(
                    onPanUpdate: (details) => _moveChair(table, chair, details),
                    onPanEnd: (_) => _finishChairMove(table, chair),
                    child: Container(
                      width: _chairRadius * 2,
                      height: _chairRadius * 2,
                      decoration: BoxDecoration(
                        color: _tableColor(table.id).withValues(alpha: 0.72),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: table.x ?? 0,
                top: table.y ?? 0,
                child: Transform.rotate(
                  angle: table.rotation * math.pi / 180,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _selectedTableId = table.id;
                      _selectedWallId = null;
                    }),
                    onPanUpdate: (details) => _moveTable(table, details),
                    onPanEnd: (_) => _finishMove(table),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 80),
                          width: table.width,
                          height: table.height,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _tableColor(table.id),
                            shape: table.shape == TableShape.circle
                                ? BoxShape.circle
                                : BoxShape.rectangle,
                            border: Border.all(
                              color: table.id == _selectedTableId
                                  ? Colors.amber
                                  : Colors.white,
                              width: table.id == _selectedTableId ? 4 : 2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                offset: Offset(2, 2),
                                color: Color(0x44000000),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(
                              table.nameAr,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        if (table.id == _selectedTableId)
                          PositionedDirectional(
                            end: -8,
                            bottom: -8,
                            child: GestureDetector(
                              onPanUpdate: (details) =>
                                  _resizeTable(table, details),
                              onPanEnd: (_) => _finishResize(table),
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: const BoxDecoration(
                                  color: Colors.amber,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _FloorTool { select, wall }

class _FloorPainter extends CustomPainter {
  const _FloorPainter({
    required this.showGrid,
    required this.gridSize,
    required this.walls,
    required this.selectedWallId,
    required this.wallStart,
    required this.wallEnd,
  });

  final bool showGrid;
  final double gridSize;
  final List<FloorWall> walls;
  final String? selectedWallId;
  final Offset? wallStart;
  final Offset? wallEnd;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    if (showGrid) {
      final gridPaint = Paint()
        ..color = const Color(0xFFE2E5E9)
        ..strokeWidth = 1;
      for (var x = 0.0; x <= size.width; x += gridSize) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
      for (var y = 0.0; y <= size.height; y += gridSize) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
    }
    for (final wall in walls) {
      canvas.drawLine(
        Offset(wall.x1, wall.y1),
        Offset(wall.x2, wall.y2),
        Paint()
          ..color = wall.id == selectedWallId
              ? Colors.amber.shade700
              : _parseColor(wall.color)
          ..strokeWidth =
              wall.id == selectedWallId ? wall.thickness + 4 : wall.thickness
          ..strokeCap = StrokeCap.round,
      );
    }
    if (wallStart != null && wallEnd != null) {
      canvas.drawLine(
        wallStart!,
        wallEnd!,
        Paint()
          ..color = AppTheme.primary
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  Color _parseColor(String value) {
    final normalized = value.replaceFirst('#', '');
    final parsed = int.tryParse(normalized, radix: 16);
    return parsed == null
        ? const Color(0xFF555555)
        : Color(0xFF000000 | parsed);
  }

  @override
  bool shouldRepaint(covariant _FloorPainter oldDelegate) {
    return oldDelegate.showGrid != showGrid ||
        oldDelegate.walls != walls ||
        oldDelegate.selectedWallId != selectedWallId ||
        oldDelegate.wallStart != wallStart ||
        oldDelegate.wallEnd != wallEnd;
  }
}
