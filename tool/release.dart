// ignore_for_file: avoid_print
import 'dart:io';

/// Automated CLI release pipeline for Hearth.
///
/// Bumps version metadata across:
/// 1. pubspec.yaml
/// 2. lib/services/update_service.dart
/// 3. installer/hearth_setup.iss
///
/// Then compiles the release Windows binary and packages the single-file
/// Inno Setup installer.
Future<void> main(List<String> args) async {
  if (args.isEmpty || args.first == '--help' || args.first == '-h') {
    _printUsage();
    exit(1);
  }

  final String versionArg = args.first.trim();
  final bool bumpOnly = args.contains('--bump-only');

  final RegExp versionValidator = RegExp(r'^\d+\.\d+\.\d+$');
  if (!versionValidator.hasMatch(versionArg)) {
    print('Error: Invalid version format "$versionArg". Expected format: X.Y.Z (e.g., 1.0.0, 1.0.1)\n');
    _printUsage();
    exit(1);
  }

  final Directory projectRoot = _resolveProjectRoot();
  print('======================================================');
  print('🚀 Hearth Release Pipeline -> Version: $versionArg');
  print('Project Root: ${projectRoot.path}');
  print('======================================================\n');

  // ---------------------------------------------------------------------------
  // 1. Update pubspec.yaml
  // ---------------------------------------------------------------------------
  final File pubspecFile = File('${projectRoot.path}/pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    print('[ERROR] pubspec.yaml not found at ${pubspecFile.path}');
    exit(1);
  }
  final String pubspecContent = pubspecFile.readAsStringSync();
  final RegExp pubspecRegex =
      RegExp(r'^version:\s*(\d+\.\d+\.\d+)(?:\+(\d+))?', multiLine: true);
  final Match? pubspecMatch = pubspecRegex.firstMatch(pubspecContent);
  if (pubspecMatch == null) {
    print('[ERROR] Could not find version line in pubspec.yaml');
    exit(1);
  }

  final String oldVersion = pubspecMatch.group(1)!;
  final int oldBuild = int.tryParse(pubspecMatch.group(2) ?? '1') ?? 1;
  final int newBuild = (versionArg == oldVersion) ? oldBuild : (oldBuild + 1);
  final String updatedPubspec = pubspecContent.replaceFirst(
    pubspecRegex,
    'version: $versionArg+$newBuild',
  );
  pubspecFile.writeAsStringSync(updatedPubspec);
  print('✔ pubspec.yaml updated: version $versionArg+$newBuild (was $oldVersion+$oldBuild)');

  // ---------------------------------------------------------------------------
  // 2. Update lib/services/update_service.dart
  // ---------------------------------------------------------------------------
  final File updateServiceFile =
      File('${projectRoot.path}/lib/services/update_service.dart');
  if (!updateServiceFile.existsSync()) {
    print('[ERROR] update_service.dart not found at ${updateServiceFile.path}');
    exit(1);
  }
  final String updateServiceContent = updateServiceFile.readAsStringSync();
  final RegExp updateServiceRegex =
      RegExp(r"static const String currentVersion = '[^']+';");
  if (!updateServiceRegex.hasMatch(updateServiceContent)) {
    print('[ERROR] Could not find currentVersion in update_service.dart');
    exit(1);
  }
  final String updatedUpdateService = updateServiceContent.replaceFirst(
    updateServiceRegex,
    "static const String currentVersion = '$versionArg';",
  );
  updateServiceFile.writeAsStringSync(updatedUpdateService);
  print('✔ update_service.dart updated: currentVersion = "$versionArg"');

  // ---------------------------------------------------------------------------
  // 3. Update installer/hearth_setup.iss
  // ---------------------------------------------------------------------------
  final File issFile = File('${projectRoot.path}/installer/hearth_setup.iss');
  if (!issFile.existsSync()) {
    print('[ERROR] hearth_setup.iss not found at ${issFile.path}');
    exit(1);
  }
  final String issContent = issFile.readAsStringSync();
  final RegExp issVersionRegex = RegExp(r'#define MyAppVersion "[^"]+"');
  if (!issVersionRegex.hasMatch(issContent)) {
    print('[ERROR] Could not find #define MyAppVersion in hearth_setup.iss');
    exit(1);
  }
  var updatedIss = issContent.replaceFirst(
    issVersionRegex,
    '#define MyAppVersion "$versionArg"',
  );
  final RegExp issOutputBaseRegex = RegExp(r'OutputBaseFilename=[^\r\n]+');
  updatedIss = updatedIss.replaceFirst(
    issOutputBaseRegex,
    'OutputBaseFilename=Hearth_Setup_{#MyAppVersion}',
  );
  issFile.writeAsStringSync(updatedIss);
  print('✔ hearth_setup.iss updated: MyAppVersion = "$versionArg", OutputBaseFilename = Hearth_Setup_{#MyAppVersion}');

  if (bumpOnly) {
    print('\n[--bump-only specified] Version bumped across all 3 files successfully. Skipping builds.');
    exit(0);
  }

  // ---------------------------------------------------------------------------
  // Build Pipeline
  // ---------------------------------------------------------------------------

  // Safety: Terminate any running hearth.exe instance to prevent LNK1104 lock
  try {
    Process.runSync('taskkill', ['/F', '/IM', 'hearth.exe'], runInShell: true);
  } catch (_) {}

  // Step A: Static Analysis
  await _runStep(
    'Step A: Running dart analyze',
    'dart',
    ['analyze'],
    runInShell: true,
  );

  // Step B: Flutter Windows Release Build
  await _runStep(
    'Step B: Building Flutter Windows Release Binary',
    'flutter',
    ['build', 'windows', '--release'],
    runInShell: true,
  );

  // Step C: Inno Setup Compilation
  final String? isccPath = _findIsccPath();
  if (isccPath == null) {
    print('\n[ERROR] Inno Setup compiler (ISCC.exe) not found.');
    print('Install it with: winget install JRSoftware.InnoSetup -e --accept-package-agreements --accept-source-agreements');
    exit(1);
  }

  print('\n>>> Step C: Compiling Windows Installer with $isccPath...');
  final Process isccProcess = await Process.start(
    isccPath,
    ['installer\\hearth_setup.iss'],
    workingDirectory: projectRoot.path,
    mode: ProcessStartMode.inheritStdio,
    runInShell: false,
  );
  final int isccExitCode = await isccProcess.exitCode;
  if (isccExitCode != 0) {
    print('\n[ERROR] Inno Setup compiler failed with exit code $isccExitCode');
    exit(isccExitCode);
  }

  // Step D: Verification
  final File installerFile =
      File('${projectRoot.path}/build/installer/Hearth_Setup_$versionArg.exe');
  if (!installerFile.existsSync()) {
    print('\n[ERROR] Expected installer not found at ${installerFile.path}');
    exit(1);
  }

  final int sizeBytes = installerFile.lengthSync();
  final String sizeMb = (sizeBytes / (1024 * 1024)).toStringAsFixed(2);

  print('\n======================================================');
  print('🎉 Hearth $versionArg Release Build Complete!');
  print('Installer: ${installerFile.path}');
  print('Size:      $sizeMb MB ($sizeBytes bytes)');
  print('======================================================\n');
}

