import 'dart:ffi';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Provides dynamic detection and resolution of Windows user folders,
/// physical disk drives, and byte size formatting.
class SystemDriveService {
  /// Resolves Windows user folders from the OS environment
  /// and returns candidates that actually exist on disk.
  static List<Map<String, dynamic>> getQuickAccessPaths() {
    final String? userProfile =
        Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
    if (userProfile == null || userProfile.isEmpty) return [];

    final String sep = Platform.pathSeparator;
    final List<Map<String, dynamic>> candidates = [
      {
        'name': 'Videos',
        'icon': Symbols.video_library,
        'path': '$userProfile${sep}Videos',
      },
      {
        'name': 'Downloads',
        'icon': Symbols.download,
        'path': '$userProfile${sep}Downloads',
      },
      {
        'name': 'Music',
        'icon': Symbols.music_note,
        'path': '$userProfile${sep}Music',
      },
      {
        'name': 'Documents',
        'icon': Symbols.folder,
        'path': '$userProfile${sep}Documents',
      },
    ];

    return candidates
        .where((item) => Directory(item['path'] as String).existsSync())
        .toList();
  }

  /// Queries Windows for local fixed and removable disks via native Win32 API
  /// and returns their display metadata, capacity, and free space.
  static Future<List<Map<String, dynamic>>> loadRealDrives() async {
    const List<Color> drivePalette = [
      Color(0xFF4F6EF7),
      Color(0xFFFB923C),
      Color(0xFF34D399),
      Color(0xFFA855F7),
    ];

    final List<Map<String, dynamic>> loadedDrives = [];

    // The drive hosting the user profile is already represented via Quick
    // Access, so it's excluded here to avoid showing it twice.
    final String? userProfile =
        Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
    final String? systemDriveLetter = (userProfile != null &&
            userProfile.length >= 2 &&
            userProfile[1] == ':')
        ? userProfile.substring(0, 2).toUpperCase()
        : null;

    if (Platform.isWindows) {
      try {
        final _Kernel32 k32 = _Kernel32.instance;
        final int driveMask = k32.getLogicalDrives();
        if (driveMask != 0) {
          final Pointer<Void> mem = k32.globalAlloc(0x0040, 1024);
          if (mem.address != 0) {
            try {
              final Pointer<Uint16> rootPathPtr = mem.cast<Uint16>();
              final Pointer<Uint16> volumeNamePtr =
                  (mem.cast<Uint8>() + 64).cast<Uint16>();
              final Pointer<Uint64> freeBytesAvail =
                  (mem.cast<Uint8>() + 600).cast<Uint64>();
              final Pointer<Uint64> totalBytesPtr =
                  (mem.cast<Uint8>() + 608).cast<Uint64>();
              final Pointer<Uint64> totalFreeBytesPtr =
                  (mem.cast<Uint8>() + 616).cast<Uint64>();

              for (int i = 0; i < 26; i++) {
                if ((driveMask & (1 << i)) == 0) continue;

                final String letter = String.fromCharCode(0x41 + i);
                final String deviceId = '$letter:';
                if (systemDriveLetter != null &&
                    deviceId.toUpperCase() == systemDriveLetter) {
                  continue;
                }

                rootPathPtr[0] = letter.codeUnitAt(0);
                rootPathPtr[1] = 0x003A; // ':'
                rootPathPtr[2] = 0x005C; // '\'
                rootPathPtr[3] = 0;

                final int driveType = k32.getDriveTypeW(rootPathPtr);
                // DRIVE_REMOVABLE = 2, DRIVE_FIXED = 3
                if (driveType != 2 && driveType != 3) {
                  continue;
                }

                volumeNamePtr[0] = 0;
                final int volResult = k32.getVolumeInformationW(
                  rootPathPtr,
                  volumeNamePtr,
                  260,
                  nullptr,
                  nullptr,
                  nullptr,
                  nullptr,
                  0,
                );

                String volumeName = '';
                if (volResult != 0) {
                  final StringBuffer sb = StringBuffer();
                  for (int j = 0; j < 260; j++) {
                    final int charCode = volumeNamePtr[j];
                    if (charCode == 0) break;
                    sb.writeCharCode(charCode);
                  }
                  volumeName = sb.toString().trim();
                }

                final int spaceResult = k32.getDiskFreeSpaceExW(
                  rootPathPtr,
                  freeBytesAvail,
                  totalBytesPtr,
                  totalFreeBytesPtr,
                );

                String? freeSpaceText;
                double? usedProgress;
                if (spaceResult != 0) {
                  final int totalBytes = totalBytesPtr.value;
                  final int freeBytes = freeBytesAvail.value;
                  if (totalBytes > 0) {
                    final int usedBytes =
                        (totalBytes - freeBytes).clamp(0, totalBytes);
                    usedProgress = (usedBytes / totalBytes).clamp(0.0, 1.0);
                    freeSpaceText = '${formatBytes(freeBytes)} free';
                  }
                }

                final String displayName = volumeName.isNotEmpty
                    ? '$volumeName ($deviceId)'
                    : 'Local Disk ($deviceId)';

                loadedDrives.add({
                  'name': displayName,
                  'path': '$deviceId\\',
                  'freeSpace': freeSpaceText,
                  'progress': usedProgress,
                  'color':
                      drivePalette[loadedDrives.length % drivePalette.length],
                });
              }
            } finally {
              k32.globalFree(mem);
            }
          }
        }
      } catch (_) {
        // Ignore if native drive query fails
      }
    }

    return loadedDrives;
  }

