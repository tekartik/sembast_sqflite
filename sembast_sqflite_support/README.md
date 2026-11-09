# sembast_sqflite_support

Development tools of the `sembast_sqflite` repo (not a library, not published).
Run them from this folder:

| Command | What it does |
|---|---|
| `dart run tool/run_ci.dart` | `flutter doctor`, then the CI of `sembast_sqflite`, `sembast_sqflite_common_test` and `sembast_sqflite_flutter_test` (`packageRunCi` of `dev_build`: format, analyze, tests). |
| `dart run tool/quick_test.dart` | The ffi test of `sembast_sqflite_common_test` on the VM (`sembast_sqflite_common_ffi_test.dart`). |
| `dart run tool/setup_env.dart` | Linux only: installs `sqlite3` and `libsqlite3-dev` with `sudo apt-get`, needed by the ffi tests. |
