import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import '../utils/app_env.dart';

/// Represents release metadata fetched from GitHub Releases.
class UpdateInfo {
  /// Normalized version string without leading 'v' (e.g. "1.0.1").
  final String latestVersion;

  /// Raw tag from GitHub (e.g. "v1.0.1").
  final String tagName;

  /// Markdown release notes from the GitHub release body.
  final String releaseNotes;

  /// Direct browser URL to the GitHub release page.
  final String htmlUrl;

  /// Direct download URL for the Windows `.exe` installer asset, if present.
  final String? exeDownloadUrl;

  /// File name of the `.exe` asset (e.g. "Hearth_Setup_1.0.1.exe").
  final String? exeFileName;

  const UpdateInfo({
    required this.latestVersion,
    required this.tagName,
    required this.releaseNotes,
    required this.htmlUrl,
    this.exeDownloadUrl,
    this.exeFileName,
  });

  /// Converts this [UpdateInfo] into a JSON-compatible map for caching.
  Map<String, dynamic> toMap() => {
        'latestVersion': latestVersion,
        'tagName': tagName,
        'releaseNotes': releaseNotes,
        'htmlUrl': htmlUrl,
        'exeDownloadUrl': exeDownloadUrl,
        'exeFileName': exeFileName,
      };

  /// Constructs an [UpdateInfo] instance from a cached JSON map.
  factory UpdateInfo.fromMap(Map<String, dynamic> map) => UpdateInfo(
        latestVersion: map['latestVersion'] as String? ?? '',
        tagName: map['tagName'] as String? ?? '',
        releaseNotes: map['releaseNotes'] as String? ?? '',
        htmlUrl: map['htmlUrl'] as String? ?? '',
        exeDownloadUrl: map['exeDownloadUrl'] as String?,
        exeFileName: map['exeFileName'] as String?,
      );
}

/// Service responsible for checking GitHub Releases for updates on every
/// application startup and downloading/launching the installer.
class UpdateService {
  static const String currentVersion = '1.0.6';
  static const String githubOwner = 'vinaynavil';
  static const String githubRepo = 'Hearth-Player';

  static const String _stateFileName = 'update_state.json';

  /// Single shared instance of [UpdateService].
  static final UpdateService instance = UpdateService._internal();

  UpdateService._internal();

  /// Factory constructor returning the singleton instance.
  factory UpdateService() => instance;


  /// Returns the JSON file used to store update timestamps and snooze state.
  static Future<File> _getStateFile() async {
    final Directory appSupportDir = await AppEnv.getSupportDirectory();
    return File(p.join(appSupportDir.path, _stateFileName));
  }

