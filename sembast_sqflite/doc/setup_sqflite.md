## Sembast sqflite setup

### Flutter iOS/Android/MacOS

**Flutter context needed.**

You have to import the `sqflite` dependency in a flutter context.

`pubspec.yaml`:
```yaml
dependencies:
  sembast_sqflite:
  sqflite:
```

The default factory based on sqflite can be created this way:

```dart
import 'package:sembast_sqflite/sembast_sqflite.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

export 'package:sembast/sembast.dart';

/// Sembast sqflite based database factory.
///
/// Supports iOS/Android/MacOS for now.
final databaseFactorySqflite =
    getDatabaseFactorySqflite(sqflite.databaseFactory);
```

A sembast database can be opened/created this way:

```dart
var factory = databaseFactorySqflite;
var db = await factory.openDatabase('my_file.db');

await db.close();
```

The file could be a relative path to the default platform database path
or an absolute path, pointing to a sqlite database.

## Options

In case you encounter some sqlite out of memory error or if you want to speed up initial load
you can modify the import page size (number of rows read at once).

```dart
// Change import page size (default is 1000)
// to use less memory
factory.sqfliteImportPageSize = 100;
```

```dart
// Change import page size (default is 1000)
// to speed up loading
factory.sqfliteImportPageSize = 100000;
```