# sembast_sqflite_common_test

The shared test suite of [sembast_sqflite](../sembast_sqflite): one call,
`defineSembastSqfliteTests(context)`, runs the generic sembast suites
(`sembast_test`: `defineTests` and `defineJdbTests`) and the sqflite specific
tests on a sembast factory built on any sqflite `DatabaseFactory`. Test only,
not on pub.dev.

## Getting started

```yaml
dev_dependencies:
  sembast_sqflite_common_test:
    git:
      url: https://github.com/tekartik/sembast_sqflite
      path: sembast_sqflite_common_test
    version: '>=0.5.0'
  sembast: '>=3.10.1'
  sqflite_common_ffi: any
  path: any
  test: any
```

`test/sembast_sqflite_ffi_test.dart`, on sqflite_common_ffi (Dart VM, desktop):

```dart
@TestOn('vm')
library;

import 'package:path/path.dart';
import 'package:sembast_sqflite_common_test/sembast_sqflite_common_test.dart';
import 'package:sembast_sqflite_common_test/test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

Future<void> main() async {
  sqfliteFfiInit();
  var context = DatabaseTestContextSqfliteFfi();
  // Every database of the run in one folder.
  await context.sqfliteDatabaseFactory.setDatabasesPath(
    absolute(join('.dart_tool', 'sembast_sqflite_test', 'databases')),
  );
  group('sembast_sqflite_ffi', () {
    defineSembastSqfliteTests(context);
  });
}
```

Run it with `dart test`. For the sqflite plugin (Android, iOS, macOS), subclass
`DatabaseTestContextSqfliteBase` with `databaseFactorySqflitePlugin` and run
the same call in a Flutter `integration_test` (see
`sembast_sqflite_flutter_test` in this repository).

## Who runs it

* this package: sqflite_common_ffi (`test/sembast_sqflite_common_ffi_test.dart`),
* `sembast_sqflite_flutter_test`: the sqflite plugin on a device and ffi.

## Common pitfalls

* sembast 3.10.1 at least: the shared jdb suite checks the changes of another
  process (listeners after a full reload, upgrade retried after a concurrent
  write). With an older sembast two tests fail.
* Call `setDatabasesPath` before defining the tests: the suite opens its
  databases by relative name. Two test files using one folder must not run
  at the same time (`concurrency: 1` in `dart_test.yaml`): the databases get
  locked.
* VM and devices only: sembast_sqflite has no web backend (use sembast_web).

Agent skill: [skills/sembast-sqflite-common-test-setup](skills/sembast-sqflite-common-test-setup/SKILL.md).
