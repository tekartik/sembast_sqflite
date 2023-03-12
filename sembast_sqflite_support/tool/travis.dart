import 'dart:io';

import 'package:path/path.dart';
import 'package:process_run/shell.dart';
import 'package:pub_semver/pub_semver.dart';

import 'linux_setup.dart' as linux_setup;

bool get runningOnTravis => Platform.environment['TRAVIS'] == 'true';

Future main() async {
  var nnbdEnabled = dartVersion > Version(2, 12, 0, pre: '0');
  if (nnbdEnabled) {
    // print(Directory.current);
    var shell = Shell();

    if (runningOnTravis) {
      await linux_setup.main();
    }

    await shell.run('''

dartanalyzer --fatal-warnings --fatal-infos .
dartfmt -n --set-exit-if-changed .
# pub run test

''');

    for (var dir in [
      'sembast_sqflite',
      'sembast_sqflite_common_test',
    ]) {
      shell = shell.pushd(join('..', dir));
      await shell.run('''
    
    pub get
    dart tool/travis.dart
    
        ''');
      shell = shell.popd();
    }
  }
}
