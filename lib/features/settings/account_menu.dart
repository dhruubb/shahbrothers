import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/common.dart';
import '../../domain/permissions.dart';
import '../../providers/providers.dart';
import '../billing/bill_controller.dart';

Future<void> signOut(BuildContext context, WidgetRef ref) async {
  final ok = await confirmDialog(context, title: 'Sign out?', message: 'You will need your password to sign in again.', confirm: 'Sign out');
  if (!ok) return;
  ref.read(billDraftProvider.notifier).reset();
  await ref.read(authControllerProvider.notifier).signOut();
}

/// Avatar button with account actions, shown on dashboards.
class AccountMenuButton extends ConsumerWidget {
  const AccountMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      tooltip: 'Account',
      color: AppColors.ivory,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      offset: const Offset(0, 48),
      onSelected: (v) {
        switch (v) {
          case 'printer':
            context.push('/settings/printer');
          case 'logout':
            signOut(context, ref);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
            Text('${user.role.label} · ${user.email}', style: const TextStyle(fontSize: 12, color: AppColors.inkMuted)),
          ]),
        ),
        const PopupMenuDivider(),
        if (user.can(Permission.printInvoice))
          const PopupMenuItem(
            value: 'printer',
            child: ListTile(leading: Icon(Icons.print_outlined), title: Text('Printer settings'), contentPadding: EdgeInsets.zero),
          ),
        const PopupMenuItem(
          value: 'logout',
          child: ListTile(leading: Icon(Icons.logout_rounded), title: Text('Sign out'), contentPadding: EdgeInsets.zero),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: InitialsAvatar(user.initials, size: 40),
      ),
    );
  }
}
