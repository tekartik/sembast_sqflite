---
name: sembast-sqflite-setup
description: >-
  Use when storing a sembast NoSQL database in a SQLite file with
  package:sembast_sqflite: choosing it over sembast_io (cross process safe,
  robust storage), creating the factory with
  getDatabaseFactorySqflite(sqfliteDatabaseFactory) from sqflite on Flutter
  iOS/Android/macOS or from sqflite_common_ffi (databaseFactoryFfi,
  sqfliteFfiInit) on desktop, Dart VM and unit tests, database path handling,
  openDatabase options, sqfliteImportPageSize, limitations (main isolate only,
  no web) and how the unchanged sembast API is used afterwards.
---

# sembast_sqflite: sembast database stored in SQLite

`package:sembast_sqflite` is a storage backend for `package:sembast`. It keeps
the whole database in memory like every sembast implementation, but persists
records as a journal in a SQLite database handled by `sqflite` (Flutter
iOS/Android/macOS) or `sqflite_common_ffi` (Windows/Linux/macOS, Dart VM,
tests). The result is a regular sembast `DatabaseFactory`: every store, record,
query, transaction and codec API of `package:sembast` is used unchanged.

```dart
import 'package:sembast/sembast.dart';
import 'package:sembast_sqflite/sembast_sqflite.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

/// One sembast factory for the whole app (Flutter iOS/Android/macOS).
final DatabaseFactory databaseFactorySqflite = getDatabaseFactorySqflite(
  sqflite.databaseFactory,
);
```

## Guidelines

### When to depend on it

* Pick `sembast_sqflite` instead of `sembast_io` (`databaseFactoryIo`) when
  the database may be opened by more than one process (Android app plus a
  background service or widget process, two desktop instances), or when a
  robust, well known on-disk format matters more than a single text file.
  Each write is a SQLite transaction, so a crash never leaves a half-written
  journal to recover.
* Prefer it over `sembast_io` for large databases: initial load is done by
  pages (`sqfliteImportPageSize` rows at a time) from an indexed table and
  deleted records are compacted in place by SQL, instead of rewriting one big
  JSON lines file.
* It does not change the memory model: the full content is still loaded in
  memory on `openDatabase()`. If the data does not fit in memory, use sqflite
  or another SQL database directly, not sembast.
* Platforms: Flutter iOS/Android/macOS through `package:sqflite`;
  Windows/Linux/macOS Flutter desktop, Dart VM and unit tests through
  `package:sqflite_common_ffi`. Not for the web: use `package:sembast_web`
  (`databaseFactoryWeb`) there.
* The package depends only on `sqflite_common`. Add the concrete sqflite
  implementation (`sqflite` and/or `sqflite_common_ffi`) to your own
  `pubspec.yaml`.

### Creating the factory

* Import `package:sembast_sqflite/sembast_sqflite.dart`. It exposes exactly
  `getDatabaseFactorySqflite(sqflite.DatabaseFactory)` returning a sembast
  `DatabaseFactory`, plus the `DatabaseFactorySqfliteExtension` extension.
  Import `package:sembast/sembast.dart` for everything else (`StoreRef`,
  `Database`, `Filter`, `Finder`, `SembastCodec`...). `sembast_sqflite.dart`
  does not re-export sembast.
* Always import the sqflite package with a prefix (`as sqflite`, `as ffi`):
  `package:sqflite`, `package:sqflite_common` and `package:sqflite_common_ffi`
  export their own `Database` and `DatabaseFactory` types, which clash with
  the sembast ones you actually use.
* On Flutter iOS/Android/macOS pass `sqflite.databaseFactory` from
  `package:sqflite/sqflite.dart` (the global getter, it is the plugin factory,
  the same object as `databaseFactorySqflitePlugin`).
* On desktop, VM and tests pass `ffi.databaseFactoryFfi` from
  `package:sqflite_common_ffi/sqflite_ffi.dart`. Call `ffi.sqfliteFfiInit()` once
  in `main()` before any database call: it is required on Windows (loads
  sqlite3.dll) and a no-op elsewhere. `databaseFactoryFfiNoIsolate` is the
  same factory running on the main isolate; keep the default isolate version
  unless you have a specific reason.
* FFI is not tested nor supported on mobile. Do not use `databaseFactoryFfi`
  on iOS/Android.
* Do not set the sqflite global `databaseFactory = databaseFactoryFfi`: it is
  only needed by sqflite's global `openDatabase()` helper. Pass the sqflite
  factory explicitly to `getDatabaseFactorySqflite()` instead.
* Create the factory once (a top-level `final` or a singleton) and share it.
  Each call to `getDatabaseFactorySqflite()` creates an independent factory
  with its own list of open databases and its own `sqfliteImportPageSize`.
* Use from the main isolate only. Do not open a `sembast_sqflite` database
  from a secondary isolate.

### Paths

