@TestOn('vm')
library sembast_sqflite.test.sembast_sqflite_simple_test;

import 'package:sembast/sembast.dart';
import 'package:sembast/timestamp.dart';
import 'package:sembast_sqflite/sembast_sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'base64_codec.dart';
import 'ffi_setup.dart';

Future main() async {
  await testSetup();
  //await databaseFactoryFfi.setLogLevel(sqfliteLogLevelVerbose);
  var factory = getDatabaseFactorySqflite(databaseFactoryFfi);

  group('idb_mem', () {
    test('open', () async {
      var store = StoreRef<String, String>.main();
      var record = store.record('key');
      await factory.deleteDatabase('test');
      var db = await factory.openDatabase('test');
      await record.put(db, 'value');
      expect(await record.get(db), 'value');
      await db.close();

      db = await factory.openDatabase('test');
      await record.put(db, 'value');
      expect(await record.get(db), 'value');
      await db.close();
    });

    test('exists', () async {
      var store = StoreRef<String, String>.main();
      var record = store.record('key');

      var dbName = 'exists.db';
      await factory.deleteDatabase(dbName);
      // create an empty db
      var sqfliteDb = await databaseFactoryFfi.openDatabase(dbName);
      expect(await sqfliteDb.getVersion(), 0);
      await sqfliteDb.close();

      var db = await factory.openDatabase(dbName);
      await record.put(db, 'value');
      expect(await record.get(db), 'value');
      await db.close();
    });

    test('format', () async {
      var store = StoreRef<String, String>.main();
      var record = store.record('key');
      await factory.deleteDatabase('test');
      var db = await factory.openDatabase('test');
      await record.put(db, 'value');
      expect(await record.get(db), 'value');
      await db.close();

      var sqfliteDb = await databaseFactoryFfi.openDatabase('test');
      expect(await sqfliteDb.query('entry'), [
        {
          'id': 1,
          'store': '_main',
          'key': 'key',
          'value': '"value"',
          'deleted': null
        }
      ]);
      await sqfliteDb.close();
    });

    test('format custom type', () async {
      var store = StoreRef<String, Object?>.main();
      var record = store.record('key');
      await factory.deleteDatabase('test');
      var db = await factory.openDatabase('test');
      await record.put(db, Timestamp(1, 2));
      expect(await record.get(db), Timestamp(1, 2));
      await db.close();

      var sqfliteDb = await databaseFactoryFfi.openDatabase('test');
      expect(await sqfliteDb.query('entry'), [
        {
          'id': 1,
          'store': '_main',
          'key': 'key',
          'value': '{"@Timestamp":"1970-01-01T00:00:01.000000002Z"}',
          'deleted': null
        }
      ]);
      await sqfliteDb.close();
    });

    test('format custom type with codec', () async {
      var codec =
          SembastCodec(signature: 'base64', codec: SembaseBase64Codec());
      var store = StoreRef<String, Object?>.main();
      var record = store.record('key');
      await factory.deleteDatabase('test');
      var db = await factory.openDatabase('test', codec: codec);
      await record.put(db, Timestamp(1, 2));
      expect(await record.get(db), Timestamp(1, 2));
      await db.close();

      var sqfliteDb = await databaseFactoryFfi.openDatabase('test');
      expect(await sqfliteDb.query('entry'), [
        {
          'id': 1,
          'store': '_main',
          'key': 'key',
          'value':
              'eyJAVGltZXN0YW1wIjoiMTk3MC0wMS0wMVQwMDowMDowMS4wMDAwMDAwMDJaIn0=',
          'deleted': null
        }
      ]);
      await sqfliteDb.close();

      db = await factory.openDatabase('test', codec: codec);
      await record.put(db, Timestamp(1, 2));
      expect(await record.get(db), Timestamp(1, 2));
      await db.close();

      /*
      try {
        db = await factory.openDatabase('test');
        fail('should fail');
      } catch (e) {
        expect(e, isNot(const TypeMatcher<TestFailure>()));
      }
       */
    });
  });
}
