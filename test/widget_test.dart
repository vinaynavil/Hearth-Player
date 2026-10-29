import 'package:flutter_test/flutter_test.dart';
import 'package:hearth/services/update_service.dart';

void main() {
  test('UpdateInfo serialization round-trip preserves fields', () {
    const info = UpdateInfo(
      latestVersion: '1.0.1',
      tagName: 'v1.0.1',
      releaseNotes: 'Custom Hearth icon and updater release',
      htmlUrl: 'https://github.com/vinaynavil/Hearth-Player/releases/tag/v1.0.1',
      exeDownloadUrl:
          'https://github.com/vinaynavil/Hearth-Player/releases/download/v1.0.1/Hearth_Setup_1.0.1.exe',
      exeFileName: 'Hearth_Setup_1.0.1.exe',
    );

    final map = info.toMap();
    final restored = UpdateInfo.fromMap(map);

    expect(restored.latestVersion, '1.0.1');
    expect(restored.tagName, 'v1.0.1');
    expect(restored.exeFileName, 'Hearth_Setup_1.0.1.exe');
  });
}
