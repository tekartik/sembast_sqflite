# sembast_sqflite_flutter_test

Flutter integration tests of [sembast_sqflite](../sembast_sqflite) on a
device: the shared sembast suites (`sembast_test`, through
`defineSembastSqfliteTests` of
[sembast_sqflite_common_test](../sembast_sqflite_common_test)) on the sqflite
plugin, and on sqflite ffi running on the device.

Not published. The same suites run on the Dart VM (ffi) in
sembast_sqflite_common_test: use this app for Android, iOS or macOS.

## Setup

The platform folders are not committed: create the ones you need first.

```shell
flutter create . --platforms=android,ios,macos
```

## Run

Start a device (Android emulator, iOS simulator) or use macOS, then:

```shell
# the sqflite plugin
SQFLITE_TEST_DEVICE_ID=emulator-5554 dart run tool/integration_test_plugin_run.dart
# sqflite ffi on the device
SQFLITE_TEST_DEVICE_ID=emulator-5554 dart run tool/integration_test_ffi_run.dart
```

`SQFLITE_TEST_DEVICE_ID` is the `flutter devices` id (`macos` for macOS):
set it whenever more than one device is available (the desktop and Chrome
count). Each tool runs `flutter drive --no-pub`: run `flutter pub get`
first.

| Runner | Factory |
|---|---|
| `integration_test/sqflite_test.dart` | `databaseFactorySqflitePlugin` (sqflite) |
| `integration_test/sqflite_ffi_test.dart` | `databaseFactoryFfi`, in the plugin's databases folder |
