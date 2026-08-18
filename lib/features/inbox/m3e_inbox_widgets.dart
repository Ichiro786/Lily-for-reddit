import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme/shape_tokens.dart';
import '../../models/inbox_item.dart';

class M3EInboxCategoryTabs extends StatelessWidget {
  const M3EInboxCategoryTabs({super.key, this.onChanged});

  static const labels = ['All', 'Unread', 'Messages', 'Mentions', 'Sent'];
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TabBar(
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      indicatorSize: TabBarIndicatorSize.tab,
      onTap: onChanged,
      tabs: [for (final label in labels) Tab(text: label)],
    );
  }
}

class M3EInboxMessageCard extends StatelessWidget {
  const M3EInboxMessageCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  final InboxItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (icon, kindLabel) = switch (item.kind) {
      InboxKind.message => (Icons.mail_outline_rounded, 'Message'),
      InboxKind.commentReply => (Icons.reply_rounded, 'Reply'),
      InboxKind.postReply => (Icons.forum_outlined, 'Post reply'),
      InboxKind.mention => (Icons.alternate_email_rounded, 'Mention'),
    };
    final title = item.isMessage
        ? (item.subject.isEmpty ? '(no subject)' : item.subject)
        : (item.linkTitle?.isEmpty ?? true ? kindLabel : item.linkTitle!);
    final author = item.author.isEmpty ? '[deleted]' : item.author;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: ShapeTokens.medium,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: colorScheme.secondaryContainer,
                foregroundColor: colorScheme.onSecondaryContainer,
                child: Text(
                  author == '[deleted]' || author.isEmpty
                      ? '?'
                      : author[0].toUpperCase(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 16, color: colorScheme.primary),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'u/$author',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            '·  ${timeAgo(item.created)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.body.replaceAll('\n', ' '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (item.isNew)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Container(
                    width: 10,
                    height: 10,
                    key: const ValueKey<String>('inbox-unread-dot'),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
