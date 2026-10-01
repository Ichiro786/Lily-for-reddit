import 'package:flutter/material.dart';
import '../../core/media_aspect_ratio.dart';
import '../../core/widgets/m3e_animated_size.dart';
import '../../core/theme/shape_tokens.dart';

/// Content-sized portrait media, with an in-place expansion for very tall images.
/// Both states preserve the entire source image; the cap never crops content.
class ExpandablePostMedia extends StatefulWidget {
  const ExpandablePostMedia({
    super.key,
    required this.aspectRatio,
    required this.builder,
    required this.onOpen,
  });
  final double aspectRatio;
  final Widget Function(BuildContext context, double height) builder;
  final VoidCallback onOpen;
  @override
  State<ExpandablePostMedia> createState() => _ExpandablePostMediaState();
}

class _ExpandablePostMediaState extends State<ExpandablePostMedia> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final natural = constraints.maxWidth / widget.aspectRatio;
      final cap = mediaViewportMaxHeight(
        viewportHeight: MediaQuery.sizeOf(context).height,
        verticalPadding: MediaQuery.viewPaddingOf(context).vertical,
      );
      final capped = natural > cap;
      final height = capped && !_expanded ? cap : natural;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          M3EAnimatedSize(
            alignment: Alignment.topCenter,
            child: ClipRRect(
              borderRadius: ShapeTokens.large,
              child: Semantics(
                button: true,
                label: 'Open full screen media',
                child: GestureDetector(
                  onTap: widget.onOpen,
                  child: SizedBox(
                    width: double.infinity,
                    height: height,
                    child: widget.builder(context, height),
                  ),
                ),
              ),
            ),
          ),
          if (capped)
            TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(
                _expanded
                    ? Icons.unfold_less_rounded
                    : Icons.open_in_full_rounded,
                size: 18,
              ),
              label: Text(_expanded ? 'Show less' : 'View full'),
              style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
            ),
        ],
      );
    },
  );
}
