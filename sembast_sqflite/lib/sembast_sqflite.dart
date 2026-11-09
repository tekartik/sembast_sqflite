/// sembast on top of sqflite: a sembast database stored in a SQLite file,
/// cross process safe.
///
/// [getDatabaseFactorySqflite] turns a sqflite factory into a sembast
/// `DatabaseFactory`. This library does not export sembast: also import
/// `package:sembast/sembast.dart` for `StoreRef`, `Database`, `Finder`...
///
/// ```dart
/// import 'package:sembast/sembast.dart';
/// import 'package:sembast_sqflite/sembast_sqflite.dart';
/// import 'package:sqflite/sqflite.dart' as sqflite;
///
/// // Created once (Flutter Android, iOS, macOS).
/// final factory = getDatabaseFactorySqflite(sqflite.databaseFactory);
///
/// Future<Database> openAppDatabase() => factory.openDatabase('my_app.db');
/// ```
library;

import 'package:sembast/sembast.dart';
import 'package:sembast_sqflite/src/database_factory_sqflite.dart' as src;
import 'package:sqflite_common/sqlite_api.dart' as sqflite;
export 'src/database_factory_sqflite.dart' show DatabaseFactorySqfliteExtension;

/// Sembast factory on top of sqflite.
///
/// Build on top of sqflite_common.
///
/// [sqfliteDatabaseFactory] is `sqflite.databaseFactory` from
/// `package:sqflite` on Flutter Android, iOS and macOS, or
/// `databaseFactoryFfi` from `package:sqflite_common_ffi` on Windows, Linux,
/// the Dart VM and in tests. Create the factory once and open each database
/// once: a relative path is in the sqflite databases folder
/// (`getDatabasesPath()`), an absolute path is used as is.
///
/// Not available on the web: use `databaseFactoryWeb` from
/// `package:sembast_web` there.
DatabaseFactory getDatabaseFactorySqflite(
  sqflite.DatabaseFactory sqfliteDatabaseFactory,
) => src.DatabaseFactorySqflite(sqfliteDatabaseFactory);
