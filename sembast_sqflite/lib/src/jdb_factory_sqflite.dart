import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:sembast/sembast.dart';
import 'package:sembast_sqflite/src/constant_import.dart';
import 'package:sembast_sqflite/src/jdb_import.dart' as jdb;
import 'package:sembast_sqflite/src/jdb_import.dart';
import 'package:sembast_sqflite/src/sembast_import.dart';
import 'package:sqflite_common/sqlite_api.dart' as sqflite;

var _debug = false; // devWarning(true); // false
/// The journal entry id
const _idPath = 'id';
const _infoStore = 'info';
const _entryStore = 'entry';
const _storePath = dbStoreNameKey;
const _keyPath = dbRecordKey;
const _recordIndex = 'record';
const _deletedIndex = 'deleted';
const _valuePath = dbRecordValueKey;
const _deletedPath = dbRecordDeletedKey;

/// last entry id inserted
const _revisionKey = jdbRevisionKey;

/// In memory jdb.
class JdbFactorySqflite implements jdb.JdbFactory {
  /// Sqflite factory
  JdbFactorySqflite(this.sqfliteDatabaseFactory);

  static const _sqfliteDbVersion = 1;
  var _lastId = 0;

  /// The sqflite factory used
  final sqflite.DatabaseFactory sqfliteDatabaseFactory;

  /// Keep track of open databases.
  final databases = <String, List<JdbDatabaseSqflite>>{};

