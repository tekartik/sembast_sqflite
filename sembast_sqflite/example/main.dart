import 'package:sembast/sembast.dart';
import 'package:sembast_sqflite/sembast_sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future main() async {
  // The sqflite base factory

  var factory = getDatabaseFactorySqflite(databaseFactoryFfi);

  var db = await factory.openDatabase('example.db');
  // Use the main store for storing key values as String
  var store = StoreRef<String, String>.main();

  // Writing the data
  await store.record('username').put(db, 'my_username');
  await store.record('url').put(db, 'my_url');

  // Reading the data
  var url = await store.record('url').get(db);
  var username = await store.record('username').get(db);

  print('url: $url');
  print('username: $username');
}
