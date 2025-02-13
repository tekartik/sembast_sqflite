import 'package:sembast/sembast.dart';
import 'package:sembast_sqflite/src/jdb_factory_sqflite.dart';
import 'package:sembast_sqflite/src/jdb_import.dart';
import 'package:sqflite_common/sqlite_api.dart' as sqflite;

/// Web factory.
class DatabaseFactorySqflite extends DatabaseFactoryJdb {
  /// Web factory.
  DatabaseFactorySqflite(sqflite.DatabaseFactory sqfliteDatabaseFactory)
    : super(JdbFactorySqflite(sqfliteDatabaseFactory));
}

DatabaseFactorySqflite asDatabaseFactorySqflite(
  DatabaseFactory databaseFactory,
) {
  try {
    return databaseFactory as DatabaseFactorySqflite;
  } catch (e) {
    // ignore: avoid_print
    print(
      'Invalid databaseFactory ${databaseFactory.runtimeType} type, expecting DatabaseFactorySqlite.',
    );
    rethrow;
  }
}

/// Extension on database factory for sqlite specific features.
extension DatabaseFactorySqfliteExtension on DatabaseFactory {
  DatabaseFactorySqflite get _df => asDatabaseFactorySqflite(this);
  JdbFactorySqflite get _jdbFactory => _df.jdbFactory as JdbFactorySqflite;

  /// Get the import page size used
  int get sqfliteImportPageSize => _jdbFactory.importPageSize;

  /// Change the import page size used. Could be used in case on memory error
  /// if records are big
  set sqfliteImportPageSize(int importPageSize) {
    assert(importPageSize != 0); // 0 not supported neither
    _jdbFactory.importPageSize = importPageSize;
  }
}
