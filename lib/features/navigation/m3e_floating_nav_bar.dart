import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class M3EFloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isMinimized;
  final int unreadCount;

  const M3EFloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isMinimized = false,
    this.unreadCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return RepaintBoundary(
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.fastOutSlowIn,
            height: isMinimized ? 44.0 : 60.0,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(isMinimized ? 999 : 28),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(
                  context: context,
                  index: 0,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                ),
                _buildNavItem(
                  context: context,
                  index: 1,
                  icon: Icons.explore_outlined,
                  activeIcon: Icons.explore_rounded,
                  label: 'Discover',
                ),
                _buildNavItem(
                  context: context,
                  index: 2,
                  icon: Icons.mail_outline_rounded,
                  activeIcon: Icons.mail_rounded,
                  label: 'Inbox',
                  badgeCount: unreadCount,
                ),
                _buildNavItem(
                  context: context,
                  index: 3,
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    int badgeCount = 0,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = currentIndex == index;

    final Color iconColor = isSelected
        ? colorScheme.onSecondaryContainer
        : colorScheme.onSurfaceVariant;
    final Color labelColor = isSelected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap(index);
          },
          borderRadius: BorderRadius.circular(isMinimized ? 999 : 20),
          splashColor: colorScheme.secondaryContainer.withValues(alpha: 0.35),
          highlightColor: Colors.transparent,
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 220),
            curve: Curves.fastOutSlowIn,
            padding: EdgeInsets.symmetric(vertical: isMinimized ? 6 : 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Active indicator capsule around icon
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.fastOutSlowIn,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSelected ? 16 : 0,
                    vertical: isSelected ? 4 : 0,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.secondaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        isSelected ? activeIcon : icon,
                        size: isMinimized ? 22 : 23,
                        color: iconColor,
                      ),
                      if (badgeCount > 0)
                        Positioned(
                          right: -4,
                          top: -2,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Text label: Smoothly collapses to 0 height in minimized state
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.fastOutSlowIn,
                  height: isMinimized ? 0 : 16,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: isMinimized ? 0.0 : 1.0,
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10.5,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: labelColor,
                        letterSpacing: 0.1,
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
