import 'package:sembast_sqflite/src/jdb_factory_sqflite.dart';
import 'package:sembast_sqflite/src/jdb_import.dart';
import 'package:sqflite_common/sqlite_api.dart' as sqflite;

/// Web factory.
class DatabaseFactorySqflite extends DatabaseFactoryJdb {
  /// Web factory.
  DatabaseFactorySqflite(sqflite.DatabaseFactory sqfliteDatabaseFactory)
      : super(JdbFactorySqflite(sqfliteDatabaseFactory));
}
