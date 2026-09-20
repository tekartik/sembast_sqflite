---
name: sembast-sqflite-common-test-setup
description: >-
  Use when running the shared sembast_sqflite conformance suite against a
  sqflite implementation (sqflite_common_ffi on the Dart VM and desktop, the
  sqflite plugin on Flutter mobile/macOS) with
  package:sembast_sqflite_common_test: defineSembastSqfliteTests,
  DatabaseTestContextSqfliteFfi, DatabaseTestContextSqfliteBase,
  DatabaseTestContextSqfliteCommon, sembastDatabaseFactorySqfliteFfi,
  sqfliteFfiInit, setDatabasesPath, sqfliteImportPageSize, and how it layers on
  the sembast_test suites (all_test.dart, all_jdb_test.dart).
---

# sembast_sqflite_common_test: shared suite for sembast_sqflite backends

`package:sembast_sqflite_common_test` packages the whole `sembast_sqflite`
test suite as one call, `defineSembastSqfliteTests(context)`. It runs the
generic `sembast_test` suites (`all_test.dart` and `all_jdb_test.dart`) on a
factory built by `getDatabaseFactorySqflite()`, plus the sqflite-specific
regression tests. A consumer only has to provide the sqflite
`DatabaseFactory` to test with.

## Guidelines

### Depending on it

* Not on pub.dev (`publish_to: none`). Add it as a **dev dependency**, from git:
  ```yaml
  dev_dependencies:
    sembast_sqflite_common_test:
      git:
        url: https://github.com/tekartik/sembast_sqflite
        path: sembast_sqflite_common_test
      version: '>=0.5.0'
    test:
  ```
  It pulls `sembast`, `sembast_sqflite`, `sqflite_common`,
  `sqflite_common_ffi` and `sembast_test` (itself a git dependency on
  `https://github.com/tekartik/sembast.dart`, `path: sembast_test`).
* Testing the **sqflite plugin** (Flutter iOS/Android/macOS) additionally
  needs `sqflite`, `flutter_test` and `integration_test` in the consumer; that
  combination must run as a Flutter `integration_test`, not as a unit test.

### The two libraries

* `package:sembast_sqflite_common_test/test.dart` — the contexts and factory:
  * `sembastDatabaseFactorySqfliteFfi`: a ready sembast `DatabaseFactory` over
    `ffi.databaseFactoryFfi`, for quick checks that do not need a context.
  * `DatabaseTestContextSqfliteCommon`: the interface, a
    `DatabaseTestContextJdb` (so `ctx.factory` and `ctx.jdbFactory` work) plus
    `sqfliteDatabaseFactory`.
  * `DatabaseTestContextSqfliteBase(sqfliteDatabaseFactory)`: abstract base
    whose constructor sets `factory = getDatabaseFactorySqflite(
    sqfliteDatabaseFactory)`. Subclass it to test another sqflite
    implementation (the plugin, a custom `sqflite_common` factory).
  * `DatabaseTestContextSqfliteFfi()`: the concrete ffi context.
* `package:sembast_sqflite_common_test/sembast_sqflite_common_test.dart` —
  `Future defineSembastSqfliteTests(DatabaseTestContextSqfliteCommon ctx)`.
  Call it inside a `group(...)`; it registers its tests synchronously, so it
  is called without `await` like any other `define*Tests`.
* Neither library re-exports `package:test/test.dart`: import `test` (Dart) or
  `flutter_test` (Flutter integration test) yourself for `group`/`test`.

### What the suite covers

* `defineTests(ctx)` from `package:sembast_test/all_test.dart`: the full
  sembast API (crud, store, record, find, query, sort, transaction, keys,
  listeners, open/version, exceptions, codecs, import/export).
* `defineJdbTests(ctx)` from `package:sembast_test/all_jdb_test.dart`:
  journal-database semantics. It applies because `getDatabaseFactorySqflite()`
  returns a `DatabaseFactoryJdb` subclass.
* Three sqflite-specific tests: `int` and `String` keys surviving a reopen in
  the same BLOB key column, an `entry` row with a `NULL` id (a database created
  without `AUTOINCREMENT`) being skipped instead of crashing, and loading 100
  records of 500 KB with `sqfliteImportPageSize` lowered to 20 — the Android
  cursor-window regression. That last one writes ~50 MB and is slow; expect the
  suite to take minutes and give it a generous timeout.

### Setting it up correctly

* Call `sqfliteFfiInit()` from
  `package:sqflite_common_ffi/sqflite_ffi.dart` once in `main()` before the
  context is used: required on Windows, harmless elsewhere.
* Point the databases directory somewhere you own before defining the tests:
  `await ctx.sqfliteDatabaseFactory.setDatabasesPath(path)` (extension from
  `package:sqflite_common/sqflite_dev.dart`) with an `absolute()` path under
  `.dart_tool/`. The suite opens databases by relative name, so without this
  the files land in the ffi default location.
* On Flutter mobile with the ffi factory, set the databases path to
  `databaseFactorySqflitePlugin.getDatabasesPath()`; the ffi default directory
  is not writable there.
