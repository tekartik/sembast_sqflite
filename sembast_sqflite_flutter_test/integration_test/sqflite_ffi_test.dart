@TestOn('android || ios || macos')
library;

// Copyright 2019, the Chromium project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sembast_sqflite_common_test/sembast_sqflite_common_test.dart';
import 'package:sembast_sqflite_common_test/test.dart';
import 'package:sqflite/sqflite.dart' as sqflite_plugin;

void main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  var testContext = DatabaseTestContextSqfliteFfi();
  setUpAll(() async {
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      await testContext.sqfliteDatabaseFactory.setDatabasesPath(
          await sqflite_plugin.databaseFactorySqflitePlugin.getDatabasesPath());
    }
  });
  group('sembast_sqflite_ffi', () {
    defineSembastSqfliteTests(testContext);
  });
}
