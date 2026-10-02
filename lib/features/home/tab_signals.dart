import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// React to the first vertical gesture, including one that starts at the top.
/// Scroll updates also cover a drag that crosses the top threshold without
/// emitting another UserScrollNotification. Nested media/chip scrollers do
/// not control the shell chrome.
bool scrollChromeVisible(ScrollNotification notification, bool visible) {
  if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
    return visible;
  }
  final metrics = notification.metrics;
  if (metrics.pixels < metrics.minScrollExtent) return true;
  if (notification is UserScrollNotification) {
    if (notification.direction == ScrollDirection.reverse) return false;
    if (notification.direction == ScrollDirection.forward) return true;
  }
  if (notification is ScrollUpdateNotification) {
    final delta = notification.scrollDelta ?? 0;
    if (delta > 0) return false;
    if (delta < 0) return true;
  }
  if (notification is ScrollEndNotification &&
      metrics.pixels <= metrics.minScrollExtent) {
    return true;
  }
  return visible;
}

/// Bumped when a bottom-nav tab is re-tapped while already active, so that tab's
/// scrollable can scroll to top. Keyed by tab index (1 = Explore, 2 = Inbox).
/// (The Posts tab uses its own `frontpageScrollSignalProvider`, which also
/// refreshes when already at the top.)
final tabReselectProvider = StateProvider.family<int, int>((ref, tab) => 0);

/// Focus Discover's search dock without pushing another route.
final discoverSearchSignalProvider = StateProvider<int>((ref) => 0);
