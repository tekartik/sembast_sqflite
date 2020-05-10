## Sembast sqflite setup

### FFI setup (Flutter Desktop/VM) 

Supports Windows/Linux/MacOS Flutter/VM

* Flutter and VM context supported.
* Flutter context not needed.

*FFI is not tested nor supported on mobile yet*

```dart
import 'package:sembast_sqflite/sembast_sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sqflite_ffi;

export 'package:sembast/sembast.dart';

/// Sembast sqflite ffi based database factory.
///
/// Supports Windows/Linux/MacOS for now.
final databaseFactorySqfliteFfi =
    getDatabaseFactorySqflite(sqflite_ffi.databaseFactoryFfi);
```

A sembast database can be opened/created this way:

```dart
var factory = databaseFactorySqflite;
var db = await factory.openDatabase('test.db');

await db.close();
```