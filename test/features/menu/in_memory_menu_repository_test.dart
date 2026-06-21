import 'package:flutter_test/flutter_test.dart';
import 'package:shift_pos/features/menu/data/in_memory_menu_repository.dart';

void main() {
  test('seeded menu repository returns active items and sorted categories',
      () async {
    final repository = InMemoryMenuRepository.seeded();

    final categories = await repository.listCategories();
    final items = await repository.listItems();

    expect(categories.map((category) => category.id),
        ['grills', 'drinks', 'extras']);
    expect(items, isNotEmpty);
    expect(items.every((item) => item.active), isTrue);
  });
}
