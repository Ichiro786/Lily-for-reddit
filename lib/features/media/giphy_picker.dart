import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/storage/secure_store.dart';
import '../../core/theme/motion_tokens.dart';
import '../../core/theme/shape_tokens.dart';
import '../../core/widgets/m3e_loading_indicator.dart';
import '../auth/auth_controller.dart';

final giphyDioFactoryProvider = Provider<Dio Function()>(
  (ref) =>
      () => Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
        ),
      ),
);

Future<String?> showGiphyPicker(BuildContext context, WidgetRef ref) async {
  // Capture dependencies before the secure-store await; the invoking composer
  // may be disposed while the platform storage operation completes.
  final store = ref.read(secureStoreProvider);
  final createDio = ref.read(giphyDioFactoryProvider);
  final key = await store.giphyKey;
  if (!context.mounted) return null;
  final dio = createDio();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    requestFocus: false,
    shape: const RoundedRectangleBorder(borderRadius: ShapeTokens.extraLarge),
    sheetAnimationStyle: MotionTokens.reduced(context)
        ? AnimationStyle.noAnimation
        : const AnimationStyle(duration: Duration(milliseconds: 300)),
    builder: (_) => _GiphySheet(apiKey: key, store: store, dio: dio),
  );
}

class GiphyResult {
  const GiphyResult({
    required this.preview,
    required this.full,
    required this.title,
  });
  final String preview, full, title;
}

List<GiphyResult> parseGiphyResults(Object? response) {
  if (response is! Map || response['data'] is! List) {
    throw const FormatException('Invalid GIPHY response');
  }
  String? url(Object? value) {
    if (value is! Map || value['url'] is! String) return null;
    final raw = value['url'] as String;
    final uri = Uri.tryParse(raw);
    return uri?.scheme == 'https' && uri!.host.isNotEmpty ? raw : null;
  }

  final results = <GiphyResult>[];
  for (final item in response['data'] as List) {
    if (item is! Map || item['images'] is! Map) continue;
    final images = item['images'] as Map;
    final full = url(images['original']);
    if (full == null) continue;
    results.add(
      GiphyResult(
        full: full,
        preview:
            url(images['fixed_width_small']) ??
            url(images['fixed_width']) ??
            full,
        title: item['title'] is String && (item['title'] as String).isNotEmpty
            ? item['title'] as String
            : 'GIF',
      ),
    );
  }
  return results;
}

String giphyFailureMessage(Object error) {
  final status = error is DioException ? error.response?.statusCode : null;
  return switch (status) {
    401 || 403 => 'GIPHY rejected this API key. Update your key and try again.',
    429 => 'GIPHY’s request limit was reached. Please try again later.',
    414 => 'Use a shorter GIF search.',
    _ =>
      error is FormatException
          ? 'GIPHY returned an unreadable response. Please retry.'
          : 'Could not reach GIPHY. Check your connection and retry.',
  };
}

class _GiphySheet extends StatefulWidget {
  const _GiphySheet({
    required this.apiKey,
    required this.store,
    required this.dio,
  });
  final String? apiKey;
  final SecureStore store;
  final Dio dio;
  @override
  State<_GiphySheet> createState() => _GiphySheetState();
}

class _GiphySheetState extends State<_GiphySheet> {
  final _query = TextEditingController();
  final _keyInput = TextEditingController();
  final _queryFocus = FocusNode();
  final _keyFocus = FocusNode();
  FocusNode get _activeFocus => _configuring ? _keyFocus : _queryFocus;
  Animation<double>? _entrance;
  Timer? _debounce;
  CancelToken? _request;
  int _revision = 0;
  late String _apiKey;
  late bool _configuring;
  bool _loading = false, _saving = false, _focused = false;
  String? _error;
  List<GiphyResult> _results = [];

  @override
  void initState() {
    super.initState();
    _apiKey = widget.apiKey?.trim() ?? '';
    _queryFocus.unfocus();
    _keyInput.text = _apiKey;
    _configuring = _apiKey.isEmpty;
    if (!_configuring) _load('');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (_entrance != animation) {
      _entrance?.removeStatusListener(_status);
      _entrance = animation;
      _entrance?.addStatusListener(_status);
    }
    if (animation == null || animation.status == AnimationStatus.completed) {
      _focusAfterEntry();
    }
  }

  void _status(AnimationStatus status) {
    if (status == AnimationStatus.completed) _focusAfterEntry();
  }

  void _focusAfterEntry() {
    if (_focused) return;
    _focused = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _activeFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _revision++;
    _debounce?.cancel();
    _request?.cancel();
    widget.dio.close(force: true);
    _entrance?.removeStatusListener(_status);
    _keyFocus.dispose();
    _queryFocus.dispose();
    _query.dispose();
    _keyInput.dispose();
    super.dispose();
  }

  void _configure() {
    _revision++;
    _debounce?.cancel();
    _request?.cancel();
    _keyInput.text = _apiKey;
    setState(() {
      _configuring = true;
      _loading = false;
      _error = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _activeFocus.requestFocus();
    });
  }

  Future<void> _saveKey() async {
    if (_saving) return;
    final key = _keyInput.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'Enter your GIPHY API key.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.store.saveGiphyKey(key);
      if (!mounted) return;
      _keyFocus.unfocus();
      setState(() {
        _apiKey = key;
        _configuring = false;
      });
      _load(_query.text.trim());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _activeFocus.requestFocus();
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save your key. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _getKey() async {
    try {
      final opened = await launchUrl(
        Uri.parse('https://developers.giphy.com/dashboard/'),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw StateError('Unavailable browser');
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Open developers.giphy.com to create your API key.',
        );
      }
    }
  }