  @override
  Future<jdb.JdbDatabase> open(String path,
      {DatabaseOpenOptions? options}) async {
    var id = ++_lastId;
    if (_debug) {
      print('[sqflite-$id] opening $path');
    }
    Future initDatabase(sqflite.Database db) async {
      if (_debug) {
        print('[sqflite-$id] creating database $path');
      }
      var batch = db.batch();
      batch.execute('DROP TABLE IF EXISTS $_infoStore');
      batch.execute('''
              CREATE TABLE $_infoStore (
                $_idPath TEXT PRIMARY KEY,
                $_valuePath TEXT
              )
              ''');
      batch.execute('DROP TABLE IF EXISTS $_entryStore');
      batch.execute('''
              CREATE TABLE $_entryStore (
                $_idPath INTEGER PRIMARY KEY AUTOINCREMENT,
                $_storePath TEXT NON NULL,
                $_keyPath BLOB NON NULL,
                $_valuePath TEXT,
                $_deletedPath,
                UNIQUE($_storePath, $_keyPath)
              )
              ''');
      batch.execute(
          'CREATE UNIQUE INDEX $_recordIndex ON $_entryStore($_storePath, $_keyPath)');
      batch.execute(
          'CREATE INDEX $_deletedIndex ON $_entryStore($_deletedPath)');
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
        print('[sqflite] deleting $path');
      }
      databases.remove(path);
      await sqfliteDatabaseFactory.deleteDatabase(path);
      if (_debug) {
        print('[sqflite] deleted $path');
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  Future<bool> exists(String path) async {
    late sqflite.Database db;
    try {
      db = await sqfliteDatabaseFactory.openDatabase(path,
          options: sqflite.OpenDatabaseOptions(readOnly: true));

      var meta = (await db.query(_infoStore,
              where: '$_keyPath = ?', whereArgs: [jdb.metaKey]))
          .firstWhereOrNull((_) => true);
      if (meta is Map && meta!['sembast'] is int) {
        return true;
      }
    } catch (_) {} finally {
      try {
        await db.close();
      } catch (_) {}
    }
    return false;
  }

  @override
  String toString() => 'JdbFactorySqflite($sqfliteDatabaseFactory)';
}

/// In memory database.
class JdbDatabaseSqflite implements jdb.JdbDatabase {
  /// New in memory database.
  JdbDatabaseSqflite(this._factory, this._sqfliteDatabase, this._id, this._path,
      this._options);

  final sqflite.Database _sqfliteDatabase;
  final int _id;
  final String _path;
  final jdb.DatabaseOpenOptions? _options;
  final _revisionUpdateController = StreamController<int>();

  jdb.JdbReadEntry _entryFromCursor(Map map) {
    var entry = jdb.JdbReadEntry()
      ..id = map[_idPath] as int
      ..record = StoreRef(map[_storePath] as String).record(map[_keyPath])
      ..value = _decodeRecordValue(map[_valuePath] as String?)
      // Deleted is an int
      ..deleted = map[_deletedPath] == 1;
    return entry;
  }

  final JdbFactorySqflite _factory;

  //final _entries = <JdbEntrySqflite>[];
  String get _debugPrefix => '[sqflite-$_id]';

  // For now read all at once
  // TODO read by <n> records
  @override
  Stream<jdb.JdbReadEntry> get entries {
    late StreamController<jdb.JdbReadEntry> ctlr;
    ctlr = StreamController<jdb.JdbReadEntry>(onListen: () async {
      var maps = await _sqfliteDatabase.query(_entryStore);
      for (var map in maps) {
        var entry = _entryFromCursor(map);
        if (_debug) {
          print('$_debugPrefix reading entry $entry');
        }
        ctlr.add(entry);
      }
      await ctlr.close();
    });
    return ctlr.stream;
  }

  var _closed = false;

  @override
  void close() {
    if (!_closed) {
      // Clear from our list of open database

      var list = _factory.databases[_path];
      if (list != null) {
        list.remove(this);
        if (list.isEmpty) {
          _factory.databases.remove(_path);
        }
      }
      if (_debug) {
        print('$_debugPrefix closing');
      }
      _closed = true;
      _sqfliteDatabase.close();
    }
  }

  /// Never null
  jdb.JdbInfoEntry _infoEntryFromMap(String id, Map? map) {
    var rawValue = map == null ? null : map[_valuePath] as String?;
    return jdb.JdbInfoEntry()
      ..id = id
      ..value = _decodeValue(rawValue);
  }

  @override
  Future<jdb.JdbInfoEntry> getInfoEntry(String id) =>
      _getInfoEntry(_sqfliteDatabase, id);

  Future<jdb.JdbInfoEntry> _getInfoEntry(
      sqflite.DatabaseExecutor executor, String id) async {
    var map = (await executor.query(_infoStore,
            columns: [_valuePath], where: '$_idPath = ?', whereArgs: [id]))
        .firstWhereOrNull((_) => true);
    return _infoEntryFromMap(id, map);
  }

  @override
  Future setInfoEntry(jdb.JdbInfoEntry entry) =>
      _setInfoEntry(_sqfliteDatabase, entry);

  Future _setInfoEntry(
      sqflite.DatabaseExecutor executor, jdb.JdbInfoEntry entry) async {
    var value = _encodeValue(entry.value);
    await executor.insert(
        _infoStore, <String, dynamic>{_idPath: entry.id, _valuePath: value},
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
  }

  Future _txnSetInfoEntry(sqflite.Transaction txn, jdb.JdbInfoEntry entry) =>
      _setInfoEntry(txn, entry);

  @override
  Future addEntries(List<jdb.JdbWriteEntry> entries) async {
    await _sqfliteDatabase.transaction((txn) async {
      await _txnAddEntries(txn, entries);
    });
  }

  Future _putInfoInt(
          sqflite.DatabaseExecutor executor, String id, int revision) =>
      executor.insert(_infoStore,
          <String, dynamic>{_idPath: id, _valuePath: _encodeValue(revision)},
          conflictAlgorithm: sqflite.ConflictAlgorithm.replace);

  Future _putRevision(sqflite.DatabaseExecutor executor, int revision) =>
      _putInfoInt(executor, _revisionKey, revision);

  Future _txnPutRevision(sqflite.Transaction txn, int revision) =>
      _putRevision(txn, revision);

  Future _putDeltaMinRevision(
          sqflite.DatabaseExecutor executor, int revision) =>
      _putInfoInt(executor, jdbDeltaMinRevisionKey, revision);

  Future _txnPutDeltaMinRevision(sqflite.Transaction txn, int revision) =>
      _putDeltaMinRevision(txn, revision);

  Future<int?> _getInfoInt(sqflite.DatabaseExecutor executor, String id) async {
    var map = (await executor.query(_infoStore,
            columns: [_valuePath], where: '$_idPath = ?', whereArgs: [id]))
        .firstWhereOrNull((_) => true);
    if (map != null) {
      return _decodeValue(map[_valuePath] as String?) as int?;
    }
    return null;
  }

  String? _encodeRecordValue(Object? value) {
    if (value == null) {
      return null;
    }
    var encodable = (_options?.codec?.jsonEncodableCodec ??
            jdb.sembastDefaultJsonEncodableCodec)
        .encode(value);
    return (_options?.codec?.codec ?? json).encode(encodable);
  }

  /// Special handling for int
  dynamic _decodeRecordValue(String? value) {
    if (value == null) {
      return null;
    }
    var encodable = (_options?.codec?.codec ?? json).decode(value)!;
    return (_options?.codec?.jsonEncodableCodec ??
            jdb.sembastDefaultJsonEncodableCodec)
        .decode(encodable);
  }

  String? _encodeValue(dynamic value) =>
      value == null ? null : jsonEncode(value);

  dynamic _decodeValue(String? value) =>
      value == null ? null : jsonDecode(value);

  Future<int?> _txnGetRevision(sqflite.Transaction txn) =>
      _getInfoInt(txn, _revisionKey);

  // Return the last entryId
  Future<int?> _txnAddEntries(
      sqflite.Transaction txn, List<jdb.JdbWriteEntry> entries) async {
    int? lastEntryId;
    for (var jdbWriteEntry in entries) {
      var store = jdbWriteEntry.record.store.name;
      var key = jdbWriteEntry.record.key;
      var value = _encodeRecordValue(jdbWriteEntry.value!);

      /*
      var sqfliteKey = await index.getKey([store, key]);
      if (sqfliteKey != null) {
        if (_debug) {
          print('$_debugPrefix deleting entry $sqfliteKey');
        }
        await objectStore.delete(sqfliteKey);
      }
       */

      lastEntryId = await txn.insert(
          _entryStore,
          <String, dynamic>{
            _storePath: store,
            _keyPath: key,
            _valuePath: value,
            if (jdbWriteEntry.deleted) _deletedPath: 1
          },
          conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
      // Save the revision in memory!
      jdbWriteEntry.txnRecord?.record.revision = lastEntryId;
      if (_debug) {
        print('$_debugPrefix added entry $lastEntryId $jdbWriteEntry');
      }
    }

    return lastEntryId;
  }

  @override
  String toString() => 'JdbDatabaseSqflite($_id, $_path)';

  String _storeLastIdKey(String store) {
    return '${store}_store_last_id';
  }

  @override
  Future<List<int>> generateUniqueIntKeys(String store, int count) async {
    var keys = <int>[];
    var infoKey = _storeLastIdKey(store);
    var lastId = (await _getInfoInt(_sqfliteDatabase, infoKey)) ?? 0;
    for (var i = 0; i < count; i++) {
      lastId++;
      keys.add(lastId);
    }
    return keys;
  }

  @override
  Future<List<String>> generateUniqueStringKeys(String store, int count) async {
    return List.generate(count, (index) => generateStringKey()).toList();
  }

  @override
  Stream<jdb.JdbEntry> entriesAfterRevision(int revision) {
    late StreamController<jdb.JdbEntry> ctlr;
    ctlr = StreamController<jdb.JdbEntry>(onListen: () async {
      // TODO by page?
      var maps = await _sqfliteDatabase.query(_entryStore,
          where: '$_idPath > $revision');
      for (var map in maps) {
        var entry = _entryFromCursor(map);
        if (_debug) {
          print('$_debugPrefix reading entry after revision $entry');
        }
        ctlr.add(entry);
      }

      await ctlr.close();
    });
    return ctlr.stream;
  }

  @override
  Future<int> getRevision() async {
    return ((await getInfoEntry(_revisionKey)).value as int?) ?? 0;
  }

  @override
  Stream<int> get revisionUpdate => _revisionUpdateController.stream;

  /// Will notify.
  void addRevision(int revision) {
    _revisionUpdateController.add(revision);
  }

  @override
  Future<StorageJdbWriteResult> writeIfRevision(
      StorageJdbWriteQuery query) async {
    return await _sqfliteDatabase.transaction((txn) async {
      var expectedRevision = query.revision ?? 0;
      int? readRevision = (await _txnGetRevision(txn)) ?? 0;
      var success = (expectedRevision == readRevision);

      if (success) {
        if (query.entries.isNotEmpty) {
          readRevision = await _txnAddEntries(txn, query.entries);
          // Set revision info
          if (readRevision != null) {
            await _txnPutRevision(txn, readRevision);
          }
        }
        if (query.infoEntries.isNotEmpty) {
          for (var infoEntry in query.infoEntries) {
            await _txnSetInfoEntry(txn, infoEntry);
          }
        }
      }
      return StorageJdbWriteResult(
          revision: readRevision, query: query, success: success);
    });
  }

  @override
  Future<Map<String, dynamic>> exportToMap() async {
    var map = <String, dynamic>{};
    await _sqfliteDatabase.transaction((txn) async {
      map['infos'] = await _txnStoreToDebugMap(txn, _infoStore);
      map['entries'] = await _txnStoreToDebugMap(txn, _entryStore);
    });
    return map;
  }

  Future<List<Map<String, dynamic>>> _txnStoreToDebugMap(
      sqflite.Transaction txn, String name) async {
    var isEntryStore = name == _entryStore;
    var list = <Map<String, dynamic>>[];
    var maps = await txn.query(name, orderBy: '$_idPath ASC');
    for (var map in maps) {
      var id = map[_idPath];
      var value = _decodeValue(map[_valuePath] as String?);
      if (isEntryStore) {
        value = <String, dynamic>{'value': value};
        // hack to remove the store when testing
        var store = map[_storePath];
        if (store != '_main') {
          value['store'] = store;
        }
        value['key'] = map[_keyPath];
        // Hack to change deleted from 1 to true
        if (map[_deletedPath] == 1) {
          value[_deletedPath] = true;
        }
      }

      list.add(<String, dynamic>{'id': id, 'value': value});
    }
    return list;
  }

  @override
  Future compact() async {
    await _sqfliteDatabase.transaction((txn) async {
      var deltaMinRevision = await _txnGetDeltaMinRevision(txn);
      var currentRevision = await _txnGetRevision(txn);
      var newDeltaMinRevision = deltaMinRevision;
      var maps = await txn.query(_entryStore,
          columns: [_idPath], where: '$_deletedPath = 1');
      for (var map in maps) {
        var revision = map[_idPath] as int;
        if (revision > newDeltaMinRevision && revision <= currentRevision!) {
          newDeltaMinRevision = revision;
          await txn.delete(_entryStore, where: '$_idPath = $revision');
        }
      }
      // devPrint('compact $newDeltaMinRevision vs $deltaMinRevision, $currentRevision');
      if (newDeltaMinRevision > deltaMinRevision) {
        await _txnPutDeltaMinRevision(txn, newDeltaMinRevision);
      }
    });
  }

  @override
  Future<int> getDeltaMinRevision() async =>
      (await (_getInfoInt(_sqfliteDatabase, jdbDeltaMinRevisionKey)
              as FutureOr<int>?) ??
          0);

  Future<int> _txnGetDeltaMinRevision(sqflite.Transaction txn) async =>
      (await (_getInfoInt(txn, jdbDeltaMinRevisionKey) as FutureOr<int>?) ?? 0);

  @override
  Future clearAll() async {
    await _sqfliteDatabase.transaction((txn) async {
      await txn.delete(_infoStore);
      await txn.delete(_entryStore);
    });
  }
}