  /// Reads and parses the persistent state from `update_state.json`.
  static Future<Map<String, dynamic>> _readState() async {
    try {
      final File file = await _getStateFile();
      if (await file.exists()) {
        final String content = await file.readAsString();
        final dynamic decoded = jsonDecode(content);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  /// Writes the current state map to `update_state.json`.
  static Future<void> _writeState(Map<String, dynamic> state) async {
    try {
      final File file = await _getStateFile();
      await file.writeAsString(jsonEncode(state), flush: true);
    } catch (_) {}
  }

  /// Compares [remote] and [current] version strings semantically.
  ///
  /// Returns `true` if [remote] is strictly higher than [current].
  static bool _isNewerVersion(String remote, String current) {
    try {
      final List<int> remoteParts = _parseVersionParts(remote);
      final List<int> currentParts = _parseVersionParts(current);

      final int maxLen = remoteParts.length > currentParts.length
          ? remoteParts.length
          : currentParts.length;

      for (int i = 0; i < maxLen; i++) {
        final int r = i < remoteParts.length ? remoteParts[i] : 0;
        final int c = i < currentParts.length ? currentParts[i] : 0;
        if (r > c) return true;
        if (r < c) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Splits a version string into integer segments, stripping prefixes,
  /// build numbers (+...), and pre-release tags (-...).
  static List<int> _parseVersionParts(String version) {
    String cleaned = version.trim();
    if (cleaned.startsWith('v') || cleaned.startsWith('V')) {
      cleaned = cleaned.substring(1);
    }
    final int plusIdx = cleaned.indexOf('+');
    if (plusIdx != -1) {
      cleaned = cleaned.substring(0, plusIdx);
    }
    final int dashIdx = cleaned.indexOf('-');
    if (dashIdx != -1) {
      cleaned = cleaned.substring(0, dashIdx);
    }

    return cleaned
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
  }

  /// Checks GitHub Releases for a newer version on every application startup,
  /// unless the user explicitly clicked "Hide for 24 hours" (`snooze_until_ms`).
  ///
  /// Wrapped in try/catch to ensure network or parsing issues never crash the app.
  Future<UpdateInfo?> checkForUpdateOnStartup({bool force = false}) async {
    try {
      if (githubOwner.isEmpty || githubOwner == 'YOUR_GITHUB_USERNAME') {
        return null;
      }

      final Map<String, dynamic> state = await _readState();
      final int now = DateTime.now().millisecondsSinceEpoch;

      if (!force) {
        final int? snoozeUntil = state['snooze_until_ms'] as int?;
        if (snoozeUntil != null && now < snoozeUntil) {
          return null;
        }
      }

      final HttpClient client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);

      try {
        Map<String, dynamic>? releaseData = await _fetchJsonMap(
          client,
          'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest',
        );

        // Fallback if /releases/latest returns 404 (e.g. pre-release tag)
        if (releaseData == null) {
          final List<dynamic>? releasesList = await _fetchJsonList(
            client,
            'https://api.github.com/repos/$githubOwner/$githubRepo/releases?per_page=5',
          );
          if (releasesList != null) {
            for (final dynamic item in releasesList) {
              if (item is Map<String, dynamic> && item['draft'] != true) {
                releaseData = item;
                break;
              }
            }
          }
        }

        if (releaseData != null) {
          state['last_checked_ms'] = DateTime.now().millisecondsSinceEpoch;

          final String rawTag =
              (releaseData['tag_name'] as String?)?.trim() ?? '';
          String normalizedVersion = rawTag;
          if (normalizedVersion.startsWith('v') ||
              normalizedVersion.startsWith('V')) {
            normalizedVersion = normalizedVersion.substring(1);
          }

          final bool isNewer =
              _isNewerVersion(normalizedVersion, currentVersion);

          String? exeUrl;
          String? exeName;
          final dynamic assets = releaseData['assets'];
          if (assets is List) {
            for (final dynamic asset in assets) {
              if (asset is Map<String, dynamic>) {
                final String name = (asset['name'] as String?) ?? '';
                if (name.toLowerCase().endsWith('.exe')) {
                  exeUrl = asset['browser_download_url'] as String?;
                  exeName = name;
                  break;
                }
              }
            }
          }

          final String bodyText =
              (releaseData['body'] as String?)?.trim() ?? '';
          final String releaseNotes = bodyText.isNotEmpty
              ? bodyText
              : 'No release notes provided for this version.';
          final String htmlUrl = (releaseData['html_url'] as String?) ??
              'https://github.com/$githubOwner/$githubRepo/releases';

          final UpdateInfo updateInfo = UpdateInfo(
            latestVersion: normalizedVersion,
            tagName: rawTag,
            releaseNotes: releaseNotes,
            htmlUrl: htmlUrl,
            exeDownloadUrl: exeUrl,
            exeFileName: exeName,
          );

          if (isNewer) {
            state['cached_release'] = updateInfo.toMap();
            await _writeState(state);
            return updateInfo;
          } else {
            state.remove('cached_release');
            await _writeState(state);
            return null;
          }
        }
      } finally {
        client.close();
      }
    } catch (_) {
      // Offline, network drop, or GitHub API rate limit: fail silently.
    }
    return null;
  }

  /// Snoozes update reminders for 24 hours by recording the future timestamp.
  Future<void> snoozeFor24Hours() async {
    final Map<String, dynamic> state = await _readState();
    state['snooze_until_ms'] =
        DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch;
    await _writeState(state);
  }

  /// Downloads the `.exe` asset if available and executes the installer,
  /// exiting the application cleanly. Falls back to opening the release page.
  Future<void> downloadAndInstallUpdate(
    UpdateInfo info, {
    required void Function(double progress) onProgress,
  }) async {
    final String? downloadUrl = info.exeDownloadUrl;
    if (downloadUrl == null || downloadUrl.isEmpty) {
      await Process.run('rundll32', ['url.dll,FileProtocolHandler', info.htmlUrl]);
      return;
    }

    final HttpClient client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    try {
      final Uri uri = Uri.parse(downloadUrl);
      final HttpClientRequest request = await client.getUrl(uri);
      request.followRedirects = true;
      request.maxRedirects = 10;
      request.headers.set('User-Agent', 'Hearth-Windows-App');

      final HttpClientResponse response = await request.close();
      if (response.statusCode != 200) {
        await Process.run(
            'rundll32', ['url.dll,FileProtocolHandler', info.htmlUrl]);
        return;
      }

      final int totalBytes = response.contentLength;
      int receivedBytes = 0;

      final String targetFileName =
          info.exeFileName ?? 'Hearth_Setup_${info.latestVersion}.exe';
      final File tempFile =
          File(p.join(Directory.systemTemp.path, targetFileName));
      final IOSink sink = tempFile.openWrite();

      await for (final List<int> chunk in response) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          onProgress((receivedBytes / totalBytes).clamp(0.0, 1.0));
        }
      }

      await sink.flush();
      await sink.close();

      await Process.start(tempFile.path, [], mode: ProcessStartMode.detached);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      exit(0);
    } catch (_) {
      try {
        await Process.run(
            'rundll32', ['url.dll,FileProtocolHandler', info.htmlUrl]);
      } catch (_) {}
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>?> _fetchJsonMap(
    HttpClient client,
    String url,
  ) async {
    final HttpClientRequest request = await client.getUrl(Uri.parse(url));
    request.headers.set('User-Agent', 'Hearth-Windows-App');
    request.headers.set('Accept', 'application/vnd.github+json');
    request.headers.set('Cache-Control', 'no-cache');

    final HttpClientResponse response =
        await request.close().timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final String body = await response.transform(utf8.decoder).join();
      final dynamic decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } else {
      await response.drain<void>();
    }
    return null;
  }

  static Future<List<dynamic>?> _fetchJsonList(
    HttpClient client,
    String url,
  ) async {
    final HttpClientRequest request = await client.getUrl(Uri.parse(url));
    request.headers.set('User-Agent', 'Hearth-Windows-App');
    request.headers.set('Accept', 'application/vnd.github+json');
    request.headers.set('Cache-Control', 'no-cache');

    final HttpClientResponse response =
        await request.close().timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final String body = await response.transform(utf8.decoder).join();
      final dynamic decoded = jsonDecode(body);
      if (decoded is List<dynamic>) {
        return decoded;
      }
    } else {
      await response.drain<void>();
    }
    return null;
  }
}
