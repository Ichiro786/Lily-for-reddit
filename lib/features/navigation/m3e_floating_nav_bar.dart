import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../core/theme/shape_tokens.dart';

/// Detached navigation with the concept's icon-and-label active container.
class M3EFloatingNavBar extends StatefulWidget {
  const M3EFloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isMinimized = false,
    this.unreadCount = 0,
    this.onSearch,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isMinimized;
  final int unreadCount;
  final VoidCallback? onSearch;

  @override
  State<M3EFloatingNavBar> createState() => _M3EFloatingNavBarState();
}

class _M3EFloatingNavBarState extends State<M3EFloatingNavBar> {
  Timer? _discoverTap;

  @override
  void dispose() {
    _discoverTap?.cancel();
    super.dispose();
  }

  void _select(int index) {
    final doubleTap = index == 1 && _discoverTap?.isActive == true;
    _discoverTap?.cancel();
    _discoverTap = null;
    HapticFeedback.selectionClick();
    if (doubleTap && widget.onSearch != null) {
      widget.onSearch!();
      return;
    }
    if (index == 1 && widget.onSearch != null) {
      _discoverTap = Timer(kDoubleTapTimeout, () {});
    }
    widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.currentIndex;
    final isMinimized = widget.isMinimized;
    final unreadCount = widget.unreadCount;
    final cs = Theme.of(context).colorScheme;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : Duration(milliseconds: isMinimized ? 120 : 200);

    final labelHeight = MediaQuery.textScalerOf(context).scale(12) * 4 / 3;
    final height = isMinimized ? 60.0 : math.max(64.0, 48 + labelHeight);
    return RepaintBoundary(
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeOutCubic,
            height: height,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: ShapeTokens.extraLarge,
              border: Border.all(color: cs.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: cs.shadow.withValues(alpha: 0.20),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                for (final (index, icon, activeIcon, label) in const [
                  (0, Icons.home_outlined, Icons.home_rounded, 'Home'),
                  (
                    1,
                    Icons.explore_outlined,
                    Icons.explore_rounded,
                    'Discover',
                  ),
                  (2, Icons.mail_outline_rounded, Icons.mail_rounded, 'Inbox'),
                  (
                    3,
                    Icons.person_outline_rounded,
                    Icons.person_rounded,
                    'Profile',
                  ),
                ])
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: currentIndex == index,
                      onTap: () => widget.onTap(index),
                      customSemanticsActions:
                          index == 1 && widget.onSearch != null
                          ? {
                              const CustomSemanticsAction(
                                label: 'Search Reddit',
                              ): widget.onSearch!,
                            }
                          : null,
                      label: index == 2 && unreadCount > 0
                          ? '$label, $unreadCount unread'
                          : label,
                      excludeSemantics: true,
                      child: Tooltip(
                        message: index == 1 && widget.onSearch != null
                            ? 'Discover · double-tap to search'
                            : label,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Material(
                            color: currentIndex == index
                                ? cs.primaryContainer
                                : Colors.transparent,
                            animationDuration: duration,
                            borderRadius: ShapeTokens.medium,
                            child: InkWell(
                              borderRadius: ShapeTokens.medium,
                              onTap: () => _select(index),
                              onLongPress: index == 1 ? widget.onSearch : null,
                              child: ClipRect(
                                child: OverflowBox(
                                  minHeight: 0,
                                  maxHeight: math.max(64.0, 48 + labelHeight),
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Icon(
                                            currentIndex == index
                                                ? activeIcon
                                                : icon,
                                            size: 24,
                                            color: currentIndex == index
                                                ? cs.primary
                                                : cs.onSurfaceVariant,
                                          ),
                                          if (index == 2 && unreadCount > 0)
                                            Positioned(
                                              right: -3,
                                              top: -2,
                                              child: Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color: cs.primary,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      ClipRect(
                                        child: AnimatedAlign(
                                          duration: duration,
                                          curve: Curves.easeOutCubic,
                                          heightFactor: isMinimized ? 0 : 1,
                                          alignment: Alignment.topCenter,
                                          child: AnimatedOpacity(
                                            opacity: isMinimized ? 0 : 1,
                                            duration: duration,
                                            curve: Curves.easeOutCubic,
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                top: 2,
                                              ),
                                              child: Column(
                                                children: [
                                                  Text(
                                                    label,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .labelMedium
                                                        ?.copyWith(
                                                          letterSpacing: 0,
                                                          color:
                                                              currentIndex ==
                                                                  index
                                                              ? cs.onPrimaryContainer
                                                              : cs.onSurfaceVariant,
                                                        ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Container(
                                                    width: 24,
                                                    height: 2,
                                                    decoration: BoxDecoration(
                                                      color:
                                                          currentIndex == index
                                                          ? cs.primary
                                                          : Colors.transparent,
                                                      borderRadius:
                                                          ShapeTokens.full,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
