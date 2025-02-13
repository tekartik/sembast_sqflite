import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:sembast_sqflite/src/jdb_import.dart';
import 'package:sembast_sqflite/src/sembast_import.dart';
import 'package:sqflite_common/sqlite_api.dart' as sqflite;
import 'package:synchronized/synchronized.dart';

import 'constant_import.dart';
import 'jdb_factory_sqflite.dart';
import 'jdb_import.dart' as jdb;
import 'sql_constant.dart';

var _debug = false; // devWarning(true); // false

/// In memory database.
class JdbDatabaseSqflite implements jdb.JdbDatabase {
  /// New in memory database.
  JdbDatabaseSqflite(
    this._factory,
    this._sqfliteDatabase,
    this._id,
    this._path,
    this._options,
  );

  final sqflite.Database _sqfliteDatabase;
  final int _id;
  final String _path;
  final jdb.DatabaseOpenOptions? _options;
  final _revisionUpdateController = StreamController<int>();

  jdb.JdbReadEntryEncoded _encodedEntryFromCursor(Map map) {
    // Deleted is an int
    var deleted = map[sqlDeletedKey] == 1;
    var id = map[sqlIdKey] as int;
    var storeName = map[sqlStoreKey] as String;
    Object? valueEncoded;
    if (!deleted) {
      /// The value is always a string here.
      var sqlValue = map[sqlValueKey] as String;

      if (contentCodec == null) {
        valueEncoded = json.decode(sqlValue);
      } else {
        // The codec will handle that.
        valueEncoded = sqlValue;
      }
    }
    var recordKey = map[sqlKeyKey] as Key;
    var entry = JdbReadEntryEncoded(
      id,
      storeName,
      recordKey,
      deleted,
      valueEncoded,
    );
    return entry;
  }

  jdb.JdbReadEntry _entryFromCursorSync(Map map) {
    var encoded = _encodedEntryFromCursor(map);
    return decodeReadEntrySync(encoded);
  }

  final JdbFactorySqflite _factory;

  String get _debugPrefix => '[sqflite-$_id]';

  final _asyncCodeLock = Lock();

