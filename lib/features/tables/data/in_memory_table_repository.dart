import '../domain/dining_table.dart';
import '../domain/table_repository.dart';

class InMemoryTableRepository implements TableRepository {
  InMemoryTableRepository({required List<DiningTable> tables})
      : _tables = List.unmodifiable(tables);

  factory InMemoryTableRepository.seeded() {
    return InMemoryTableRepository(
      tables: const [
        DiningTable(id: 't1', nameAr: 'ترابيزة 1', sectionAr: 'الصالة', sortOrder: 1),
        DiningTable(id: 't2', nameAr: 'ترابيزة 2', sectionAr: 'الصالة', sortOrder: 2),
        DiningTable(id: 't3', nameAr: 'ترابيزة 3', sectionAr: 'الصالة', sortOrder: 3),
        DiningTable(id: 'garden-1', nameAr: 'خارجي 1', sectionAr: 'خارجي', sortOrder: 10),
      ],
    );
  }

  final List<DiningTable> _tables;

  @override
  Future<List<DiningTable>> listTables() async {
    final tables = [..._tables];
    tables.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return tables;
  }
}
