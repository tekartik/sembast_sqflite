import 'package:sembast/sembast.dart';
import 'package:sembast_sqflite/src/database_factory_sqflite.dart' as src;
import 'package:sqflite_common/sqlite_api.dart' as sqflite;

/// Sembast factory on top of sqflite.
///
/// Build on top of sqflite_common.
DatabaseFactory getDatabaseFactorySqflite(
        sqflite.DatabaseFactory sqfliteDatabaseFactory) =>
    src.DatabaseFactorySqflite(sqfliteDatabaseFactory);
