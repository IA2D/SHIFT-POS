import 'package:flutter_test/flutter_test.dart';
import 'package:shift_pos/features/auth/data/in_memory_auth_repository.dart';

void main() {
  test('sets, verifies, replaces, and clears cashier PIN', () async {
    final repository = InMemoryAuthRepository();
    final admin = (await repository.listAccounts()).single;

    await repository.setPin(admin.id, '1234');
    expect(await repository.verifyPin(admin.id, '1234'), isTrue);
    expect(await repository.verifyPin(admin.id, '1111'), isFalse);
    expect((await repository.listAccounts()).single.pin, isNotNull);

    await repository.setPin(admin.id, '4321');
    expect(await repository.verifyPin(admin.id, '1234'), isFalse);
    expect(await repository.verifyPin(admin.id, '4321'), isTrue);

    await repository.setPin(admin.id, null);
    expect(await repository.verifyPin(admin.id, '4321'), isFalse);
    expect((await repository.listAccounts()).single.pin, isNull);
  });

  test('rejects malformed PIN values', () async {
    final repository = InMemoryAuthRepository();
    final admin = (await repository.listAccounts()).single;

    expect(() => repository.setPin(admin.id, '12'), throwsArgumentError);
    expect(() => repository.setPin(admin.id, 'abcd'), throwsArgumentError);
  });
}
