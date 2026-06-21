import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database_gateway.dart';
import 'database_tables.dart';

class SqliteDatabaseGateway implements DatabaseGateway {
  SqliteDatabaseGateway({
    required this.fileName,
    DatabaseFactory? factory,
    String? databasePath,
  })  : _factory = factory,
        _databasePath = databasePath;

  static const schemaVersion = 6;

  final String fileName;
  final DatabaseFactory? _factory;
  final String? _databasePath;
  String? _resolvedDatabasePath;
  Database? _database;

  Database get _db {
    final database = _database;
    if (database == null) {
      throw StateError('DatabaseGateway.initialize() must be called first.');
    }
    return database;
  }

  @override
  Future<void> initialize() async {
    if (_database != null) return;

    final factory = _factory ?? _platformFactory();
    final resolvedPath = _databasePath ?? await _defaultDatabasePath();
    _resolvedDatabasePath = resolvedPath;
    _database = await factory.openDatabase(
      resolvedPath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys = ON');
          await database.execute('PRAGMA journal_mode = WAL');
        },
        onCreate: (database, version) => _createSchema(database),
        onUpgrade: _upgradeSchema,
      ),
    );
  }

  DatabaseFactory _platformFactory() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      return databaseFactoryFfi;
    }
    if (Platform.isAndroid || Platform.isIOS) {
      return databaseFactory;
    }
    throw UnsupportedError(
      'SQLite is not supported on ${Platform.operatingSystem}.',
    );
  }

  Future<String> _defaultDatabasePath() async {
    final supportDirectory = await getApplicationSupportDirectory();
    final directory = Directory(path.join(supportDirectory.path, 'SHIFT POS'));
    await directory.create(recursive: true);
    return path.join(directory.path, fileName);
  }

  Future<void> _createSchema(Database database) async {
    for (final table in DatabaseTables.all) {
      await _createEntityTable(database, table);
    }
    await database.execute(
      'CREATE INDEX audit_events_updated_at_idx '
      'ON ${DatabaseTables.auditEvents}(updated_at DESC)',
    );
  }

  Future<void> _createEntityTable(Database database, String table) {
    return database.execute('''
        CREATE TABLE $table (
          id TEXT PRIMARY KEY NOT NULL,
          payload TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
  }

  Future<void> _upgradeSchema(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      for (final table in DatabaseTables.menuV2) {
        await _createEntityTable(database, table);
      }
    }
    if (oldVersion < 3) {
      for (final table in DatabaseTables.operationsV3) {
        await _createEntityTable(database, table);
      }
    }
    if (oldVersion < 4) {
      for (final table in DatabaseTables.floorPlanV4) {
        await _createEntityTable(database, table);
      }
    }
    if (oldVersion < 5) {
      for (final table in DatabaseTables.cashDrawerV5) {
        await _createEntityTable(database, table);
      }
    }
    if (oldVersion < 6) {
      for (final table in DatabaseTables.printersV6) {
        await _createEntityTable(database, table);
      }
    }
  }

  void _checkTable(String table) {
    if (!DatabaseTables.all.contains(table)) {
      throw ArgumentError.value(table, 'table', 'Unknown database table');
    }
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    Map<String, Object?> filters = const {},
  }) async {
    _checkTable(table);
    final rows = await _db.query(table, orderBy: 'updated_at DESC');
    final decoded = rows.map((row) {
      final payload = jsonDecode(row['payload']! as String);
      if (payload is! Map<String, dynamic>) {
        throw const FormatException(
          'Database entity payload must be an object.',
        );
      }
      return <String, Object?>{'id': row['id'], ...payload};
    });
    return decoded.where((row) {
      return filters.entries.every((entry) => row[entry.key] == entry.value);
    }).toList(growable: false);
  }

  @override
  Future<void> save(
    String table,
    String id,
    Map<String, Object?> data,
  ) async {
    _checkTable(table);
    final payload = <String, Object?>{...data}..remove('id');
    await _db.insert(
      table,
      {
        'id': id,
        'payload': jsonEncode(payload),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> delete(String table, String id) async {
    _checkTable(table);
    await _db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  @override
  Future<String> createBackup({String? directoryPath}) async {
    final sourcePath = _resolvedDatabasePath;
    if (sourcePath == null) throw StateError('Database is not initialized');
    await _db.execute('PRAGMA wal_checkpoint(FULL)');
    final directory = directoryPath == null || directoryPath.trim().isEmpty
        ? Directory(path.join(
            (await getApplicationDocumentsDirectory()).path,
            'SHIFT POS Backups',
          ))
        : Directory(directoryPath.trim());
    await directory.create(recursive: true);
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final destination =
        path.join(directory.path, 'shift_pos_$timestamp.sqlite');
    await File(sourcePath).copy(destination);
    return destination;
  }

  @override
  Future<void> restoreBackup(String filePath) async {
    final destination = _resolvedDatabasePath;
    if (destination == null) throw StateError('Database is not initialized');
    final source = File(filePath);
    if (!await source.exists()) {
      throw ArgumentError.value(filePath, 'filePath', 'Backup file not found');
    }
    await close();
    await source.copy(destination);
    await initialize();
  }
}
