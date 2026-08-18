import 'package:url_launcher/url_launcher.dart';

bool isYouTubeUrl(String rawUrl) {
  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return false;
  }
  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  return host == 'youtube.com' ||
      host == 'm.youtube.com' ||
      host == 'youtu.be';
}

Future<bool> launchSmartUrl(String rawUrl) async {
  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null) return false;

  if (isYouTubeUrl(rawUrl)) {
    final openedInApp = await launchUrl(
      uri,
      mode: LaunchMode.inAppBrowserView,
    );
    if (openedInApp) return true;
  }

  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
