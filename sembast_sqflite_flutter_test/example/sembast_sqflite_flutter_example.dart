import 'package:sembast_sqflite/sembast_sqflite.dart';
import 'package:sembast_test/test_common.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

export 'package:sembast/sembast.dart';

Future main() async {
  /// Sembast sqflite based database factory.
  ///
  /// Supports iOS/Android/MacOS for now.
  final factory = getDatabaseFactorySqflite(sqflite.databaseFactory);

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
