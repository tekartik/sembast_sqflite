@TestOn('vm')
library sembast_sqflite_test.test.ffi_test;

import 'package:sembast_sqflite/sembast_sqflite.dart';
import 'package:sembast_test/all_jdb_test.dart' as all_jdb_test;
import 'package:sembast_test/all_test.dart';
import 'package:sembast_test/jdb_test_common.dart';
import 'package:sembast_test/test_common.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sqflite;
import 'package:test/test.dart';

import 'ffi_setup.dart';

var testPath = '.dart_tool/sembast_test/idb/databases';

Future main() async {
  await testSetup();
  // await databaseFactoryFfi.setLogLevel(sqfliteLogLevelVerbose);

  var factory = getDatabaseFactorySqflite(sqflite.databaseFactoryFfi);

  var testContext = DatabaseTestContextJdb()..factory = factory;

  group('idb_io', () {
    defineTests(testContext);
    all_jdb_test.defineTests(testContext);
  });
}