  /// Read entries by page (default 1000)
  @override
  Stream<jdb.JdbReadEntry> get entries {
    late StreamController<jdb.JdbReadEntry> ctlr;
    var hasAsyncCodec = this.hasAsyncCodec;
    ctlr = StreamController<jdb.JdbReadEntry>(
      onListen: () async {
        var limit = _factory.importPageSize;
        var lastId = 0;
        var asyncCodecFutures = <Future>[];
        while (true) {
          var maps = await _sqfliteDatabase.query(
            sqlEntryTable,
            orderBy: '$sqlIdKey ASC',
            limit: limit,
            where: '$sqlIdKey > $lastId',
          );
          for (var map in maps) {
            if (hasAsyncCodec) {
              var entry = _encodedEntryFromCursor(map);
              asyncCodecFutures.add(
                _asyncCodeLock.synchronized(() async {
                  var decoded = await decodeReadEntryAsync(entry);
                  if (_debug) {
                    // ignore: avoid_print
                    print('$_debugPrefix reading async entry $entry');
                  }
                  ctlr.add(decoded);
                }),
              );
            } else {
              var entry = _entryFromCursorSync(map);
              if (_debug) {
                // ignore: avoid_print
                print('$_debugPrefix reading entry $entry');
              }
              ctlr.add(entry);
            }
          }
          if (maps.isEmpty) {
            break;
          } else {
            lastId = maps.last[sqlIdKey] as int;
          }
        }
        if (hasAsyncCodec) {
          await Future.wait(asyncCodecFutures);
        }
        await ctlr.close();
      },
    );
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
        // ignore: avoid_print
        print('$_debugPrefix closing');
      }
      _closed = true;
      _sqfliteDatabase.close();
    }
  }

  /// Never null
  jdb.JdbInfoEntry _infoEntryFromMap(String id, Map? map) {
    var rawValue = map == null ? null : map[sqlValueKey] as String?;
    return jdb.JdbInfoEntry()
      ..id = id
      ..value = _decodeValue(rawValue);
  }

  @override
  Future<jdb.JdbInfoEntry> getInfoEntry(String id) =>
      _getInfoEntry(_sqfliteDatabase, id);

  Future<jdb.JdbInfoEntry> _getInfoEntry(
    sqflite.DatabaseExecutor executor,
    String id,
  ) async {
    var map = (await executor.query(
      sqlInfoTable,
      columns: [sqlValueKey],
      where: '$sqlIdKey = ?',
      whereArgs: [id],
    )).firstWhereOrNull((_) => true);
    return _infoEntryFromMap(id, map);
  }

  @override
  Future setInfoEntry(jdb.JdbInfoEntry entry) =>
      _setInfoEntry(_sqfliteDatabase, entry);

  Future _setInfoEntry(
    sqflite.DatabaseExecutor executor,
    jdb.JdbInfoEntry entry,
  ) async {
    var value = _encodeValue(entry.value);
    await executor.insert(sqlInfoTable, <String, Object?>{
      sqlIdKey: entry.id,
      sqlValueKey: value,
    }, conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
  }

  Future _txnSetInfoEntry(sqflite.Transaction txn, jdb.JdbInfoEntry entry) =>
      _setInfoEntry(txn, entry);

  @override
  Future addEntries(List<jdb.JdbWriteEntry> entries) async {
    var entriesEncoded = await encodeEntries(entries);
    await _sqfliteDatabase.transaction((txn) async {
      await _txnAddEntries(txn, entriesEncoded);
    });
  }

  Future _putInfoInt(
    sqflite.DatabaseExecutor executor,
    String id,
    int revision,
  ) => executor.insert(sqlInfoTable, <String, Object?>{
    sqlIdKey: id,
    sqlValueKey: _encodeValue(revision),
  }, conflictAlgorithm: sqflite.ConflictAlgorithm.replace);

  Future _putRevision(sqflite.DatabaseExecutor executor, int revision) =>
      _putInfoInt(executor, sqlRevisionKey, revision);

  Future _txnPutRevision(sqflite.Transaction txn, int revision) =>
      _putRevision(txn, revision);

  Future _putDeltaMinRevision(
    sqflite.DatabaseExecutor executor,
    int revision,
  ) => _putInfoInt(executor, jdbDeltaMinRevisionKey, revision);

  Future _txnPutDeltaMinRevision(sqflite.Transaction txn, int revision) =>
      _putDeltaMinRevision(txn, revision);

  Future<int?> _getInfoInt(sqflite.DatabaseExecutor executor, String id) async {
    var map = (await executor.query(
      sqlInfoTable,
      columns: [sqlValueKey],
      where: '$sqlIdKey = ?',
      whereArgs: [id],
    )).firstWhereOrNull((_) => true);
    if (map != null) {
      return _decodeValue(map[sqlValueKey] as String?) as int?;
    }
    return null;
  }

  /// We always need a codec (default being json)
  Codec<Object?, String> get sqfliteContentCodec => contentCodec ?? json;

  String? _encodeValue(Object? value) =>
      value == null ? null : jsonEncode(value);

  dynamic _decodeValue(String? value) =>
      value == null ? null : jsonDecode(value);

  Future<int?> _txnGetRevision(sqflite.Transaction txn) =>
      _getInfoInt(txn, sqlRevisionKey);

  // Return the last entryId
  Future<int?> _txnAddEntries(
    sqflite.Transaction txn,
    List<jdb.JdbWriteEntryEncoded> entries,
  ) async {
    int? lastEntryId;
    for (var jdbWriteEntry in entries) {
      var store = jdbWriteEntry.storeName;
      var key = jdbWriteEntry.recordKey;
      var value = jdbWriteEntry.valueEncoded;
      var deleted = jdbWriteEntry.deleted;

      /// By default the encoded value is not json encoded if content codec
      /// is null. for json conversion here
      if (contentCodec == null && !deleted) {
        value = jsonEncode(value);
      }

      lastEntryId = await txn.insert(sqlEntryTable, <String, Object?>{
        sqlStoreKey: store,
        sqlKeyKey: key,
        sqlValueKey: value,
        if (deleted) sqlDeletedKey: 1,
      }, conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
      // Save the revision in memory!
      jdbWriteEntry.revision = lastEntryId;
      if (_debug) {
        // ignore: avoid_print
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
    ctlr = StreamController<jdb.JdbEntry>(
      onListen: () async {
        // TODO by page?
        var maps = await _sqfliteDatabase.query(
          sqlEntryTable,
          where: '$sqlIdKey > $revision',
        );
        for (var map in maps) {
          var entry = _entryFromCursorSync(map);
          if (_debug) {
            // ignore: avoid_print
            print('$_debugPrefix reading entry after revision $entry');
          }
          ctlr.add(entry);
        }

        await ctlr.close();
      },
    );
    return ctlr.stream;
  }

  @override
  Future<int> getRevision() async {
    return ((await getInfoEntry(sqlRevisionKey)).value as int?) ?? 0;
  }

  @override
  Stream<int> get revisionUpdate => _revisionUpdateController.stream;

  /// Will notify.
  void addRevision(int revision) {
    _revisionUpdateController.add(revision);
  }

  @override
  Future<StorageJdbWriteResult> writeIfRevision(
    StorageJdbWriteQuery query,
  ) async {
    var entriesEncoded = await encodeEntries(query.entries);
    return await _sqfliteDatabase.transaction((txn) async {
      var expectedRevision = query.revision ?? 0;
      int? readRevision = (await _txnGetRevision(txn)) ?? 0;
      var success = (expectedRevision == readRevision);

      if (success) {
        if (query.entries.isNotEmpty) {
          readRevision = await _txnAddEntries(txn, entriesEncoded);
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
        revision: readRevision,
        query: query,
        success: success,
      );
    });
  }

  @override
  Future<Map<String, Object?>> exportToMap() async {
    var map = <String, Object?>{};
    await _sqfliteDatabase.transaction((txn) async {
      map['infos'] = await _txnStoreToDebugMap(txn, sqlInfoTable);
      map['entries'] = await _txnStoreToDebugMap(txn, sqlEntryTable);
    });
    return map;
  }

  Future<List<Map<String, Object?>>> _txnStoreToDebugMap(
    sqflite.Transaction txn,
    String name,
  ) async {
    var isEntryStore = name == sqlEntryTable;
    var list = <Map<String, Object?>>[];
    var maps = await txn.query(name, orderBy: '$sqlIdKey ASC');
    for (var map in maps) {
      var id = map[sqlIdKey];
      var sqlValue = map[sqlValueKey] as String?;

      Object? value = sqlValue;

      if (isEntryStore) {
        var deleted = map[sqlDeletedKey] == 1;
        if (!deleted) {
          if (contentCodec == null) {
            value = jsonDecode(sqlValue!);
          }
        }
        var entryValue = <String, Object?>{};
        // hack to remove the store when testing
        var store = map[sqlStoreKey];
        if (store != '_main') {
          entryValue['store'] = store;
        }
        entryValue['key'] = map[sqlKeyKey];
        // Hack to change deleted from 1 to true
        if (deleted) {
          entryValue[sqlDeletedKey] = true;
        } else {
          entryValue[sqlValueKey] = value;
        }
        value = entryValue;
      } else {
        value = jsonDecode(sqlValue!);
      }

      list.add(<String, Object?>{'id': id, 'value': value});
    }
    return list;
  }

  @override
  Future compact() async {
    await _sqfliteDatabase.transaction((txn) async {
      var deltaMinRevision = await _txnGetDeltaMinRevision(txn);
      var currentRevision = (await _txnGetRevision(txn)) ?? 0;
      var newDeltaMinRevision = deltaMinRevision;
      var maps = await txn.query(
        sqlEntryTable,
        columns: [sqlIdKey],
        where: '$sqlDeletedKey = 1',
      );
      for (var map in maps) {
        var revision = (map[sqlIdKey] as int?) ?? 0;
        if (revision > newDeltaMinRevision && revision <= currentRevision) {
          newDeltaMinRevision = revision;
          await txn.delete(sqlEntryTable, where: '$sqlIdKey = $revision');
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
      (await _getInfoInt(_sqfliteDatabase, jdbDeltaMinRevisionKey)) ?? 0;

  Future<int> _txnGetDeltaMinRevision(sqflite.Transaction txn) async =>
      (await _getInfoInt(txn, jdbDeltaMinRevisionKey)) ?? 0;

  @override
  Future clearAll() async {
    await _sqfliteDatabase.transaction((txn) async {
      await txn.delete(sqlInfoTable);
      await txn.delete(sqlEntryTable);
    });
  }

  @override
  jdb.DatabaseOpenOptions get openOptions => _options!;
}
