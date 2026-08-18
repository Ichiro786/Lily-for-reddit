import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme/shape_tokens.dart';
import '../../models/inbox_item.dart';
import '../home/tab_signals.dart';
import 'inbox_controller.dart';
import 'm3e_inbox_widgets.dart';

class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  static const _tabs = [
    ('All', 'inbox'),
    ('Unread', 'unread'),
    ('Messages', 'messages'),
    ('Mentions', 'mentions'),
    ('Sent', 'sent'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Inbox'),
          actions: [
            Builder(
              builder: (context) => IconButton(
                tooltip: 'Mark this tab read',
                icon: const Icon(Icons.mark_email_read_outlined),
                onPressed: () {
                  final index = DefaultTabController.of(context).index;
                  ref
                      .read(inboxControllerProvider(_tabs[index].$2).notifier)
                      .markAllRead();
                },
              ),
            ),
          ],
          bottom: const M3EInboxCategoryTabs(),
        ),
        floatingActionButton: FloatingActionButton(
          shape: const RoundedRectangleBorder(
            borderRadius: ShapeTokens.small,
          ),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          tooltip: 'New message',
          onPressed: () => context.push('/compose_message'),
          child: const Icon(Icons.edit_rounded),
        ),
        body: TabBarView(
          children: [for (final tab in _tabs) _InboxList(where: tab.$2)],
        ),
      ),
    );
  }
}

class _InboxList extends ConsumerStatefulWidget {
  const _InboxList({required this.where});

  final String where;

  @override
  ConsumerState<_InboxList> createState() => _InboxListState();
}

class _InboxListState extends ConsumerState<_InboxList>
    with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();
  String _kindFilter = 'all';

  @override
  bool get wantKeepAlive => true;

  List<InboxItem> _applyFilter(List<InboxItem> items) {
    if (widget.where != 'inbox' || _kindFilter == 'all') return items;
    return items.where((item) {
      switch (_kindFilter) {
        case 'replies':
          return item.kind == InboxKind.commentReply ||
              item.kind == InboxKind.postReply;
        case 'mentions':
          return item.kind == InboxKind.mention;
        case 'messages':
          return item.kind == InboxKind.message;
        default:
          return true;
      }
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
        ref.read(inboxControllerProvider(widget.where).notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Widget _filterBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const options = [
      ('all', 'All'),
      ('replies', 'Replies'),
      ('mentions', 'Mentions'),
      ('messages', 'Messages'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
      child: Row(
        children: [
          for (final option in options) ...[
            FilterChip(
              label: Text(option.$2),
              selected: _kindFilter == option.$1,
              onSelected: (_) => setState(() => _kindFilter = option.$1),
              shape: const RoundedRectangleBorder(
                borderRadius: ShapeTokens.full,
              ),
              selectedColor: colorScheme.primaryContainer,
              checkmarkColor: colorScheme.onPrimaryContainer,
              labelStyle: TextStyle(
                color: _kindFilter == option.$1
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
              side: BorderSide(
                color: _kindFilter == option.$1
                    ? Colors.transparent
                    : colorScheme.outlineVariant,
              ),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.listen<int>(tabReselectProvider(2), (_, __) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOut,
        );
      }
    });
    final async = ref.watch(inboxControllerProvider(widget.where));
    final notifier = ref.read(inboxControllerProvider(widget.where).notifier);

    final body = RefreshIndicator(
      onRefresh: notifier.refresh,
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: Text('Could not load inbox.\n$error')),
            ),
          ],
        ),
        data: (state) {
          final items = _applyFilter(state.items);
          if (items.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('Nothing here')),
              ],
            );
          }
          return ListView.separated(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 130),
            itemCount: items.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == items.length) {
                return state.loadingMore
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : const SizedBox.shrink();
              }
              final item = items[index];
              return Dismissible(
                key: ValueKey(item.fullname),
                direction: item.isMessage
                    ? DismissDirection.horizontal
                    : DismissDirection.startToEnd,
                background: _swipeBackground(
                  context,
                  read: true,
                  isNew: item.isNew,
                ),
                secondaryBackground: _swipeBackground(context, read: false),
                confirmDismiss: (direction) async {
                  if (direction == DismissDirection.startToEnd) {
                    item.isNew
                        ? notifier.markRead(item.fullname)
                        : notifier.markUnread(item.fullname);
                    return false;
                  }
                  notifier.deleteMessage(item.fullname);
                  return true;
                },
                child: M3EInboxMessageCard(
                  item: item,
                  onTap: () => _open(context, ref, item),
                ),
              );
            },
          );
        },
      ),
    );

    if (widget.where != 'inbox') return body;
    return Column(
      children: [
        _filterBar(context),
        Expanded(child: body),
      ],
    );
  }

  Widget _swipeBackground(
    BuildContext context, {
    required bool read,
    bool isNew = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    if (read) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: colorScheme.tertiary,
          borderRadius: ShapeTokens.small,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isNew
                  ? Icons.mark_email_read_outlined
                  : Icons.mark_email_unread_outlined,
              color: colorScheme.onTertiary,
            ),
            const SizedBox(width: 8),
            Text(
              isNew ? 'Mark read' : 'Mark unread',
              style: TextStyle(
                color: colorScheme.onTertiary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(
        color: colorScheme.error,
        borderRadius: ShapeTokens.small,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Delete',
            style: TextStyle(
              color: colorScheme.onError,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.delete_outline_rounded, color: colorScheme.onError),
        ],
      ),
    );
  }

  void _open(BuildContext context, WidgetRef ref, InboxItem item) {
    if (item.isNew) {
      ref.read(inboxControllerProvider(widget.where).notifier).markRead(item.fullname);
    }
    if (item.isMessage) {
      context.push('/message', extra: item);
      return;
    }
    final reference = item.postRef;
    if (reference == null) return;
    final commentId = item.fullname.startsWith('t1_')
        ? item.fullname.substring(3)
        : null;
    final suffix = commentId == null ? '' : '?comment=$commentId';
    context.push(
      '/comments/${reference.subreddit}/${reference.postId}$suffix',
    );
  }
}
