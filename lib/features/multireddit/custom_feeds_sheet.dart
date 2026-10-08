import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../core/widgets/m3e_loading_indicator.dart';
import 'multireddit_providers.dart';

void showCustomFeedsSheet(
  BuildContext context,
  WidgetRef ref,
  String username,
) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => Consumer(
      builder: (sheet, localRef, _) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheet).height * .65,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Custom feeds',
                        style: Theme.of(sheet).textTheme.titleLarge,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _create(sheet, localRef, username),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('New'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: localRef
                    .watch(myMultiredditsProvider)
                    .when(
                      loading: () => const Center(child: M3ELoadingIndicator()),
                      error: (e, _) => Center(
                        child: TextButton(
                          onPressed: () =>
                              localRef.invalidate(myMultiredditsProvider),
                          child: const Text('Could not load feeds. Retry'),
                        ),
                      ),
                      data: (feeds) => feeds.isEmpty
                          ? const Center(child: Text('No custom feeds yet'))
                          : ListView(
                              children: [
                                for (final feed in feeds)
                                  ListTile(
                                    leading: const Icon(
                                      Icons.dynamic_feed_rounded,
                                    ),
                                    title: Text(feed.displayName),
                                    subtitle: Text(
                                      '${feed.subreddits.length} communities',
                                    ),
                                    onTap: () {
                                      Navigator.pop(sheet);
                                      context.push('/m/$username/${feed.name}');
                                    },
                                  ),
                              ],
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

Future<void> _create(
  BuildContext context,
  WidgetRef ref,
  String username,
) async {
  final controller = TextEditingController();
  String? name;
  try {
    name = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('New custom feed'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Feed name'),
          onSubmitted: (value) => Navigator.pop(dialog, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  } finally {
    controller.dispose();
  }
  if (name == null || name.isEmpty || !context.mounted) return;
  try {
    await ref
        .read(redditRepositoryProvider)
        .createMultireddit(username: username, name: name);
    ref.invalidate(myMultiredditsProvider);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not create feed. Please try again.'),
        ),
      );
    }
  }
}
