import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../data/repositories/data_repository.dart';
import '../../domain/analytics.dart';
import '../../domain/permissions.dart';
import '../../providers/providers.dart';
import '../billing/bill_controller.dart';
import '../billing/billing_history_screen.dart';

class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({super.key, required this.customerId});
  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(customersProvider);
    final sales = ref.watch(salesProvider(SalesQuery(customerId: customerId)));
    final user = ref.watch(currentUserProvider);
    final canEdit = user?.can(Permission.manageCustomers) ?? false;
    final canBill = user?.can(Permission.createBill) ?? false;

    return AsyncView<List<Customer>>(
      value: customers,
      builder: (all) {
        final c = all.where((x) => x.id == customerId).firstOrNull;
        if (c == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(icon: Icons.person_off_outlined, title: 'Customer not found'),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(c.name),
            actions: [
              if (canEdit)
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => context.push('/customers/${c.id}/edit'),
                ),
            ],
          ),
          floatingActionButton: canBill
              ? FloatingActionButton.extended(
                  heroTag: 'customer-bill',
                  onPressed: () {
                    final ctrl = ref.read(billDraftProvider.notifier);
                    if (ref.read(billDraftProvider).isEmpty) ctrl.selectCustomer(c);
                    context.push('/bill/new');
                  },
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                  label: const Text('Bill this customer'),
                )
              : null,
          body: MaxWidth(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              children: [
                AppCard(
                  child: Row(children: [
                    InitialsAvatar(c.initials, size: 56, highlight: true),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c.name, style: Theme.of(context).textTheme.titleLarge),
                        Text('+91 ${Validators.prettyPhone(c.phone)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (c.email != null) Text(c.email!, style: Theme.of(context).textTheme.bodySmall),
                        if (c.city != null) Text(c.city!, style: Theme.of(context).textTheme.bodySmall),
                        if (c.tags.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(spacing: 6, runSpacing: 4, children: [for (final t in c.tags) Pill(t, tone: PillTone.gold)]),
                        ],
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                sales.when(
                  skipLoadingOnRefresh: true,
                  loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
                  error: (e, _) => ErrorView(error: e),
                  data: (list) {
                    final s = Analytics.summarize(list);
                    final completed = list.where((x) => !x.isCancelled).toList();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        StatGrid(children: [
                          StatCard(label: 'Total spent', value: Money.format(s.revenuePaise, decimals: false), icon: Icons.currency_rupee_rounded),
                          StatCard(label: 'Purchases', value: '${s.billCount}', icon: Icons.shopping_bag_outlined),
                          StatCard(label: 'Average bill', value: Money.compact(s.averageBillPaise), icon: Icons.analytics_outlined),
                          StatCard(
                            label: 'Last visit',
                            value: completed.isEmpty ? '—' : Dates.dayShort(completed.first.createdAt),
                            icon: Icons.event_available_outlined,
                            caption: completed.isEmpty ? null : '${DateTime.now().difference(completed.first.createdAt).inDays} days ago',
                          ),
                        ]),
                        const SectionHeader('Purchase history'),
                        if (list.isEmpty)
                          const AppCard(child: Text('No purchases yet.'))
                        else
                          for (final sale in list) SaleTile(sale: sale),
                      ],
                    );
                  },
                ),
                const SectionHeader('Communication & consent'),
                _ConsentCard(customer: c),
                if (c.dateOfBirth != null || c.anniversary != null || c.notes != null) ...[
                  const SectionHeader('Details'),
                  AppCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (c.dateOfBirth != null) _kv('Birthday', Dates.dayShort(c.dateOfBirth!)),
                      if (c.anniversary != null) _kv('Anniversary', Dates.dayShort(c.anniversary!)),
                      if (c.notes != null) _kv('Notes', c.notes!),
                    ]),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: Text(k, style: const TextStyle(color: AppColors.inkMuted))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w500))),
        ]),
      );
}

class _ConsentCard extends StatelessWidget {
  const _ConsentCard({required this.customer});
  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final c = customer;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(c.marketingConsent ? Icons.verified_outlined : Icons.do_not_disturb_on_outlined,
                color: c.marketingConsent ? AppColors.success : AppColors.inkSoft),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                c.marketingConsent ? 'Agreed to receive offers & updates' : 'No marketing consent',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ]),
          if (c.marketingConsent && c.marketingConsentAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 32),
              child: Text(
                'Recorded ${Dates.day(c.marketingConsentAt!)}${c.marketingConsentSource == null ? '' : ' · ${_source(c.marketingConsentSource!)}'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            Pill('Prefers ${c.preferredChannel.label}', tone: PillTone.neutral),
            for (final ch in c.optedInChannels) Pill(ch, tone: PillTone.success, icon: Icons.check_rounded),
          ]),
          const SizedBox(height: 10),
          Text('WhatsApp and Telegram campaigns will only reach customers who opted in here.',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  static String _source(String s) => switch (s) {
        'in_store_verbal' => 'verbal, in store',
        'signed_form' => 'signed form',
        'app' => 'in app',
        _ => s,
      };
}
