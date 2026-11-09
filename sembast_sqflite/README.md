# sembast_sqflite

sembast DB for flutter on top of sqflite.

`sembast_sqflite` provides a [sembast](https://pub.dev/packages/sembast) `DatabaseFactory` that stores the
database in a SQLite file. The API to read and write data is the sembast API, unchanged.

* Flutter Android, iOS and macOS through [`sqflite`](https://pub.dev/packages/sqflite)
* Flutter Windows, Linux, macOS, Dart VM and unit tests through
  [`sqflite_common_ffi`](https://pub.dev/packages/sqflite_common_ffi)
* Not on the web: use [`sembast_web`](https://pub.dev/packages/sembast_web) there (see
  [One code base for all platforms](https://github.com/tekartik/sembast.dart/blob/master/sembast/doc/open.md#one-code-base-for-all-platforms))

See [sembast](https://github.com/tekartik/sembast.dart) for API usage, starting with
[Getting started](https://github.com/tekartik/sembast.dart/blob/master/sembast/README.md#getting-started).

## Setup

```sh
flutter pub add sembast sembast_sqflite sqflite
# Desktop, Dart VM and tests
dart pub add sembast sembast_sqflite sqflite_common_ffi
```

[Setup instructions](https://github.com/tekartik/sembast_sqflite/tree/master/sembast_sqflite/doc/setup.md) for all 
platforms (Flutter/VM, iOS/Android/MacOS, Windows/Linux)

## Quick usage

Example for Flutter (iOS/Android/MacOS):

```dart
import 'package:sembast/sembast.dart';
import 'package:sembast_sqflite/sembast_sqflite.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

/// Sembast sqflite based database factory, created once.
///
/// Supports iOS/Android/MacOS for now.
final databaseFactorySqflite = getDatabaseFactorySqflite(
  sqflite.databaseFactory,
);

/// Opens the app database. Call it once at startup and keep the result.
Future<Database> openAppDatabase() {
  // A relative path is in the sqflite databases folder (getDatabasesPath()).
  return databaseFactorySqflite.openDatabase('my_app.db');
}

Future<void> demo(Database db) async {
  // Define the store, key is a string, value is a string
  var store = StoreRef<String, String>.main();
  // Define the record
  var record = store.record('my_key');

  // Write a record
  await record.put(db, 'my_value');

  // Read it
  print(await record.get(db));
}
```

* `sembast_sqflite.dart` does not export sembast: also import `package:sembast/sembast.dart`.
* Import sqflite with a prefix (`as sqflite`): both packages have a `Database` and a `DatabaseFactory` class.
* To open the database in `main()` before `runApp()`, call `WidgetsFlutterBinding.ensureInitialized()` first.
* A relative path is in `getDatabasesPath()`: the app databases folder on Android, the Documents folder on iOS and
  macOS (visible in the Files app on iOS when file sharing is enabled). An absolute path, for example in
  `path_provider`'s `getApplicationSupportDirectory()`, is used as is. An existing app must keep its path: a new path
  opens a new, empty database.

## Why

You might wonder why...sembast already has its own io format. However sembast io is not cross process safe and one
might consider that it is not a well known robust database system.

Here sqflite is used as the based of a journal database that provides data to sembast, allowing a fast all-in-memory 
access and safe cross process database storage and transaction mechanism.

## Usage notes

* `sembast_sqflite` should be used from the main isolate only
* While being cross-process safe, you might encounter locked access when using multiple transactions are in progress, which could happen while debugging.
* Changes written by another process are not pushed to this one: they are loaded on this database's next write, or
  when you call `db.checkForChanges()` (for example when the app resumes). Listeners (`onSnapshot`) fire then.
* Do not open (and close) the same database file with sqflite directly or with another sqflite based factory while
  sembast has it open: sqflite opens a single instance per path by default, so closing it there closes the connection
  sembast uses. The same goes for one file opened through two spellings of its path (`'my_app.db'` and its absolute
  path): always use the same path.
* Never point it at an existing sqlite file used for something else: a file without a sqlite user version gets its
  `entry` and `info` tables replaced, a file with one fails to open (`no such table: entry`) and a user version above
  1 is set back to 1.
* A corrupted record (unreadable value) makes `openDatabase` throw, in every mode: nothing is deleted.
* Applications should not rely on internal [storage format](https://github.com/tekartik/sembast_sqflite/tree/master/sembast_sqflite/doc/storage_format.md)