* `factory.openDatabase(path)` forwards `path` as-is to the sqflite factory.
  A relative path (`'my_app.db'`) is resolved by sqflite against
  `sqfliteDatabaseFactory.getDatabasesPath()`: the app databases directory on
  Android, the Documents directory on iOS/macOS, and a default location that
  only makes sense for debugging with `sqflite_common_ffi`. An absolute path
  is used verbatim.
* On desktop and in Dart VM apps build an absolute path yourself
  (`path_provider`'s `getApplicationSupportDirectory()` in Flutter, or a
  directory you own), joined with `package:path`, and create the directory
  before opening. Only tests should rely on the ffi default location.
* `factory.deleteDatabase(path)` and `factory.databaseExists(path)` delegate to
  the sqflite factory with the same path rules. `deleteDatabase()` swallows
  errors and never throws.
* The file is a SQLite database with a fixed schema (`info` and `entry`
  tables). Never point it at an existing SQLite file used for something else:
  when sqflite reports version 0 (a file without the sembast schema) the
  tables `info` and `entry` are dropped and recreated in that file.
* Do not read or write the SQLite tables directly and do not rely on the
  storage format. Use sembast's export/import
  (`package:sembast/utils/sembast_import_export.dart`) to move data.

### Opening options and codec

* `openDatabase(path, {version, onVersionChanged, mode, codec})` are the
  sembast options with the sembast semantics; nothing sqflite specific.
  `version`/`onVersionChanged` are sembast's own versioning stored in the
  `info` table, unrelated to the internal sqflite schema version.
* `DatabaseMode.defaultMode` is `neverFails`: a corrupted database is
  deleted and recreated. Use `DatabaseMode.existing` or
  `DatabaseMode.readOnly` when losing data silently is not acceptable.
* Without a codec each record value is JSON encoded into the `value` TEXT
  column. Sembast custom types (`Timestamp`, `Blob`) are
  supported and encoded by sembast before storage.
* With `codec: SembastCodec(signature: ..., codec: ...)` the codec output
  string is stored instead of JSON, so the codec must be a
  `Codec<Object?, String>` (async content codecs are supported too). The same
  codec must be given at every open; a database opened with a different
  codec fails as with any sembast implementation.

### Import page size

* `factory.sqfliteImportPageSize` (getter and setter, from
  `DatabaseFactorySqfliteExtension`) is the number of rows read per SQL query
  when loading the database on open. Default is 1000.
* Lower it (for example 100) when records are big and SQLite reports an out
  of memory error while opening; raise it (10000 or more) to speed up the
  initial load of many small records. Set it before `openDatabase()`; it is a
  factory property, not a per-database one. `0` is not allowed (assertion).
* The extension only works on a factory returned by
  `getDatabaseFactorySqflite()`; on any other `DatabaseFactory` the cast
  throws.

### Runtime behavior

* Every `Database.close()` closes the underlying sqflite database. Close on
  app exit or before deleting the file, and do not open the same path twice
  concurrently in one process.
* Cross-process safety relies on SQLite locking. While another process (or a
  paused debugger) holds a write transaction, writes wait on the SQLite lock;
  expect "database is locked" style delays when debugging two processes.
* Record keys are stored in a BLOB column; `int` and `String` keys are both
  supported. Auto-generated `int` keys are per store and persisted in the
  `info` table.

## Examples

### Flutter iOS/Android/macOS with sqflite

```dart
import 'package:sembast/sembast.dart';
import 'package:sembast/timestamp.dart';
import 'package:sembast_sqflite/sembast_sqflite.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

/// Shared sembast factory backed by the sqflite plugin.
final DatabaseFactory databaseFactorySqflite = getDatabaseFactorySqflite(
  sqflite.databaseFactory,
);

final notesStore = intMapStoreFactory.store('notes');

Future<Database> openAppDatabase() async {
  // Relative path: stored in the platform databases directory.
  return databaseFactorySqflite.openDatabase('app.db');
}

Future<int> addNote(Database db, String title) {
  return notesStore.add(db, {'title': title, 'created': Timestamp.now()});
}
```

### Flutter desktop or Dart VM with sqflite_common_ffi

```dart
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sembast/sembast.dart';
import 'package:sembast_sqflite/sembast_sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

/// Shared sembast factory backed by sqflite ffi (Windows/Linux/macOS, VM).
final DatabaseFactory databaseFactorySqfliteFfi = getDatabaseFactorySqflite(
  ffi.databaseFactoryFfi,
);

Future<void> main() async {
  // Required on Windows, no-op elsewhere. Call once before any db access.
  ffi.sqfliteFfiInit();

  // Own the location: absolute path in a directory you create.
  var dir = Directory(p.join('.local', 'data'));
  await dir.create(recursive: true);
  var path = p.absolute(p.join(dir.path, 'app.db'));

  var db = await databaseFactorySqfliteFfi.openDatabase(path);
  var store = StoreRef<String, String>.main();
  await store.record('username').put(db, 'alice');
  print(await store.record('username').get(db)); // alice
  await db.close();
}
```

### One factory for every Flutter target (io side)

