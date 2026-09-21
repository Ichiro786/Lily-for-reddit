import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/shape_tokens.dart';
import '../auth/auth_controller.dart';
import '../auth/web_login_screen.dart';
import '../explore/explore_screen.dart';
import '../feed/feed_controller.dart';
import '../inbox/inbox_controller.dart';
import '../multireddit/multireddit_providers.dart';

class M3EProfileHeader extends StatelessWidget {
  const M3EProfileHeader({
    super.key,
    required this.username,
    required this.onSwitchAccount,
    required this.onViewProfile,
    this.subtitle,
    this.details,
  });

  final String username;
  final VoidCallback onSwitchAccount;
  final VoidCallback onViewProfile;
  final String? subtitle;
  final String? details;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final initial = username.isEmpty ? '?' : username[0].toUpperCase();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: ShapeTokens.medium,
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
              border: Border.all(color: colorScheme.primary, width: 2),
            ),
            child: Text(
              initial,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: onSwitchAccount,
                  borderRadius: ShapeTokens.extraSmall,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            'u/$username',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                if (details != null)
                  Text(
                    details!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                TextButton(
                  onPressed: onViewProfile,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('View profile  ›'),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: onSwitchAccount,
            tooltip: 'Switch or add account',
            icon: const Icon(Icons.people_alt_rounded),
          ),
        ],
      ),
    );
  }
}

/// Refreshes all account-scoped data after switching/adding/removing an account.
void resetAccountData(WidgetRef ref) {
  ref.read(redditRepositoryProvider).clearSubsCache();
  ref.invalidate(feedControllerProvider);
  ref.invalidate(inboxControllerProvider);
  ref.invalidate(unreadCountProvider);
  ref.invalidate(subscribedSubredditsProvider);
  ref.invalidate(myMultiredditsProvider);
}

/// Displays the M3E bottom sheet to manage, switch, or add accounts.
void showAccountBottomSheet(
    BuildContext context, WidgetRef ref, String current) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) => Consumer(
      builder: (ctx, ref2, _) {
        final cs = Theme.of(ctx).colorScheme;
        final accounts =
            ref2.watch(accountsProvider).valueOrNull ?? [current];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Accounts',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              for (final a in accounts)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: cs.primaryContainer,
                    foregroundColor: cs.onPrimaryContainer,
                    child: Text(a.isNotEmpty ? a[0].toUpperCase() : '?'),
                  ),
                  title: Text('u/$a'),
                  selected: a == current,
                  trailing: a == current
                      ? Icon(Icons.check_circle_rounded, color: cs.primary)
                      : IconButton(
                          tooltip: 'Remove',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () =>
                              _confirmRemove(context, ref, a),
                        ),
                  onTap: a == current
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          await ref
                              .read(authControllerProvider.notifier)
                              .switchAccount(a);
                          resetAccountData(ref);
                        },
                ),
              const Divider(height: 8),
              ListTile(
                leading: const Icon(Icons.person_add_alt_1_rounded),
                title: const Text('Add account'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _addAccount(context, ref);
                },
              ),
              ListTile(
                leading: Icon(Icons.logout_rounded, color: cs.error),
                title: Text('Log out of u/$current',
                    style: TextStyle(color: cs.error)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _confirmRemove(context, ref, current);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    ),
  );
}

Future<void> _addAccount(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final isWeb = ref.read(authModeProvider).valueOrNull == 'web';
  try {
    if (isWeb) {
      final cookie = await Navigator.of(context).push<String>(
        MaterialPageRoute(
            builder: (_) => const WebLoginScreen(clearFirst: true)),
      );
      if (cookie == null || cookie.isEmpty) return;
      await ref.read(authControllerProvider.notifier).loginWithWebSession(cookie);
    } else {
      await ref.read(authControllerProvider.notifier).addAccount();
    }
    resetAccountData(ref);
  } catch (e) {
    messenger.showSnackBar(SnackBar(
        content: Text(
            'Could not add account: ${'$e'.replaceFirst('Exception: ', '')}')));
  }
}

Future<void> _confirmRemove(
    BuildContext context, WidgetRef ref, String username) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Log out of u/$username?'),
      content: const Text(
          'This removes the account from this device. Your saved API '
          'credentials stay so you can add it again.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out')),
      ],
    ),
  );
  if (ok == true) {
    await ref.read(authControllerProvider.notifier).removeAccount(username);
    resetAccountData(ref);
  }
}

