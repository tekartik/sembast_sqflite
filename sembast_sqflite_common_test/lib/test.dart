import 'package:sembast/sembast.dart';
import 'package:sembast_sqflite/sembast_sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

DatabaseFactory sembastDatabaseFactorySqfliteFfi =
    getDatabaseFactorySqflite(databaseFactoryFfi);