```dart
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast_sqflite/sembast_sqflite.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

// For Flutter web, use `databaseFactoryWeb` from package:sembast_web in a
// conditional import instead of this file.

DatabaseFactory? _factory;

/// sqflite plugin on iOS/Android/macOS, ffi on Windows/Linux.
DatabaseFactory get databaseFactory => _factory ??= () {
      if (Platform.isWindows || Platform.isLinux) {
        ffi.sqfliteFfiInit();
        return getDatabaseFactorySqflite(ffi.databaseFactoryFfi);
      }
      return getDatabaseFactorySqflite(sqflite.databaseFactory);
    }();

/// Relative name on mobile, absolute path in the app support dir on desktop.
Future<String> databasePath(String name) async {
  if (Platform.isWindows || Platform.isLinux) {
    var dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return p.join(dir.path, name);
  }
  return name;
}

Future<Database> openAppDatabase() async =>
    databaseFactory.openDatabase(await databasePath('app.db'));
```

### Unit test on the VM

```dart
import 'package:sembast/sembast.dart';
import 'package:sembast_sqflite/sembast_sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:test/test.dart';

void main() {
  ffi.sqfliteFfiInit();
  final factory = getDatabaseFactorySqflite(ffi.databaseFactoryFfi);
  final store = StoreRef<String, String>.main();

  test('write, reopen, read', () async {
    // Relative path: ffi default location, fine for tests only.
    var path = 'sembast_sqflite_test.db';
    await factory.deleteDatabase(path);

    var db = await factory.openDatabase(path);
    await store.record('key').put(db, 'value');
    await db.close();

    db = await factory.openDatabase(path);
    expect(await store.record('key').get(db), 'value');
    expect(await factory.databaseExists(path), isTrue);
    await db.close();
  });
}
```

### Tuning the import page size

```dart
import 'package:sembast/sembast.dart';
import 'package:sembast_sqflite/sembast_sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

Future<Database> openBigRecordsDatabase(String path) async {
  var factory = getDatabaseFactorySqflite(ffi.databaseFactoryFfi);
  // Default is 1000 rows per query. Read fewer rows at once when records are
  // large (avoids sqlite out of memory), more when they are tiny and numerous.
  factory.sqfliteImportPageSize = 100;
  return factory.openDatabase(path);
}
```

### Version, mode and codec are plain sembast options

```dart
import 'package:sembast/sembast.dart';
import 'package:sembast_sqflite/sembast_sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

final factory = getDatabaseFactorySqflite(ffi.databaseFactoryFfi);

Future<Database> openVersioned(String path, SembastCodec codec) {
  return factory.openDatabase(
    path,
    version: 2,
    onVersionChanged: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) {
        // migrate with the regular sembast API
      }
    },
    // Fail instead of silently recreating a corrupted or missing database.
    mode: DatabaseMode.existing,
    // Codec output (a String) replaces the JSON stored in the value column.
    codec: codec,
  );
}
```

### Using the database: the sembast API, unchanged

```dart
import 'package:sembast/sembast.dart';

final todos = intMapStoreFactory.store('todos');

Future<List<String>> pendingTitles(Database db) async {
  var records = await todos.find(
    db,
    finder: Finder(
      filter: Filter.equals('done', false),
      sortOrders: [SortOrder('title')],
    ),
  );
  return records.map((r) => r['title'] as String).toList();
}

Future<void> markAllDone(Database db) => db.transaction((txn) async {
      await todos.update(txn, {'done': true});
    });
```

`Database`, `StoreRef`, `RecordRef`, `Finder`, `Filter`, transactions,
listeners (`onSnapshot`) and export/import all come from `package:sembast`
and behave the same on every backend. Load the `sembast` package skills for
that API.

## Common mistakes

* Importing `package:sqflite/sqflite.dart` in a Dart VM test or a Windows/Linux
  build: the plugin needs a Flutter mobile/macOS context. Use
  `sqflite_common_ffi` there.
* Forgetting `sqfliteFfiInit()` on Windows: the sqlite3 library is not found.
* Expecting `sembast_sqflite.dart` to export sembast: also import
  `package:sembast/sembast.dart` (and `package:sembast/timestamp.dart` or
  `package:sembast/blob.dart` for those types).
* Importing sqflite without a prefix next to sembast: `Database` and
  `DatabaseFactory` become ambiguous and the file does not compile.
* Building a factory per open (`getDatabaseFactorySqflite(...)` in every
  function): each one tracks its own databases and page size. Keep one.
* Relying on the ffi default databases directory in a real desktop app.
  Use an absolute path in an app-owned directory.
* Opening a `sembast_sqflite` database in a background isolate, or the same
  path twice at the same time in one process.
* Querying the `entry`/`info` tables with sqflite to read records. The
  format is internal; use the sembast API or export/import.
* Setting `sqfliteImportPageSize` on a `DatabaseFactory` that does not come
  from `getDatabaseFactorySqflite()`: the extension throws a cast error.
