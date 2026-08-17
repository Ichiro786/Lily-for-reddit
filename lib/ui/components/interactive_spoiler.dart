import 'package:flutter/material.dart';

class InteractiveSpoiler extends StatefulWidget {
  const InteractiveSpoiler({
    super.key,
    required this.text,
    this.textStyle,
  });

  final String text;
  final TextStyle? textStyle;

  @override
  State<InteractiveSpoiler> createState() => _InteractiveSpoilerState();
}

class _InteractiveSpoilerState extends State<InteractiveSpoiler> {
  bool _isRevealed = false;

  void _toggle() {
    setState(() => _isRevealed = !_isRevealed);
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.textStyle ?? DefaultTextStyle.of(context).style;
    final hiddenStyle = style.copyWith(color: Colors.transparent);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggle,
      child: _isRevealed
          ? Text(widget.text, style: style)
          : DecoratedBox(
              decoration: BoxDecoration(color: Colors.grey.shade800),
              child: Text(widget.text, style: hiddenStyle),
            ),
    );
  }
}
