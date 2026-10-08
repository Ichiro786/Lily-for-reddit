import 'dart:math' as math;
import 'package:flutter/material.dart';

/// App-specific responsive tab group. Labels remain whole even at large text
/// sizes; rows expand to fill the track instead of clipping a scrolling pill.
class ProfileTabs extends StatelessWidget {
  const ProfileTabs({super.key, required this.tabs});
  final List<Tab> tabs;
  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final style = theme.textTheme.labelLarge!.copyWith(
      fontWeight: FontWeight.w700,
    );
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          var longest = 0.0;
          for (final tab in tabs) {
            final painter = TextPainter(
              text: TextSpan(text: tab.text, style: style),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
            )..layout();
            longest = math.max(longest, painter.width);
            painter.dispose();
          }
          final columns = (constraints.maxWidth / (longest + 32)).floor().clamp(
            1,
            tabs.length,
          );
          final rows = (tabs.length / columns).ceil();
          final perRow = (tabs.length / rows).ceil();
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var start = 0; start < tabs.length; start += perRow)
                Row(
                  children: [
                    for (
                      var i = start;
                      i < math.min(start + perRow, tabs.length);
                      i++
                    )
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Semantics(
                            selected: controller.index == i,
                            button: true,
                            child: Material(
                              color: controller.index == i
                                  ? cs.primaryContainer
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(24),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: () => controller.animateTo(i),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minHeight: 48,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                    child: Center(
                                      child: Text(
                                        tabs[i].text!,
                                        textAlign: TextAlign.center,
                                        style: style.copyWith(
                                          color: controller.index == i
                                              ? cs.onPrimaryContainer
                                              : cs.onSurfaceVariant,
                                        ),
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
            ],
          );
        },
      ),
    );
  }
}
