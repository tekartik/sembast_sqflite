import 'package:sembast/sembast.dart';
import 'package:sembast_sqflite/sembast_sqflite.dart';
import 'package:sembast_sqflite_common_test/test.dart';
import 'package:sqflite/sqflite.dart' as sqflite_plugin;

/// Factory using the plugin sqflite.
DatabaseFactory sembastDatabaseFactorySqflitePlugin =
    getDatabaseFactorySqflite(sqflite_plugin.databaseFactorySqflitePlugin);

/// The test context
class DatabaseTestContextSqflitePlugin extends DatabaseTestContextSqfliteBase {
  DatabaseTestContextSqflitePlugin()
      : super(sqflite_plugin.databaseFactorySqflitePlugin);
}
