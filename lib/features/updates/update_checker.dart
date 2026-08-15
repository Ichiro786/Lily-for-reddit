import 'package:dio/dio.dart';
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
  final Dio _dio = Dio();

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
          installedVersion ?? await currentVersion());
      if (tag.isEmpty || current.isEmpty || !isNewerReleaseVersion(tag, current)) {
        return null;
      }
      // Pick the LARGEST .apk — that's the universal build (installs on any
      // device). Releases also carry smaller per-ABI split APKs for F-Droid.
      final assets = (data['assets'] as List?) ?? const [];
      String? apk;
      int bestSize = -1;
      for (final a in assets) {
        final m = a as Map;
        final name = (m['name'] as String? ?? '').toLowerCase();
        if (!name.endsWith('.apk')) continue;
        final size = (m['size'] as num?)?.toInt() ?? 0;
        if (size > bestSize) {
          bestSize = size;
          apk = m['browser_download_url'] as String?;
        }
      }
      return UpdateInfo(
        version: tag,
        url: data['html_url'] as String? ??
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
