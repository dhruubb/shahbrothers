import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/common.dart';
import '../../domain/exceptions.dart';
import '../../domain/permissions.dart';
import '../../providers/providers.dart';
import '../billing/bill_controller.dart';
import '../printing/printer_service.dart';
import 'account_menu.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: 'Reset demo data?',
      message: 'All bills, customers and changes made on this device will be replaced with the original demo data.',
      confirm: 'Reset',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(repositoryProvider).resetDemoData();
      ref.read(billDraftProvider.notifier).reset();
      ref.refreshData();
      if (context.mounted) showSnack(context, 'Demo data restored');
    } catch (e) {
      if (context.mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final repo = ref.watch(repositoryProvider);
    final settings = ref.watch(settingsProvider).valueOrNull;
    final printer = ref.watch(printerConfigProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();

    Widget tile(IconData icon, String title, String? sub, VoidCallback onTap) => ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.goldPale, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: AppColors.maroon, size: 20),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: sub == null ? null : Text(sub),
          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.inkSoft),
          onTap: onTap,
        );

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: MaxWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            AppCard(
              child: Row(children: [
                InitialsAvatar(user.initials, size: 52, highlight: true),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(user.fullName, style: Theme.of(context).textTheme.titleLarge),
                    Text(user.email, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Pill(user.role.label, tone: PillTone.maroon),
                  ]),
                ),
              ]),
            ),
            if (user.can(Permission.viewBusinessAnalytics)) ...[
              const SectionHeader('Business'),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  tile(Icons.summarize_outlined, 'Sales reports', 'Summaries and PDF export', () => context.push('/reports')),
                  tile(Icons.emoji_events_outlined, 'Bonuses', 'Monthly payouts', () => context.push('/bonuses')),
                  tile(Icons.checkroom_outlined, 'Saree catalogue', 'Products, prices and stock', () => context.push('/products')),
                ]),
              ),
            ],
            const SectionHeader('Settings'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                if (user.can(Permission.manageSettings)) ...[
                  tile(Icons.storefront_outlined, 'Store & GST',
                      settings == null ? null : 'GST ${settings.gstRate}% · prefix ${settings.invoicePrefix}', () => context.push('/settings/store')),
                  tile(Icons.stairs_outlined, 'Bonus rules', 'Commission slabs', () => context.push('/settings/commission')),
                ],
                if (user.can(Permission.printInvoice))
                  tile(Icons.print_outlined, 'Printer', printer?.summary ?? 'Thermal receipt printer', () => context.push('/settings/printer')),
              ]),
            ),
            const SectionHeader('Data'),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(repo.isDemoMode ? Icons.phone_android_rounded : Icons.cloud_done_outlined, color: AppColors.maroon),
                  const SizedBox(width: 10),
                  Expanded(child: Text(repo.backendLabel, style: const TextStyle(fontWeight: FontWeight.w600))),
                ]),
                const SizedBox(height: 6),
                Text(
                  repo.isDemoMode
                      ? 'Demo mode: data is stored on this device and survives restarts. Connect Supabase to share data across devices (see README).'
                      : 'Connected to Supabase. Data is shared across all devices and protected by row-level security.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (repo.isDemoMode && user.can(Permission.manageSettings)) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                    onPressed: () => _reset(context, ref),
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Reset demo data'),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => signOut(context, ref),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign out'),
            ),
            const SizedBox(height: 24),
            const Center(child: BrandMark(size: 36)),
            const SizedBox(height: 6),
            Center(child: Text('Shah Brothers · v1.0.0', style: Theme.of(context).textTheme.bodySmall)),
          ],
        ),
      ),
    );
  }
}