  void _changed(String value) {
    _debounce?.cancel();
    _request?.cancel();
    _revision++;
    setState(() {
      _results = [];
      _loading = true;
      _error = null;
    });
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _load(value.trim()),
    );
  }

  Future<void> _load(String query) async {
    _debounce?.cancel();
    if (_apiKey.isEmpty || _configuring) return;
    final revision = ++_revision;
    _request?.cancel();
    final cancel = _request = CancelToken();
    setState(() {
      _loading = true;
      _error = null;
      _results = [];
    });
    try {
      final response = await widget.dio.get(
        'https://api.giphy.com/v1/gifs/${query.isEmpty ? 'trending' : 'search'}',
        cancelToken: cancel,
        queryParameters: {
          'api_key': _apiKey,
          if (query.isNotEmpty) 'q': query,
          'limit': 24,
          'rating': 'pg-13',
        },
      );
      if (!mounted || revision != _revision) return;
      final data = response.data;
      final meta = data is Map ? data['meta'] : null;
      final status = meta is Map ? meta['status'] : null;
      if (status is int && status >= 400) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: Response(
            requestOptions: response.requestOptions,
            statusCode: status,
          ),
        );
      }
      final results = parseGiphyResults(data);
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (error) {
      if (!mounted ||
          revision != _revision ||
          (error is DioException && CancelToken.isCancel(error))) {
        return;
      }
      setState(() {
        _loading = false;
        _error = giphyFailureMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final available = math.max(
      0.0,
      MediaQuery.sizeOf(context).height -
          keyboard -
          MediaQuery.paddingOf(context).top -
          64,
    );
    final sheetHeight = math.min(
      available,
      MediaQuery.sizeOf(context).height * 0.7,
    );
    final contentHeight = math.max(
      sheetHeight - 12,
      240 + MediaQuery.textScalerOf(context).scale(60),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: sheetHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SingleChildScrollView(
              child: SizedBox(
                height: contentHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _configuring ? 'Connect GIPHY' : 'Choose a GIF',
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                        if (!_configuring)
                          IconButton.filledTonal(
                            tooltip: 'GIPHY API key',
                            onPressed: _configure,
                            icon: const Icon(Icons.key_rounded),
                          ),
                        IconButton(
                          tooltip: 'Close GIF picker',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_configuring)
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Add your GIPHY API key to browse and search GIFs. Your key is saved securely on this device.',
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                key: const ValueKey('giphy-api-key'),
                                controller: _keyInput,
                                focusNode: _activeFocus,
                                obscureText: true,
                                autocorrect: false,
                                enableSuggestions: false,
                                readOnly: _saving,
                                onSubmitted: (_) => _saveKey(),
                                decoration: const InputDecoration(
                                  labelText: 'GIPHY API key',
                                  prefixIcon: Icon(Icons.key_rounded),
                                ),
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: _saving ? null : _saveKey,
                                icon: _saving
                                    ? const M3ELoadingIndicator.small()
                                    : const Icon(Icons.link_rounded),
                                label: const Text('Connect GIPHY'),
                              ),
                              TextButton.icon(
                                onPressed: _saving ? null : _getKey,
                                icon: const Icon(Icons.open_in_new_rounded),
                                label: const Text('Get a GIPHY API key'),
                              ),
                              if (_apiKey.isNotEmpty)
                                TextButton(
                                  onPressed: _saving
                                      ? null
                                      : () {
                                          _keyFocus.unfocus();
                                          setState(() {
                                            _configuring = false;
                                            _error = null;
                                          });
                                          _load(_query.text.trim());
                                          WidgetsBinding.instance
                                              .addPostFrameCallback((_) {
                                                if (mounted) {
                                                  _queryFocus.requestFocus();
                                                }
                                              });
                                        },
                                  child: const Text('Keep current key'),
                                ),
                              if (_error != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(
                                    _error!,
                                    style: TextStyle(color: cs.error),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      TextField(
                        controller: _query,
                        focusNode: _activeFocus,
                        textInputAction: TextInputAction.search,
                        inputFormatters: [LengthLimitingTextInputFormatter(50)],
                        onChanged: _changed,
                        onSubmitted: (value) => _load(value.trim()),
                        decoration: const InputDecoration(
                          hintText: 'Search GIFs',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _loading
                            ? const Center(child: M3ELoadingIndicator())
                            : _error != null
                            ? SingleChildScrollView(
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      child: Text(
                                        _error!,
                                        style: TextStyle(color: cs.error),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    FilledButton.tonalIcon(
                                      onPressed: () =>
                                          _load(_query.text.trim()),
                                      icon: const Icon(Icons.refresh_rounded),
                                      label: const Text('Retry'),
                                    ),
                                    TextButton(
                                      onPressed: _configure,
                                      child: const Text('Update API key'),
                                    ),
                                  ],
                                ),
                              )
                            : _results.isEmpty
                            ? const Center(
                                child: Text(
                                  'No GIFs found. Try another search.',
                                ),
                              )
                            : GridView.builder(
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 160,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                    ),
                                itemCount: _results.length,
                                itemBuilder: (context, index) {
                                  final gif = _results[index];
                                  return Semantics(
                                    button: true,
                                    label: gif.title,
                                    child: Material(
                                      color: cs.surfaceContainerHigh,
                                      borderRadius: ShapeTokens.medium,
                                      clipBehavior: Clip.antiAlias,
                                      child: InkWell(
                                        onTap: () =>
                                            Navigator.pop(context, gif.full),
                                        child: CachedNetworkImage(
                                          imageUrl: gif.preview,
                                          memCacheWidth: 200,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) =>
                                              const Icon(
                                                Icons.broken_image_outlined,
                                              ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Powered by GIPHY',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
