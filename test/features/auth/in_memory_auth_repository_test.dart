import 'package:flutter_test/flutter_test.dart';
import 'package:shift_pos/features/auth/data/in_memory_auth_repository.dart';
import 'package:shift_pos/features/auth/domain/app_user.dart';

void main() {
  test('logs in with non-empty credentials and stores current user', () async {
    final repository = InMemoryAuthRepository();

    final user = await repository.login(username: 'ahmed', password: '1234');

    expect(user, isNotNull);
    expect(user!.username, 'ahmed');
    expect(user.can(Permission.accessPos), isTrue);
    expect(await repository.currentUser(), user);
  });

  test('rejects empty credentials', () async {
    final repository = InMemoryAuthRepository();

    expect(await repository.login(username: '', password: '1234'), isNull);
    expect(await repository.login(username: 'ahmed', password: ''), isNull);
  });

  test('logout clears current user', () async {
    final repository = InMemoryAuthRepository();
    await repository.login(username: 'ahmed', password: '1234');

    await repository.logout();

    expect(await repository.currentUser(), isNull);
  });
}
