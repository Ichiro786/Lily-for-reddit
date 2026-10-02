import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/reddit_constants.dart';

class UpdateInfo {
  const UpdateInfo({required this.version, required this.url, this.apkUrl});
  final String version;
  final String url; // release page
  final String? apkUrl; // direct .apk asset if present
}

/// Checks the GitHub Releases API for a newer version. Distribution is via
/// GitHub (no Play Store), so this is the update channel.
class UpdateChecker {
  UpdateChecker({Dio? dio, Future<List<String>> Function()? supportedAbis})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
            ),
          ),
      _supportedAbis = supportedAbis ?? deviceAbis;
  final Dio _dio;
  final Future<List<String>> Function() _supportedAbis;

  static Future<List<String>> deviceAbis() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return [];
    try {
      return await const MethodChannel(
            'lily/device',
          ).invokeListMethod<String>('supportedAbis') ??
          [];
    } on PlatformException {
      return [];
    } on MissingPluginException {
      return [];
    }
  }

  static String? compatibleApk(List<dynamic> assets, List<String> abis) {
    String? match(String token) {
      final pattern = RegExp('(^|[-_.])${RegExp.escape(token)}([-.]|\$)');
      for (final asset in assets) {
        if (asset is! Map) continue;
        final name = asset['name'];
        final url = asset['browser_download_url'];
        if (name is! String || url is! String) continue;
        final lower = name.toLowerCase();
        final uri = Uri.tryParse(url);
        if (lower.endsWith('.apk') &&
            pattern.hasMatch(lower) &&
            uri != null &&
            uri.scheme == 'https' &&
            uri.host.isNotEmpty) {
          return url;
        }
      }
      return null;
    }

    for (final abi in abis) {
      if (!['arm64-v8a', 'armeabi-v7a', 'x86_64', 'x86'].contains(abi)) {
        continue;
      }
      final url = match(abi);
      if (url != null) return url;
    }
    return match('universal');
  }

  Future<String> currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  Future<UpdateInfo?> check({String? installedVersion}) async {
    try {
      final res = await _dio.get(
        'https://api.github.com/repos/${RedditConstants.githubRepo}/releases/latest',
        options: Options(headers: {'Accept': 'application/vnd.github+json'}),
      );
      final data = res.data as Map<String, dynamic>;
      final tag = normalizeReleaseVersion(data['tag_name'] as String? ?? '');
      final current = normalizeReleaseVersion(
        installedVersion ?? await currentVersion(),
      );
      if (tag.isEmpty ||
          current.isEmpty ||
          !isNewerReleaseVersion(tag, current)) {
        return null;
      }
      final assets = (data['assets'] as List?) ?? const [];
      final apk = compatibleApk(assets, await _supportedAbis());
      return UpdateInfo(
        version: tag,
        url:
            data['html_url'] as String? ??
            'https://github.com/${RedditConstants.githubRepo}/releases',
        apkUrl: apk,
      );
    } catch (_) {
      return null;
    }
  }

  /// Accepts tags such as `v1.2.0`, `1.2.0`, and `lily-v1.2.0`, while keeping
  /// the app-facing comparison on the three-part semantic version only.
  static String normalizeReleaseVersion(String raw) {
    final match = RegExp(r'(\d+\.\d+\.\d+)').firstMatch(raw.trim());
    return match?.group(1) ?? '';
  }

  static bool isNewerReleaseVersion(String a, String b) {
    final pa = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final pb = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }
}
