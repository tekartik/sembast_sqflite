import 'dart:async';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:sembast_sqflite/src/jdb_import.dart' as jdb;
import 'package:sembast_sqflite/src/jdb_import.dart';
import 'package:sembast_sqflite/src/sql_constant.dart';
import 'package:sqflite_common/sqlite_api.dart' as sqflite;

import 'jdb_database_sqflite.dart';

/// Row count limit when importing data
var _sqfliteImportPageSizeDefault = 1000;

var _debug = false; // devWarning(true); // false

/// In memory jdb.
class JdbFactorySqflite implements jdb.JdbFactory {
  /// Sqflite factory
  JdbFactorySqflite(this.sqfliteDatabaseFactory);

  static const _sqfliteDbVersion = 1;
  var _lastId = 0;

  /// Import page size (used on open)
  int importPageSize = _sqfliteImportPageSizeDefault;

  /// The sqflite factory used
  final sqflite.DatabaseFactory sqfliteDatabaseFactory;

  /// Keep track of open databases.
  final databases = <String, List<JdbDatabaseSqflite>>{};

  @override
  Future<jdb.JdbDatabase> open(String path, DatabaseOpenOptions options) async {
    var id = ++_lastId;
    if (_debug) {
      // ignore: avoid_print
      print('[sqflite-$id] opening $path');
    }
    Future initDatabase(sqflite.Database db) async {
      if (_debug) {
        // ignore: avoid_print
        print('[sqflite-$id] creating database $path');
      }
      var batch = db.batch();
      batch.execute('DROP TABLE IF EXISTS $sqlInfoTable');
      batch.execute('''
              CREATE TABLE $sqlInfoTable (
                $sqlIdKey TEXT PRIMARY KEY,
                $sqlValueKey TEXT
              )
              ''');
      batch.execute('DROP TABLE IF EXISTS $sqlEntryTable');
      batch.execute('''
              CREATE TABLE $sqlEntryTable (
                $sqlIdKey INTEGER PRIMARY KEY AUTOINCREMENT,
                $sqlStoreKey TEXT NON NULL,
                $sqlKeyKey BLOB NON NULL,
                $sqlValueKey TEXT,
                $sqlDeletedKey INTEGER,
                UNIQUE($sqlStoreKey, $sqlKeyKey)
              )
              ''');
      batch.execute('DROP INDEX IF EXISTS $sqlRecordIndex');
      batch.execute(
          'CREATE UNIQUE INDEX $sqlRecordIndex ON $sqlEntryTable($sqlStoreKey, $sqlKeyKey)');
      batch.execute('DROP INDEX IF EXISTS $sqlDeletedIndex');
      batch.execute(
          'CREATE INDEX $sqlDeletedIndex ON $sqlEntryTable($sqlDeletedKey)');
      await batch.commit(noResult: true);
    }

    var sqfliteDb = await sqfliteDatabaseFactory.openDatabase(path,
        options: sqflite.OpenDatabaseOptions(
            version: _sqfliteDbVersion,
            onCreate: (db, version) async {
              await initDatabase(db);
            },
            onUpgrade: (db, oldVersion, newVersion) async {
              if (oldVersion < _sqfliteDbVersion) {
                await initDatabase(db);
              }
            }));

    var db = JdbDatabaseSqflite(this, sqfliteDb, id, path, options);

    /// Add to our list
    var list = databases[path] ??= <JdbDatabaseSqflite>[];
    list.add(db);

    return db;
  }

  @override
  Future delete(String path) async {
    try {
      if (_debug) {
        // ignore: avoid_print
        print('[sqflite] deleting $path');
      }
      databases.remove(path);
      await sqfliteDatabaseFactory.deleteDatabase(path);
      if (_debug) {
        // ignore: avoid_print
        print('[sqflite] deleted $path');
      }
    } catch (e) {
      if (_debug) {
        // ignore: avoid_print
        print(e);
      }
    }
  }

  @override
  Future<bool> exists(String path) async {
    late sqflite.Database db;
    try {
      db = await sqfliteDatabaseFactory.openDatabase(path,
          options: sqflite.OpenDatabaseOptions(readOnly: true));

      var meta = (await db.query(sqlInfoTable,
              where: '$sqlKeyKey = ?', whereArgs: [jdb.metaKey]))
          .firstWhereOrNull((_) => true);
      if (meta is Map && meta!['sembast'] is int) {
        return true;
      }
    } catch (_) {
    } finally {
      try {
        await db.close();
      } catch (_) {}
    }
    return false;
  }

  @override
  String toString() => 'JdbFactorySqflite($sqfliteDatabaseFactory)';
}
