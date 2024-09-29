@TestOn('vm')
library;

import 'package:path/path.dart';
import 'package:sembast_sqflite_common_test/sembast_sqflite_common_test.dart';
import 'package:sembast_sqflite_common_test/test.dart';

import 'ffi_setup.dart' as setup;
import 'ffi_setup.dart';

var testPath =
    absolute(join('.dart_tool', 'sembast_sqflite_test', 'idb', 'databases'));

Future main() async {
  await setup.testSetup();
  // await databaseFactoryFfi.setLogLevel(sqfliteLogLevelVerbose);

  var testContext = DatabaseTestContextSqfliteFfi();
  await testContext.sqfliteDatabaseFactory.setDatabasesPath(testPath);
  group('sembast_sqflite_ffi', () {
    defineSembastSqfliteTests(testContext);
  });
}
