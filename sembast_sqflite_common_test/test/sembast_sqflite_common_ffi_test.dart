@TestOn('vm')
library sembast_sqflite_test.test.ffi_test;

import 'package:path/path.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast_sqflite/sembast_sqflite.dart';
import 'package:sembast_test/all_jdb_test.dart' as all_jdb_test;
import 'package:sembast_test/all_test.dart';
import 'package:sembast_test/jdb_test_common.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'ffi_setup.dart';

var testPath =
    absolute(join('.dart_tool', 'sembast_sqflite_test', 'idb', 'databases'));

Future main() async {
  await testSetup();
  // await databaseFactoryFfi.setLogLevel(sqfliteLogLevelVerbose);

  var factory = getDatabaseFactorySqflite(databaseFactoryFfi);

  var testContext = DatabaseTestContextJdb()..factory = factory;

  group('idb_io', () {
    defineTests(testContext);
    all_jdb_test.defineTests(testContext);
  });

  test('int vs String key', () async {
    var intStore = intMapStoreFactory.store('int');
    var stringStore = stringMapStoreFactory.store('string');
    var dbPath = join(testPath, 'int_vs_string_key.db');
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
}
