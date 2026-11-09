## 2.2.4+1

* Documentation: fix the README example (no sembast_test import), platforms, setup,
  database path notes, ffi setup doc fix, dartdoc, skill updated
* Fix delta reads (changes made by another instance) with an async codec, and
  read errors (such as a corrupted value) now complete the read with the error
  instead of hanging.
* Require sembast 3.9.0 (endless write retry after another instance compacted
  the database).
* New databases: `store` and `key` are `NOT NULL`, no duplicate `record` index.
* Document the single sqflite connection per path and the plain sqlite file
  limits.

## 2.2.3

* Add `sembast-sqflite-setup` agent skill in `skills/`, installable with `dart run skills@ get`

## 2.2.2

* Require dart 3.12

## 2.2.1+1

* Require dart 3.10

## 2.2.1

* Require dart 3.7

## 2.2.0+4

* dart 3 support
* require dart 3.5

## 2.1.1

* Support Async content codec

## 2.1.0+1

* support strict-casts

## 2.0.1

* Add `DatabaseFactory.sqfliteImportPageSize` to control how data is imported from sqlite

## 2.0.0+1

* `nnbd` support

## 1.0.0+1

* First stable version
* pre-nnbd only

## 0.2.0+2

* Add `Blob` and `Timestamp` support

## 0.1.0

* Initial revision
