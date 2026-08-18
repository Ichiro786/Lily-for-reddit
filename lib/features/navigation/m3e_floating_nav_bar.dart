import 'package:flutter/material.dart';

import '../../core/theme/shape_tokens.dart';

class M3EFloatingNavBar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = minimized ? ShapeTokens.full : ShapeTokens.extraLarge;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: RepaintBoundary(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            height: minimized ? 44 : 64,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: radius,
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
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
                for (var i = 0; i < _destinations.length; i++)
                  Expanded(
                    child: _Destination(
                      iconOff: _destinations[i].$1,
                      iconOn: _destinations[i].$2,
                      label: _destinations[i].$3,
                      selected: selectedIndex == i,
                      unread: i == 2 ? unread : 0,
                      minimized: minimized,
                      showLabels: showLabels,
                      onTap: () => onSelected(i),
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
    final selectedColor = colorScheme.primary;
    final color = selected ? selectedColor : colorScheme.onSurfaceVariant;
    final labelsVisible = showLabels && !minimized;
    final icon = Icon(selected ? iconOn : iconOff, size: minimized ? 21 : 24);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            constraints: BoxConstraints(
              minHeight: minimized ? 32 : 48,
              minWidth: minimized ? 32 : 64,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: selected && !minimized ? 12 : 8,
              vertical: minimized ? 3 : 5,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? selectedColor.withValues(alpha: 0.25)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconTheme(data: IconThemeData(color: color), child: icon),
                      if (unread > 0)
                        Positioned(
                          top: -4,
                          right: -7,
                          child: Container(
                            constraints: minimized
                                ? const BoxConstraints.tightFor(
                                    width: 8, height: 8)
                                : const BoxConstraints(minWidth: 16, minHeight: 16),
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
                  ClipRect(
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOutCubic,
                      heightFactor: labelsVisible ? 1 : 0,
                      alignment: Alignment.topCenter,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: labelsVisible ? 1 : 0,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: color,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
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
      ),
    );
  }
}
