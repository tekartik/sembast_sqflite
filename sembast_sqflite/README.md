# sembast_sqflite

sembast DB for flutter on top of sqflite.

* Supports both iOS and Android
* Supports Flutter Web through sembast_web.
* Supports Dart VM (Desktop) through sembast

See [sembast](https://github.com/tekartik/sembast.dart) for API usage

## Setup

[Setup instructions](https://github.com/tekartik/sembast_sqflite/tree/master/sembast_sqflite/doc/setup.md) for all 
platforms (Flutter/VM, iOS/Android/MacOS, Windows/Linux)

## Quick usage

Example for Flutter (iOS/Android/MacOS):

```dart
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
```

## Why

You might wonder why...sembast already has its own io format. However sembast io is not cross process safe and one
might consider that it is not a well known robust database system.

Here sqflite is used as the based of a journal database that provides data to sembast, allowing a fast all-in-memory 
access and safe cross process database storage and transaction mechanism.

# Usage

* `sembast_sqflite` should be used from the main isolate only
* While being cross-process safe, you might encounter locked access when using multiple transactions are in progress, which could happen while debugging.
* Applications should not rely on internal [storage format](https://github.com/tekartik/sembast_sqflite/tree/master/sembast_sqflite/doc/storage_format.md)