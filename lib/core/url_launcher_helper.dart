import 'package:url_launcher/url_launcher.dart';

bool isYouTubeUrl(String rawUrl) {
  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return false;
  }
  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  return host == 'youtube.com' || host == 'm.youtube.com' || host == 'youtu.be';
}

/// Reddit also emits relative community, user and comment permalinks.
Uri? redditLinkUri(String rawUrl) {
  var uri = Uri.tryParse(rawUrl.trim());
  if (uri == null || rawUrl.trim().isEmpty) return null;
  if (!uri.hasScheme && rawUrl.trim().startsWith('/')) {
    uri = Uri.parse('https://reddit.com').resolveUri(uri);
  }
  if ((uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty &&
      !RegExp(r'[\s/%\\]').hasMatch(uri.host)) {
    return uri;
  }
  if (uri.scheme == 'mailto' && uri.path.isNotEmpty) return uri;
  return null;
}

Future<bool> launchSmartUrl(String rawUrl) async {
  final uri = redditLinkUri(rawUrl);
  if (uri == null) return false;

  if (isYouTubeUrl(rawUrl)) {
    try {
      final openedInApp = await launchUrl(
        uri,
        mode: LaunchMode.inAppBrowserView,
      );
      if (openedInApp) return true;
    } catch (_) {
      // The platform may lack an in-app browser; try its external handler.
    }
  }

  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
