// ignore_for_file: implementation_imports, invalid_use_of_visible_for_testing_member
@TestOn('vm')
library;

import 'package:path/path.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/src/database_factory_mixin.dart';
import 'package:sembast_sqflite/sembast_sqflite.dart';
import 'package:sembast_test/base64_codec.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'ffi_setup.dart';

var testPath = absolute(
  join('.dart_tool', 'sembast_sqflite_test', 'regression', 'databases'),
);

Future<void> main() async {
  await testSetup();
  await databaseFactoryFfi.setDatabasesPath(testPath);
  var factory = getDatabaseFactorySqflite(databaseFactoryFfi);
  var store = StoreRef<int, String>('s');

  group('sembast_sqflite_regression', () {
    test('async codec, changes of another instance (delta read)', () async {
      var codec = SembastCodec(
        signature: 'async_base64',
        codec: SembastBase64CodecAsync(),
      );
      var dbPath = 'async_codec_delta.db';
      await factory.deleteDatabase(dbPath);
      var db1 = await factory.openDatabase(dbPath, codec: codec);
      // A second instance on the same path (as another process would).
      factory.mixin.removeDatabaseOpenHelper(dbPath);
      var db2 = await factory.openDatabase(dbPath, codec: codec);
      try {
        await store.record(1).put(db1, 'a');
        // db2 reads the change of db1 before writing.
        await store.record(2).put(db2, 'b');
        expect(await store.findKeys(db2), [1, 2]);
      } finally {
        await db1.close();
        await db2.close();
      }
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('corrupted value, open throws', () async {
      var dbPath = 'corrupted_value.db';
      await factory.deleteDatabase(dbPath);
      var db = await factory.openDatabase(dbPath);
      await store.record(1).put(db, 'a');
      await db.close();

      var sqfliteDb = await databaseFactoryFfi.openDatabase(dbPath);
      await sqfliteDb.rawUpdate(
        "UPDATE entry SET value = '{bad' WHERE key = 1",
      );
      await sqfliteDb.close();

      await expectLater(factory.openDatabase(dbPath), throwsA(anything));
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('new database schema', () async {
      var dbPath = 'schema.db';
      await factory.deleteDatabase(dbPath);
      var db = await factory.openDatabase(dbPath);
      await db.close();
      var sqfliteDb = await databaseFactoryFfi.openDatabase(dbPath);
      try {
        var notNull = {
          for (var row in await sqfliteDb.rawQuery('PRAGMA table_info(entry)'))
            row['name']: row['notnull'],
        };
        expect(notNull['store'], 1);
        expect(notNull['key'], 1);
        var indexes = [
          for (var row in await sqfliteDb.rawQuery('PRAGMA index_list(entry)'))
            row['name'],
        ];
        expect(indexes, isNot(contains('record')));
      } finally {
        await sqfliteDb.close();
      }
    });
  });
}
