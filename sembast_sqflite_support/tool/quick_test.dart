import 'package:path/path.dart';
import 'package:process_run/shell.dart';

Future main() async {
  var shell = Shell().pushd('..');

  shell = shell.pushd(join('sembast_sqflite_common_test'));
  await shell.run('''

dart pub get
dart test -p vm test/sembast_sqflite_common_ffi_test.dart

    ''');
  shell = shell.popd();
}