  /// Formats raw byte counts into human-readable GB / TB / MB strings.
  static String formatBytes(int bytes) {
    const double gb = 1024 * 1024 * 1024;
    const double tb = gb * 1024;
    if (bytes >= tb) {
      return '${(bytes / tb).toStringAsFixed(2)} TB';
    }
    if (bytes >= gb) {
      return '${(bytes / gb).toStringAsFixed(1)} GB';
    }
    final double mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(0)} MB';
  }
}

class _Kernel32 {
  _Kernel32._() {
    _lib = DynamicLibrary.open('kernel32.dll');
    getLogicalDrives = _lib.lookupFunction<Uint32 Function(), int Function()>(
      'GetLogicalDrives',
    );
    getDriveTypeW = _lib.lookupFunction<
      Uint32 Function(Pointer<Uint16>),
      int Function(Pointer<Uint16>)
    >('GetDriveTypeW');
    getVolumeInformationW = _lib.lookupFunction<
      Int32 Function(
        Pointer<Uint16>,
        Pointer<Uint16>,
        Uint32,
        Pointer<Uint32>,
        Pointer<Uint32>,
        Pointer<Uint32>,
        Pointer<Uint16>,
        Uint32,
      ),
      int Function(
        Pointer<Uint16>,
        Pointer<Uint16>,
        int,
        Pointer<Uint32>,
        Pointer<Uint32>,
        Pointer<Uint32>,
        Pointer<Uint16>,
        int,
      )
    >('GetVolumeInformationW');
    getDiskFreeSpaceExW = _lib.lookupFunction<
      Int32 Function(
        Pointer<Uint16>,
        Pointer<Uint64>,
        Pointer<Uint64>,
        Pointer<Uint64>,
      ),
      int Function(
        Pointer<Uint16>,
        Pointer<Uint64>,
        Pointer<Uint64>,
        Pointer<Uint64>,
      )
    >('GetDiskFreeSpaceExW');
    globalAlloc = _lib.lookupFunction<
      Pointer<Void> Function(Uint32, IntPtr),
      Pointer<Void> Function(int, int)
    >('GlobalAlloc');
    globalFree = _lib.lookupFunction<
      Pointer<Void> Function(Pointer<Void>),
      Pointer<Void> Function(Pointer<Void>)
    >('GlobalFree');
  }

  static _Kernel32? _instance;
  static _Kernel32 get instance => _instance ??= _Kernel32._();

  late final DynamicLibrary _lib;
  late final int Function() getLogicalDrives;
  late final int Function(Pointer<Uint16>) getDriveTypeW;
  late final int Function(
    Pointer<Uint16>,
    Pointer<Uint16>,
    int,
    Pointer<Uint32>,
    Pointer<Uint32>,
    Pointer<Uint32>,
    Pointer<Uint16>,
    int,
  ) getVolumeInformationW;
  late final int Function(
    Pointer<Uint16>,
    Pointer<Uint64>,
    Pointer<Uint64>,
    Pointer<Uint64>,
  ) getDiskFreeSpaceExW;
  late final Pointer<Void> Function(int, int) globalAlloc;
  late final Pointer<Void> Function(Pointer<Void>) globalFree;
}
