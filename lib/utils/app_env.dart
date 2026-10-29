import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppEnv {
  AppEnv._();

  /// Returns true when running via `flutter run` (debug) or directly from
  /// the local workspace `\build\windows\` directory.
  static final bool isWorkspaceBuild = kDebugMode ||
      Platform.resolvedExecutable.toLowerCase().contains(r'\build\windows\');

  /// Window title to distinguish workspace builds from the installed release.
  static String get windowTitle =>
      isWorkspaceBuild ? 'Hearth (Dev)' : 'Hearth';

  /// Returns the isolated Application Support directory:
  /// - Production installed build: `%APPDATA%\Vinay Navil\Hearth`
  /// - Workspace dev build: `%APPDATA%\Vinay Navil\Hearth\dev`
  static Future<Directory> getSupportDirectory() async {
    final Directory baseDir = await getApplicationSupportDirectory();
    final Directory targetDir =
        isWorkspaceBuild ? Directory(p.join(baseDir.path, 'dev')) : baseDir;
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    return targetDir;
  }
}
