import 'package:sembast_sqflite/sembast_sqflite.dart';
import 'package:test/test.dart';

Future main() async {
  group('import', () {
    test('open', () async {
      getDatabaseFactorySqflite(null);
    });
  });
}
