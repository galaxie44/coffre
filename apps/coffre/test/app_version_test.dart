import 'package:coffre/services/app_update_service.dart';
import 'package:coffre/utils/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('newer GitHub tags are detected', () {
    expect(AppVersion.isNewer('1.0.1', '1.0.0'), isTrue);
    expect(AppVersion.isNewer('v1.1.0', '1.0.9'), isTrue);
    expect(AppVersion.isNewer('1.0.0', '1.0.0'), isFalse);
    expect(AppVersion.isNewer('1.0.0', '1.0.1'), isFalse);
  });

  test('only official GitHub download URLs are trusted', () {
    expect(
      isTrustedUpdateUrl(
        Uri.parse(
          'https://github.com/galaxie44/coffre/releases/download/v1.0.1/Coffre-Setup-Windows.exe',
        ),
      ),
      isTrue,
    );
    expect(
      isTrustedUpdateUrl(Uri.parse('https://evil.example/Coffre-Setup-Windows.exe')),
      isFalse,
    );
    expect(
      isTrustedUpdateUrl(
        Uri.parse('https://github.com/someone-else/coffre/releases/download/v1/x.exe'),
      ),
      isFalse,
    );
  });

  test('tagFromLatestLocation reads the GitHub release tag', () {
    expect(
      AppUpdateService.tagFromLatestLocation(
        'https://github.com/galaxie44/coffre/releases/tag/v1.0.3',
      ),
      'v1.0.3',
    );
    expect(
      AppUpdateService.tagFromLatestLocation(
        '/galaxie44/coffre/releases/tag/v1.0.3',
      ),
      'v1.0.3',
    );
    expect(AppUpdateService.tagFromLatestLocation(null), isNull);
  });

  test('parseLatest reads the Windows installer asset', () {
    const json = '''
{
  "tag_name": "v1.0.2",
  "name": "Coffre 1.0.2 (test)",
  "draft": false,
  "assets": [
    {
      "name": "Coffre.apk",
      "browser_download_url": "https://github.com/galaxie44/coffre/releases/download/v1.0.2/Coffre.apk"
    },
    {
      "name": "Coffre-Setup-Windows.exe",
      "browser_download_url": "https://github.com/galaxie44/coffre/releases/download/v1.0.2/Coffre-Setup-Windows.exe"
    }
  ]
}
''';
    final windows = AppUpdateService.parseLatest(json);
    expect(windows, isNotNull);
    expect(windows!.version, '1.0.2');
    expect(windows.title, contains('test'));
    expect(windows.downloadUrl.path, contains('Coffre-Setup-Windows.exe'));
    final android = AppUpdateService.parseLatest(json, assetName: AppUpdateService.androidAsset);
    expect(android, isNotNull);
    expect(android!.fileName, 'Coffre.apk');
  });
}
