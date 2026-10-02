import 'package:flutter/material.dart';

/// Apply formatting at the current selection without moving the cursor to the
/// end of the draft. Invalid platform selections fall back to its end.
void insertReplyMarkdown(
  TextEditingController controller,
  String before,
  String after, {
  String placeholder = 'text',
}) {
  final text = controller.text;
  final selection = controller.selection;
  final valid =
      selection.isValid && selection.start >= 0 && selection.end <= text.length;
  final start = valid ? selection.start : text.length;
  final end = valid ? selection.end : text.length;
  final selected = start == end ? placeholder : text.substring(start, end);
  controller.value = TextEditingValue(
    text: text.replaceRange(start, end, '$before$selected$after'),
    selection: TextSelection(
      baseOffset: start + before.length,
      extentOffset: start + before.length + selected.length,
    ),
  );
}

void insertReplyGif(TextEditingController controller, String url) {
  final text = controller.text;
  final selection = controller.selection;
  final valid =
      selection.isValid && selection.start >= 0 && selection.end <= text.length;
  final start = valid ? selection.start : text.length;
  final end = valid ? selection.end : text.length;
  final before = start > 0 && text[start - 1] != '\n' ? '\n' : '';
  final after = end < text.length && text[end] != '\n' ? '\n' : '';
  final insert = '$before$url$after';
  controller.value = TextEditingValue(
    text: text.replaceRange(start, end, insert),
    selection: TextSelection.collapsed(offset: start + insert.length),
  );
}