/// Locates the project root directory whether invoked from root or `tool/`.
Directory _resolveProjectRoot() {
  final File scriptFile = File(Platform.script.toFilePath());
  final Directory parent = scriptFile.parent;
  if (parent.path.endsWith('tool') || parent.path.endsWith('tool\\') || parent.path.endsWith('tool/')) {
    return parent.parent;
  }
  return Directory.current;
}

/// Discovers the path to `ISCC.exe`.
String? _findIsccPath() {
  final String? localAppData = Platform.environment['LOCALAPPDATA'];
  final List<String> candidates = <String>[
    if (localAppData != null)
      '$localAppData\\Programs\\Inno Setup 6\\ISCC.exe',
    r'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
    r'C:\Program Files\Inno Setup 6\ISCC.exe',
  ];

  for (final String path in candidates) {
    if (File(path).existsSync()) {
      return path;
    }
  }

  try {
    final ProcessResult result =
        Process.runSync('where', ['iscc'], runInShell: true);
    if (result.exitCode == 0) {
      final String output = (result.stdout as String).trim();
      if (output.isNotEmpty) {
        return output.split(RegExp(r'[\r\n]+')).first.trim();
      }
    }
  } catch (_) {}

  return null;
}

/// Helper to execute a CLI build command with inherited stdio.
Future<void> _runStep(
  String description,
  String executable,
  List<String> arguments, {
  bool runInShell = false,
}) async {
  print('\n>>> $description...');
  final Process process = await Process.start(
    executable,
    arguments,
    mode: ProcessStartMode.inheritStdio,
    runInShell: runInShell,
  );
  final int exitCode = await process.exitCode;
  if (exitCode != 0) {
    print('\n[ERROR] "$description" failed with exit code $exitCode');
    exit(exitCode);
  }
}

void _printUsage() {
  print('Hearth Release Automation Tool');
  print('Usage:');
  print('  dart run tool/release.dart <version> [--bump-only]');
  print('');
  print('Examples:');
  print('  dart run tool/release.dart 1.0.0 --bump-only   # Updates version numbers without building');
  print('  dart run tool/release.dart 1.0.1               # Bumps to 1.0.1, runs analyze, builds release & installer');
}
