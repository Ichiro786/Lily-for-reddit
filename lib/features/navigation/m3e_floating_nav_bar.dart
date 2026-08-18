import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../core/theme/shape_tokens.dart';

class M3EFloatingNavBar extends StatefulWidget {
  const M3EFloatingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.unread = 0,
    this.minimized = false,
    this.showLabels = true,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final int unread;
  final bool minimized;
  final bool showLabels;

  static const _destinations = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.explore_outlined, Icons.explore_rounded, 'Discover'),
    (Icons.mail_outline_rounded, Icons.mail_rounded, 'Inbox'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  @override
  State<M3EFloatingNavBar> createState() => _M3EFloatingNavBarState();
}

class _M3EFloatingNavBarState extends State<M3EFloatingNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _morph;

  @override
  void initState() {
    super.initState();
    _morph = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: widget.minimized ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(covariant M3EFloatingNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.minimized != widget.minimized) {
      _morph.animateTo(
        widget.minimized ? 1 : 0,
        curve: Curves.fastOutSlowIn,
      );
    }
  }

  @override
  void dispose() {
    _morph.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _morph,
            builder: (context, _) {
              final t = Curves.fastOutSlowIn.transform(_morph.value);
              final minimized = t > 0.5;
              final radius = BorderRadius.lerp(
                    ShapeTokens.extraLarge,
                    ShapeTokens.full,
                    t,
                  ) ??
                  ShapeTokens.extraLarge;
              return Container(
                key: const ValueKey<String>('m3e-nav-dock'),
                height: lerpDouble(58, 42, t),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: radius,
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.24),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    for (var i = 0;
                        i < M3EFloatingNavBar._destinations.length;
                        i++)
                      Expanded(
                        child: _Destination(
                          iconOff: M3EFloatingNavBar._destinations[i].$1,
                          iconOn: M3EFloatingNavBar._destinations[i].$2,
                          label: M3EFloatingNavBar._destinations[i].$3,
                          selected: widget.selectedIndex == i,
                          unread: i == 2 ? widget.unread : 0,
                          minimized: minimized,
                          showLabels: widget.showLabels,
                          onTap: () => widget.onSelected(i),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({
    required this.iconOff,
    required this.iconOn,
    required this.label,
    required this.selected,
    required this.unread,
    required this.minimized,
    required this.showLabels,
    required this.onTap,
  });

  final IconData iconOff;
  final IconData iconOn;
  final String label;
  final bool selected;
  final int unread;
  final bool minimized;
  final bool showLabels;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = selected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    final labelVisible = showLabels && !minimized;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.fastOutSlowIn,
            constraints: BoxConstraints(
              minHeight: minimized ? 32 : 42,
              minWidth: minimized ? 32 : 56,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: selected && !minimized ? 10 : 8,
              vertical: minimized ? 2 : 4,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? colorScheme.primary.withValues(alpha: 0.22)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      selected ? iconOn : iconOff,
                      size: minimized ? 20 : 22,
                      color: color,
                    ),
                    if (unread > 0)
                      Positioned(
                        top: -5,
                        right: -7,
                        child: Container(
                          constraints: minimized
                              ? const BoxConstraints.tightFor(
                                  width: 8,
                                  height: 8,
                                )
                              : const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                          padding: minimized
                              ? EdgeInsets.zero
                              : const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: colorScheme.error,
                            shape: minimized
                                ? BoxShape.circle
                                : BoxShape.rectangle,
                            borderRadius:
                                minimized ? null : BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: minimized
                              ? null
                              : Text(
                                  unread > 99 ? '99+' : '$unread',
                                  style: TextStyle(
                                    color: colorScheme.onError,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                  ],
                ),
                Flexible(
                  fit: FlexFit.loose,
                  child: AnimatedOpacity(
                    opacity: labelVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.fastOutSlowIn,
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.fastOutSlowIn,
                      child: labelVisible
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: color,
                                          fontWeight: selected
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                        ),
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
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
