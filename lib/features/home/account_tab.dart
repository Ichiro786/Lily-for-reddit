import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_controller.dart';
import '../settings/settings_screen.dart';
import '../user/user_screen.dart';

class AccountTab extends ConsumerWidget {
  const AccountTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final username =
        ref.watch(authControllerProvider).valueOrNull?.username ?? '';
    return username.isEmpty
        ? const SettingsScreen()
        : UserScreen(username: username, embedded: true);
  }
}
