import 'package:sembast_sqflite/sembast_sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sqflite_ffi;

import 'package:sembast/sembast.dart';

Future main() async {
  /// Sembast sqflite based database factory.
  ///
  /// Supports Linux/Windows/MacOS for now.
  final factory = getDatabaseFactorySqflite(sqflite_ffi.databaseFactoryFfi);

  // Define the store, key is a string, value is a string
  var store = StoreRef<String, String>.main();
  // Define the record
  var record = store.record('my_key');

  // Open the database
  var db = await factory.openDatabase('test.db');

  // Write a record
  await record.put(db, 'my_value');

  // print store content
  print(await store.stream(db).first);

  // Close the database
  await db.close();
}
