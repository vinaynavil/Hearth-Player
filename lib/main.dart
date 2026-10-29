import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:window_manager/window_manager.dart';

import 'screens/home_screen.dart';
import 'services/directory_browser_service.dart';
import 'theme/hearth_theme.dart';
import 'utils/app_env.dart';

String? _extractInitialVideoPath(List<String> args) {
  for (final rawArg in args) {
    final cleaned = rawArg.trim().replaceAll('"', '');
    if (cleaned.isEmpty || cleaned.startsWith('-')) continue;
    final dotIdx = cleaned.lastIndexOf('.');
    if (dotIdx == -1 || dotIdx == cleaned.length - 1) continue;
    final ext = cleaned.substring(dotIdx + 1).toLowerCase();
    if (!DirectoryBrowserService.videoExtensions.contains(ext)) continue;
    final file = File(cleaned);
    if (file.existsSync()) {
      return file.absolute.path;
    }
  }
  return null;
}

Future<void> main(List<String> args) async {
  // 1. Turn on Flutter's core engine
  WidgetsFlutterBinding.ensureInitialized();
  PaintingBinding.instance.imageCache.maximumSizeBytes = 30 * 1024 * 1024; // 30 MB
  PaintingBinding.instance.imageCache.maximumSize = 100;
  SystemChannels.skia.invokeMethod<void>(
    'Skia.setResourceCacheMaxBytes',
    32 * 1024 * 1024, // 32 MB
  );
  await Window.initialize();

  // 2. Turn on the libmpv video engine
  MediaKit.ensureInitialized();


  // 3. Turn on the Windows window controller for the main window
  await windowManager.ensureInitialized();

  final String windowTitle = AppEnv.windowTitle;

  // 4. Permanently hide the native OS title bar so Windows never flashes it
  final WindowOptions windowOptions = WindowOptions(
    center: true,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
    title: windowTitle,
  );

  final String? initialVideoPath = _extractInitialVideoPath(args);

  runApp(HearthApp(
    initialVideoPath: initialVideoPath,
    windowTitle: windowTitle,
  ));

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    try {
      if (initialVideoPath != null) {
        await Window.setEffect(
          effect: WindowEffect.disabled,
          dark: true,
        );
      } else {
        await Window.setEffect(
          effect: WindowEffect.mica,
          dark: true,
        );
      }
      debugPrint('Window setEffect called successfully');
    } catch (e) {
      debugPrint('Window setEffect FAILED: $e');
    }
    await Window.hideWindowControls();
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
    await windowManager.maximize();
    await windowManager.show();
    await windowManager.focus();
  });
}

class HearthApp extends StatelessWidget {
  final String? initialVideoPath;
  final String windowTitle;
  const HearthApp({
    super.key,
    this.initialVideoPath,
    this.windowTitle = 'Hearth',
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: windowTitle,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        canvasColor: Colors.transparent,
        textTheme: ThemeData.dark().textTheme.apply(
          fontFamily: HearthTheme.fontFamily,
          fontFamilyFallback: HearthTheme.fontFallback,
        ),
      ),
      home: HomeScreen(initialVideoPath: initialVideoPath),
    );
  }
}
