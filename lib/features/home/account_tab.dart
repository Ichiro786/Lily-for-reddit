import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../auth/auth_controller.dart';
import '../multireddit/multireddit_providers.dart';
import '../profile/profile_header.dart';
import '../settings/settings_screen.dart';

class AccountTab extends ConsumerWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final username =
        ref.watch(authControllerProvider).valueOrNull?.username ?? '';

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        M3EProfileHeader(
          username: username,
          onSwitchAccount: () => showAccountBottomSheet(context, ref, username),
          onViewProfile: () => context.push('/u/$username'),
        ),

        // Settings (primary)
        const SettingsList(embedded: true),

        const Divider(),

        // Custom feeds (secondary)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text('Custom feeds',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(
                            color: cs.primary, fontWeight: FontWeight.w700)),
              ),
              TextButton.icon(
                onPressed: () => _createMulti(context, ref, username),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New'),
              ),
            ],
          ),
        ),
        ref.watch(myMultiredditsProvider).when(
              loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) => const SizedBox.shrink(),
              data: (multis) => Column(
                children: [
                  for (final m in multis)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: cs.tertiaryContainer,
                        foregroundColor: cs.onTertiaryContainer,
                        child: const Icon(Icons.dynamic_feed_rounded, size: 20),
                      ),
                      title: Text(m.displayName),
                      subtitle: Text('${m.subreddits.length} subreddits'),
                      onTap: () => context.push('/m/$username/${m.name}'),
                    ),
                ],
              ),
            ),
        const SizedBox(height: 130),
      ],
    );
  }

  Future<void> _createMulti(
      BuildContext context, WidgetRef ref, String username) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New custom feed'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Feed name'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Create')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await ref
          .read(redditRepositoryProvider)
          .createMultireddit(username: username, name: name);
      ref.invalidate(myMultiredditsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('Could not create feed: ${'$e'.replaceFirst('Exception: ', '')}')));
      }
    }
  }
}
