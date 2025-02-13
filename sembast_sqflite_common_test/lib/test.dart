import 'package:sembast/sembast.dart';
import 'package:sembast_sqflite/sembast_sqflite.dart';
import 'package:sembast_test/jdb_test_common.dart';
import 'package:sembast_test/test_common.dart';
import 'package:sqflite_common/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

/// The factory on ffi
DatabaseFactory sembastDatabaseFactorySqfliteFfi = getDatabaseFactorySqflite(
  ffi.databaseFactoryFfi,
);

/// The test context
class DatabaseTestContextSqfliteFfi extends DatabaseTestContextSqfliteBase {
  DatabaseTestContextSqfliteFfi() : super(ffi.databaseFactoryFfi);
}

/// Sqflite base test context
abstract class DatabaseTestContextSqfliteBase extends DatabaseTestContextJdb
    implements DatabaseTestContextSqfliteCommon {
  DatabaseTestContextSqfliteBase(this.sqfliteDatabaseFactory) {
    factory = getDatabaseFactorySqflite(sqfliteDatabaseFactory);
  }
  @override
  final sqflite.DatabaseFactory sqfliteDatabaseFactory;
}

/// The test context
abstract class DatabaseTestContextSqfliteCommon extends DatabaseTestContextJdb {
  sqflite.DatabaseFactory get sqfliteDatabaseFactory;
}
