import 'package:sqflite_common_ffi/sqflite_ffi.dart';

export 'package:sqflite_common/sqflite_dev.dart';
export 'package:sqflite_common/sqlite_api.dart';
export 'package:test/test.dart';

Future testSetup() async {
  sqfliteFfiInit();
  //await databaseFactoryFfi.setLogLevel(sqfliteLogLevelVerbose);
  // var factory = getDatabaseFactorySqflite(databaseFactoryFfi);
}
