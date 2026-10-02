import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/shape_tokens.dart';
import '../../core/reddit_comment_media.dart';
import '../../models/comment.dart';
import 'comments_controller.dart';

/// Searches the current visible tree; results retain identity across mutations.
class CommentSearchDialog extends ConsumerStatefulWidget {
  const CommentSearchDialog({
    super.key,
    required this.threadKey,
    this.initialQuery = '',
    required this.onQueryChanged,
  });
  final String threadKey;
  final String initialQuery;
  final ValueChanged<String> onQueryChanged;

  @override
  ConsumerState<CommentSearchDialog> createState() =>
      _CommentSearchDialogState();
}

class _CommentSearchDialogState extends ConsumerState<CommentSearchDialog> {
  late final _controller = TextEditingController(text: widget.initialQuery);
  final _previews = <String, (String, String)>{};
  String _preview(Comment comment) {
    final cached = _previews[comment.fullname];
    if (cached != null && cached.$1 == comment.body) return cached.$2;
    final text = commentSearchText(comment.body);
    _previews[comment.fullname] = (comment.body, text);
    return text;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final thread = ref.watch(commentsControllerProvider(widget.threadKey));
    final query = _controller.text.trim().toLowerCase();
    final comments = thread.valueOrNull;
    final matches = comments == null || query.isEmpty
        ? const []
        : visibleComments(comments)
              .where(
                (comment) =>
                    !comment.isMore &&
                    _preview(comment).toLowerCase().contains(query),
              )
              .toList();
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      shape: ShapeTokens.extraLargeShape,
      backgroundColor: cs.surfaceContainerHigh,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onChanged: (query) {
                        widget.onQueryChanged(query);
                        setState(() {});
                      },
                      onSubmitted: (_) {
                        if (matches.isNotEmpty) {
                          Navigator.pop(context, matches.first.fullname);
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Search comments',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close search',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: query.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Search within this comment thread'),
                    )
                  : matches.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No matching comments'),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final comment = matches[index];
                        return ListTile(
                          title: Text(
                            'u/${comment.author}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            _preview(comment),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.arrow_forward_rounded),
                          onTap: () => Navigator.pop(context, comment.fullname),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
