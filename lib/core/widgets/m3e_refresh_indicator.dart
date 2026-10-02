import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/motion_tokens.dart';
import 'm3e_loading_indicator.dart';

class M3EScallopedSpinner extends StatelessWidget {
  const M3EScallopedSpinner({
    super.key,
    this.progress = 1,
    this.refreshing = false,
    this.size = 42,
    this.semanticLabel = 'Refreshing',
  });
  final double progress;
  final bool refreshing;
  final double size;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => M3ELoadingIndicator(
    size: size,
    progress: refreshing ? null : progress,
    semanticLabel: semanticLabel,
  );
}

class M3ERefreshIndicator extends StatefulWidget {
  const M3ERefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.triggerExtent = 96,
  });

  final Future<void> Function() onRefresh;
  final Widget child;
  final double triggerExtent;

  @override
  M3ERefreshIndicatorState createState() => M3ERefreshIndicatorState();
}

class M3ERefreshIndicatorState extends State<M3ERefreshIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _springController;
  double _pullExtent = 0;
  bool _refreshing = false;
  bool _thresholdReached = false;
  int _resetGeneration = 0;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
  }

  @override
  void dispose() {
    _resetGeneration++;
    _springController.dispose();
    super.dispose();
  }

  double get _progress =>
      (_pullExtent / widget.triggerExtent).clamp(0.0, 1.0).toDouble();

  Future<void> show() async {
    if (!mounted || _refreshing) return;
    _resetGeneration++;
    if (_springController.isAnimating) _springController.stop();
    setState(() {
      _refreshing = true;
      _pullExtent = widget.triggerExtent;
      _thresholdReached = true;
    });
    await _refresh();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0 ||
        notification.metrics.axis != Axis.vertical ||
        _refreshing) {
      return false;
    }

    if (notification is OverscrollNotification &&
        notification.dragDetails != null &&
        notification.overscroll < 0 &&
        notification.metrics.pixels <= notification.metrics.minScrollExtent) {
      _setPullExtent(_pullExtent - notification.overscroll);
    } else if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null) {
      if (notification.metrics.pixels < notification.metrics.minScrollExtent) {
        _setPullExtent(
          notification.metrics.minScrollExtent - notification.metrics.pixels,
        );
      } else if (_pullExtent > 0) {
        _setPullExtent(_pullExtent - (notification.scrollDelta ?? 0));
      }
    } else if (notification is ScrollEndNotification && _pullExtent > 0) {
      if (_progress >= 1) {
        _startRefresh();
      } else {
        _resetPull();
      }
    }
    return false;
  }

  void _setPullExtent(double extent) {
    _resetGeneration++;
    if (_springController.isAnimating) _springController.stop();
    final next = extent.clamp(0.0, widget.triggerExtent * 1.35).toDouble();
    if (next >= widget.triggerExtent && !_thresholdReached) {
      _thresholdReached = true;
      HapticFeedback.mediumImpact();
    } else if (next < widget.triggerExtent) {
      _thresholdReached = false;
    }
    if (mounted && next != _pullExtent) {
      setState(() => _pullExtent = next);
    }
  }

  void _startRefresh() {
    if (_refreshing) return;
    _resetGeneration++;
    if (_springController.isAnimating) _springController.stop();
    setState(() {
      _refreshing = true;
      _pullExtent = widget.triggerExtent;
    });
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
          _thresholdReached = false;
        });
        _resetPull();
      }
    }
  }

  void _resetPull() {
    if (!mounted || _pullExtent == 0) return;
    final generation = ++_resetGeneration;
    _springController.stop();
    if (MotionTokens.reduced(context)) {
      setState(() {
        _pullExtent = 0;
        _thresholdReached = false;
      });
      return;
    }
    final startExtent = _pullExtent;
    void listener() {
      if (mounted && generation == _resetGeneration) {
        setState(
          () => _pullExtent =
              startExtent *
              (1 - Curves.easeOutCubic.transform(_springController.value)),
        );
      }
    }

    _springController.addListener(listener);
    _springController.forward(from: 0).whenCompleteOrCancel(() {
      _springController.removeListener(listener);
      if (mounted && generation == _resetGeneration) {
        setState(() {
          _pullExtent = 0;
          _thresholdReached = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final visible = _refreshing || _pullExtent > 0;
    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: Stack(
        children: [
          widget.child,
          if (visible)
            Positioned(
              top: 8 + (_pullExtent * 0.22),
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Material(
                    color: colorScheme.surfaceContainerHigh,
                    elevation: 3,
                    shadowColor: Colors.black.withValues(alpha: 0.22),
                    shape: const CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: M3EScallopedSpinner(
                        progress: _progress,
                        refreshing: _refreshing,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
