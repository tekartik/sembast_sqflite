import 'dart:io';

import 'package:dev_test/package.dart';
import 'package:path/path.dart';
import 'package:process_run/shell.dart';
import 'package:pub_semver/pub_semver.dart';

Future main() async {
  var shell = Shell();

  await shell.run('flutter doctor');

  final nnbdEnabled = dartVersion > Version(2, 12, 0, pre: '0');
  if (nnbdEnabled) {
    for (var dir in [
      'sembast_sqflite',
      'sembast_sqflite_common_test',
      'sembast_sqflite_flutter_test',
    ]) {
      await packageRunCi(join('..', dir));
    }
  } else {
    stderr.writeln('ci test skipped for $dartVersion');
  }
}
