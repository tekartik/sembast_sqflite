import 'package:process_run/shell.dart';

Future main() async {
  // print(Directory.current);
  var shell = Shell();
  await shell.run('''

dartanalyzer --fatal-warnings --fatal-infos .
dartfmt -n --set-exit-if-changed .
pub run test -p vm,chrome

''');
}
