@TestOn('vm || browser')
library;

import 'package:sembast_sqflite/sembast_sqflite.dart';
import 'package:test/test.dart';

var testPath = '.dart_tool/sembast_test/sembas_io_api/databases';

Future main() async {
  group('sembast_sqflite_api', () {
    test('getDatabaseFactorySqflite', () async {
      // ignore: unnecessary_statements
      getDatabaseFactorySqflite;
    });
  });
}
