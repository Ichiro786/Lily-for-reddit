import 'package:flutter/material.dart';

import '../../core/route_observer.dart';
import '../../models/listing.dart';

/// Generic infinite-scroll list backed by a `fetch(after)` callback.
class PagedList<T> extends StatefulWidget {
  const PagedList({
    super.key,
    required this.fetch,
    required this.itemBuilder,
    this.padding = const EdgeInsets.fromLTRB(10, 8, 10, 130),
    this.emptyLabel = 'Nothing here',
    this.requestKey,
  });

  final Future<Listing<T>> Function(String? after) fetch;
  final Widget Function(BuildContext, T) itemBuilder;
  final EdgeInsets padding;
  final String emptyLabel;
  final Object? requestKey;

  @override
  State<PagedList<T>> createState() => _PagedListState<T>();
}

class _PagedListState<T> extends State<PagedList<T>> with RouteAware {
  final _scroll = ScrollController();
  final _items = <T>[];
  String? _after;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;
  int _generation = 0;
  bool _refreshing = false;
  DateTime _lastLoaded = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 500) {
        _loadMore();
      }
    });
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) appRouteObserver.subscribe(this, route);
  }

  /// Returning to this list after a pushed route is popped: silently refresh if
  /// the data has gone stale (no full-screen spinner, keeps the user's place).
  @override
  void didPopNext() {
    if (!_loading &&
        DateTime.now().difference(_lastLoaded) > const Duration(minutes: 5)) {
      _load(silent: true);
    }
  }

  @override
  void didUpdateWidget(covariant PagedList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requestKey != widget.requestKey) _load();
  }

  @override
  void dispose() {
    _generation++;
    appRouteObserver.unsubscribe(this);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final generation = ++_generation;
    _refreshing = true;
    _loadingMore = false;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final listing = await widget.fetch(null);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items
          ..clear()
          ..addAll(listing.items);
        _after = listing.after;
        _loading = false;
        _lastLoaded = DateTime.now();
      });
    } catch (e) {
      // A silent (stale) refresh failing shouldn't blow away the list.
      if (mounted && generation == _generation && !silent) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _refreshing = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_refreshing ||
        _loading ||
        _loadingMore ||
        _after == null ||
        _after!.isEmpty) {
      return;
    }
    final generation = _generation;
    setState(() => _loadingMore = true);
    try {
      final listing = await widget.fetch(_after);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(listing.items);
        _after = listing.after;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _loadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Text('Could not load.\n$_error', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ],
      );
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Center(child: Text(widget.emptyLabel)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        controller: _scroll,
        padding: widget.padding,
        itemCount: _items.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          if (i == _items.length) {
            return _loadingMore
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : const SizedBox.shrink();
          }
          return widget.itemBuilder(context, _items[i]);
        },
      ),
    );
  }
}
