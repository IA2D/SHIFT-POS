abstract interface class DatabaseGateway {
  Future<void> initialize();

  Future<List<Map<String, Object?>>> query(
    String table, {
    Map<String, Object?> filters = const {},
  });

  Future<void> save(
    String table,
    String id,
    Map<String, Object?> data,
  );

  Future<void> delete(String table, String id);

  Future<String> createBackup({String? directoryPath});

  Future<void> restoreBackup(String filePath);
}
