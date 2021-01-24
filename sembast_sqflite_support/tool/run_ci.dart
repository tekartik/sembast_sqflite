import 'package:process_run/shell.dart';
import 'package:dev_test/package.dart';
import 'package:path/path.dart';

Future main() async {
  // await packageRunCi('.');

  var shell = Shell().cd('..');

  await shell.run('flutter doctor');

  for (var dir in [
    '.',
    ...[
      'sembast_sqflite',
      'sembast_sqflite_common_test',
    ].map((dir) => join('..', dir))
  ]) {
    await packageRunCi(dir);
  }
}
