@TestOn('android || ios || macos')
library;

// Copyright 2019, the Chromium project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sembast_sqflite_common_test/sembast_sqflite_common_test.dart';
import 'package:sembast_sqflite_flutter_test/test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  var testContext = DatabaseTestContextSqflitePlugin();

  group('sembast_sqflite_plugin', () {
    defineSembastSqfliteTests(testContext);
  });
}