* Run with `dart test` (or `flutter test integration_test/...` for the plugin).
  Browser runs only make sense for
  `test/multiplatform/sembast_sqflite_api_test.dart`, which merely checks that
  `getDatabaseFactorySqflite` is importable; the suite itself is VM/device only.
* The context wraps one sqflite factory for the whole run. Do not mutate
  `ctx.factory` between `define*Tests` calls, and create a second context
  instead of reusing one across two sqflite implementations.
* `ctx.factory.sqfliteImportPageSize` (extension
  `DatabaseFactorySqfliteExtension` from `package:sembast_sqflite`) is a
  factory-wide setting; restore the previous value in a `finally` when a test
  changes it, as the suite does.

## Examples

### Dart VM / desktop: the whole suite on sqflite_common_ffi

```dart
@TestOn('vm')
library;

import 'package:path/path.dart';
import 'package:sembast_sqflite_common_test/sembast_sqflite_common_test.dart';
import 'package:sembast_sqflite_common_test/test.dart';
import 'package:sqflite_common/sqflite_dev.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

var testPath = absolute(
  join('.dart_tool', 'sembast_sqflite_test', 'databases'),
);

Future<void> main() async {
  sqfliteFfiInit(); // Required on Windows, no-op elsewhere.
  var testContext = DatabaseTestContextSqfliteFfi();
  // Keep every database of the run in one directory we own.
  await testContext.sqfliteDatabaseFactory.setDatabasesPath(testPath);
  group('sembast_sqflite_ffi', () {
    defineSembastSqfliteTests(testContext);
  });
}
```

### A context for another sqflite implementation

```dart
import 'package:sembast_sqflite_common_test/test.dart';
import 'package:sqflite_common/sqflite.dart' as sqflite;

/// Context for any sqflite_common factory.
///
/// In a Flutter package this is constructed with
/// `databaseFactorySqflitePlugin` from `package:sqflite/sqflite.dart`, and the
/// resulting test file must be a `flutter test integration_test/...` run.
class DatabaseTestContextSqflitePlugin extends DatabaseTestContextSqfliteBase {
  DatabaseTestContextSqflitePlugin(sqflite.DatabaseFactory sqfliteFactory)
    : super(sqfliteFactory);
}
```

### Quick check without the suite

```dart
@TestOn('vm')
library;

import 'package:sembast/sembast.dart';
import 'package:sembast_sqflite_common_test/test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show sqfliteFfiInit;
import 'package:test/test.dart';

void main() {
  sqfliteFfiInit();
  var store = StoreRef<String, String>.main();

  test('write, reopen, read', () async {
    // Shared ffi-backed sembast factory exported by the package.
    var factory = sembastDatabaseFactorySqfliteFfi;
    var path = 'quick_check.db';
    await factory.deleteDatabase(path);

    var db = await factory.openDatabase(path);
    await store.record('key').put(db, 'value');
    await db.close();

    db = await factory.openDatabase(path);
    expect(await store.record('key').get(db), 'value');
    await db.close();
  });
}
```

### Reusing the context for your own backend tests

```dart
@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:sembast/blob.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast_sqflite/sembast_sqflite.dart';
import 'package:sembast_sqflite_common_test/test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show sqfliteFfiInit;
import 'package:test/test.dart';

void main() {
  sqfliteFfiInit();
  var ctx = DatabaseTestContextSqfliteFfi();
  var store = StoreRef<int, Blob>('blobs');

  test('big blobs load with a smaller import page size', () async {
    // deleteAndOpen comes from DatabaseTestContext (package:sembast_test).
    var db = await ctx.deleteAndOpen('big_blobs.db');
    for (var i = 0; i < 5; i++) {
      await store.record(i).put(db, Blob(Uint8List(500 * 1024)));
    }
    await db.close();

    var previous = ctx.factory.sqfliteImportPageSize;
    try {
      ctx.factory.sqfliteImportPageSize = 2; // Fewer rows per SQL query.
      db = await ctx.factory.openDatabase('big_blobs.db');
      expect(await store.findKeys(db), hasLength(5));
      await db.close();
    } finally {
      // Factory-wide setting: always restore it.
      ctx.factory.sqfliteImportPageSize = previous;
    }
  });
}
```

## Common mistakes

* Forgetting `sqfliteFfiInit()`: sqlite3 is not loaded on Windows.
* Not calling `setDatabasesPath`: databases are created in the ffi default
  location (and on a mobile device, in a directory that is not writable).
* Awaiting `defineSembastSqfliteTests(...)` at top level instead of calling it
  inside a `group`, or calling it outside `main()`.
* Expecting `test.dart` or `sembast_sqflite_common_test.dart` to bring `group`
  and `expect`: import `package:test/test.dart` (or `flutter_test`) too.
* Running the suite in a browser: only the tiny multiplatform API test works
  there; `sembast_sqflite` has no web backend (use `sembast_web`).
* Adding the package to `dependencies` rather than `dev_dependencies`.
* Sharing one context between two sqflite implementations, or leaving
  `sqfliteImportPageSize` modified after a test.
