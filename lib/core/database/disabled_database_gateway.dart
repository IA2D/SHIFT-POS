import 'database_gateway.dart';

class DisabledDatabaseGateway implements DatabaseGateway {
  const DisabledDatabaseGateway();

  Never _disabled() {
    throw StateError(
      'Database linkage is disabled by config. Enable database.enabled after '
      'schema and migrations are implemented.',
    );
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    Map<String, Object?> filters = const {},
  }) async {
    _disabled();
  }

  @override
  Future<void> save(
    String table,
    String id,
    Map<String, Object?> data,
  ) async {
    _disabled();
  }

  @override
  Future<void> delete(String table, String id) async {
    _disabled();
  }
}
