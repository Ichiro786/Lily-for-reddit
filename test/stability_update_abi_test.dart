import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luli_for_reddit/features/updates/update_checker.dart';
import 'stability_api_errors_test.dart' show TestAdapter, jsonResponse;

Map<String, dynamic> asset(String abi, int size) => {
  'name': 'lily-$abi.apk',
  'size': size,
  'browser_download_url': 'https://github.com/download/$abi.apk',
};

void main() {
  final assets = [
    asset('x86_64', 999),
    asset('armeabi-v7a', 500),
    asset('arm64-v8a', 100),
  ];
  test('B13 chooses device ABI order rather than APK size', () {
    expect(
      UpdateChecker.compatibleApk(assets, ['arm64-v8a', 'armeabi-v7a']),
      'https://github.com/download/arm64-v8a.apk',
    );
    expect(
      UpdateChecker.compatibleApk(assets, ['armeabi-v7a']),
      'https://github.com/download/armeabi-v7a.apk',
    );
    expect(
      UpdateChecker.compatibleApk(assets, ['x86_64']),
      'https://github.com/download/x86_64.apk',
    );
  });
  test(
    'B13 fallback requires explicit universal asset; unknown/incompatible assets use release page',
    () {
      expect(
        UpdateChecker.compatibleApk([asset('x86_64', 999)], ['arm64-v8a']),
        isNull,
      );
      expect(UpdateChecker.compatibleApk([asset('release', 999)], []), isNull);
      expect(
        UpdateChecker.compatibleApk(
          [null, {}, asset('universal', 1)],
          ['arm64-v8a'],
        ),
        'https://github.com/download/universal.apk',
      );
      expect(
        UpdateChecker.compatibleApk(
          [
            {'name': 'lily-arm64-v8a.apk', 'browser_download_url': 'invalid'},
          ],
          ['arm64-v8a'],
        ),
        isNull,
      );
    },
  );
  test('B13 actual release check uses native supported-ABI bridge', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const channel = MethodChannel('lily/device');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'supportedAbis');
          return ['arm64-v8a', 'armeabi-v7a'];
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final dio = Dio();
    dio.httpClientAdapter = TestAdapter(
      (options) => jsonResponse({
        'tag_name': 'v1.0.2',
        'assets': assets,
        'html_url': 'https://github.com/release',
      }, 200),
    );
    final info = await UpdateChecker(dio: dio).check(installedVersion: '1.0.1');
    expect(info?.apkUrl, 'https://github.com/download/arm64-v8a.apk');
  });
}
