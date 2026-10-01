import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final responseCacheProvider = Provider<ResponseCache>((ref) => ResponseCache());

/// Tiny on-disk JSON cache for GET responses, used as a fallback when the
/// network is unavailable (best-effort offline reading).
class ResponseCache {
  ResponseCache({
    Directory? directory,
    DateTime Function()? now,
    this.maxAge = const Duration(hours: 24),
  }) : _dir = directory,
       _now = now ?? DateTime.now;
  Directory? _dir;
  final DateTime Function() _now;
  final Duration maxAge;
  int _generation = 0;

  Future<Directory> _ensureDir() async {
    if (_dir != null) return _dir!;
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}/luli_cache');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return _dir = dir;
  }

  String _key(String key) => md5.convert(utf8.encode(key)).toString();

  Future<void> write(String key, Object? data) async {
    final generation = _generation;
    try {
      if (data == null) return;
      final dir = await _ensureDir();
      if (generation != _generation) return;
      final f = File('${dir.path}/${_key(key)}.json');
      await f.writeAsString(
        jsonEncode({
          'version': 2,
          'created': _now().millisecondsSinceEpoch,
          'data': data,
        }),
      );
    } catch (_) {
      /* caching is best-effort */
    }
  }

  Future<dynamic> read(String key) async {
    try {
      final dir = await _ensureDir();
      final f = File('${dir.path}/${_key(key)}.json');
      if (!f.existsSync()) return null;
      final entry = jsonDecode(await f.readAsString());
      if (entry is! Map || entry['version'] != 2 || entry['created'] is! int) {
        return null;
      }
      final age = _now().difference(
        DateTime.fromMillisecondsSinceEpoch(entry['created'] as int),
      );
      if (age.isNegative || age > maxAge) {
        await f.delete();
        return null;
      }
      return entry['data'];
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    _generation++;
    try {
      final dir = await _ensureDir();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      _dir = null;
    } catch (_) {}
  }
}
