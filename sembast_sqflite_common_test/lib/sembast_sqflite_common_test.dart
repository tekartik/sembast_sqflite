import 'dart:typed_data';

import 'package:sembast/blob.dart';
import 'package:sembast_sqflite/sembast_sqflite.dart';
import 'package:sembast_sqflite_common_test/test.dart';
import 'package:sembast_test/all_jdb_test.dart' as all_jdb_test;
import 'package:sembast_test/all_test.dart';
import 'package:sembast_test/test_common.dart';
import 'package:sqflite_common/sqflite.dart' as sqflite;
// ignore: unused_import
import 'package:sqflite_common/sqflite_dev.dart';

Future defineSembastSqfliteTests(
    DatabaseTestContextSqfliteCommon testContext) async {
  var factory = testContext.factory;
  var sqlFactory = testContext.sqfliteDatabaseFactory;
  defineTests(testContext);
  all_jdb_test.defineTests(testContext);

  test('int vs String key', () async {
    var intStore = intMapStoreFactory.store('int');
    var stringStore = stringMapStoreFactory.store('string');
    var dbPath = 'int_vs_string_key.db';
    await factory.deleteDatabase(dbPath);
    var db = await factory.openDatabase(dbPath);
    try {
      await intStore.add(db, {'value': 1});
      await stringStore.add(db, {'value': 2});
      await db.close();
      db = await factory.openDatabase(dbPath);
      var intRecords = await intStore.query().getSnapshots(db);
      var stringRecords = await stringStore.query().getSnapshots(db);
      print(intRecords);
      print(stringRecords);
      expect(intRecords.first.key, isA<int>());
      expect(stringRecords.first.key, isA<String>());
      intRecords = await intStore.query().onSnapshots(db).first;
      stringRecords = await stringStore.query().onSnapshots(db).first;
    } finally {
      await db.close();
    }
  });

  test('entry with null id', () async {
    var store = intMapStoreFactory.store('test');
    var dbPath = 'entry_with_null_id.db';
    await factory.deleteDatabase(dbPath);

    // Create a database with two entries
    var db = await factory.openDatabase(dbPath);
    await db.transaction((txn) async {
      await store.record(1).put(txn, {'test': 1});
      await store.record(2).put(txn, {'test': 2});
    });
    expect(await store.findKeys(db), [1, 2]);
    await db.close();

    var fakeDbPath = 'entry_with_null_id_fake.db';
    await factory.deleteDatabase(fakeDbPath);

    // Create a fake sembast database without AUTOINCREMENT
    var fakeSqlDb = await sqlFactory.openDatabase(fakeDbPath,
        options: sqflite.OpenDatabaseOptions(
            version: 1,
            onCreate: (db, version) async {
              await db.execute('''
              CREATE TABLE info (
                id TEXT PRIMARY KEY,
                value TEXT
              )''');
              await db.execute('''
              CREATE TABLE entry (
                /* id INTEGER PRIMARY KEY AUTOINCREMENT, */
                id INTEGER,
                store TEXT NON NULL,
                key BLOB NON NULL,
                value TEXT,
                deleted INTEGER,
                UNIQUE(store, key)
              )''');
            }));

    // Copy data from database to fake database
    var sqlDb = await sqlFactory.openDatabase(dbPath);
    Future<void> copyTable(String tableName) async {
      for (var row in await sqlDb.query(tableName)) {
        await fakeSqlDb.insert(tableName, row);
      }
    }

    await copyTable('info');
    await copyTable('entry');
    await sqlDb.close();
    // Corrupt the database by setting the id of the first entry to NULL
    await fakeSqlDb.execute('UPDATE entry SET id = NULL WHERE id = 1');
    await fakeSqlDb.close();

    // Open the fake database as sembast, first entry should be ignored now
    db = await factory.openDatabase(fakeDbPath);
    expect(await store.findKeys(db), [2]);
    await db.close();
  });

  test('big record size on android', () async {
    // await sqlFactory.setLogLevel(sqflite.sqfliteLogLevelVerbose);
    var store = StoreRef<int, Blob>('test');
    var dbPath = 'big_blob_loading.db';
    await factory.deleteDatabase(dbPath);

    // Create a database with two entries
    var db = await factory.openDatabase(dbPath);

    // Bump until it fails once, 100 tested on an emulator
    var count = 100;
    for (var i = 0; i < count; i++) {
      await store.record(i).put(db, Blob(Uint8List(500 * 1024)));
    }
    await db.close();

    var defaultImportSize = factory.sqfliteImportPageSize;
    try {
      factory.sqfliteImportPageSize = 20;
      db = await factory.openDatabase(dbPath);
      expect(await store.findKeys(db), hasLength(count));
      await db.close();
    } finally {
      factory.sqfliteImportPageSize = defaultImportSize;
    }
  });
}
