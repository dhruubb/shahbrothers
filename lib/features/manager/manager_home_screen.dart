import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/common.dart';
import '../../data/repositories/data_repository.dart';
import '../../domain/analytics.dart';
import '../../providers/providers.dart';
import '../billing/bill_controller.dart';
import '../billing/billing_history_screen.dart';
import '../printing/printer_service.dart';
import '../settings/account_menu.dart';

class ManagerHomeScreen extends ConsumerWidget {
  const ManagerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    final today = Dates.startOfDay(DateTime.now());
    final todaySales = ref.watch(salesProvider(SalesQuery(from: today, to: today.add(const Duration(days: 1)))));
    final draft = ref.watch(billDraftProvider);
    final printer = ref.watch(printerConfigProvider).valueOrNull;

    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.maroon,
        onRefresh: () async {
          ref.refreshData();
          ref.invalidate(printerConfigProvider);
        },
        child: MaxWidth(
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 12, 16, 32),
            children: [
              Row(children: [
                const BrandMark(size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${Dates.greeting()}, ${me?.firstName ?? ''}', style: Theme.of(context).textTheme.titleLarge),
                    Text('${Dates.weekday(today)}, ${Dates.day(today)}', style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
                const AccountMenuButton(),
              ]),
              const SizedBox(height: 16),
              HeroPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(draft.isEmpty ? 'READY TO BILL' : 'BILL IN PROGRESS',
                        style: const TextStyle(color: AppColors.goldLight, fontSize: 11.5, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(
                      draft.isEmpty
                          ? 'Create a new bill'
                          : '${draft.customer?.name ?? (draft.customerName.isEmpty ? 'New customer' : draft.customerName)} · '
                              '${draft.items.length} item${draft.items.length == 1 ? '' : 's'}',
                      style: const TextStyle(fontFamily: AppTheme.serif, color: AppColors.ivory, fontSize: 24, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      draft.isEmpty
                          ? 'Customer, salesperson, sarees, payment — then print.'
                          : 'Pick up where you left off.',
                      style: const TextStyle(color: AppColors.goldLight),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.maroon900),
                      onPressed: () => context.push('/bill/new'),
                      icon: Icon(draft.isEmpty ? Icons.add_rounded : Icons.edit_note_rounded),
                      label: Text(draft.isEmpty ? 'New bill' : 'Continue bill'),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
              const SectionHeader("Today's counter"),
              todaySales.when(
                skipLoadingOnRefresh: true,
                skipLoadingOnReload: true,
                loading: () => const SizedBox(height: 180, child: Center(child: CircularProgressIndicator())),
                error: (e, _) => ErrorView(error: e, onRetry: () => ref.refreshData()),
                data: (sales) {
                  final s = Analytics.summarize(sales);
                  final byMethod = Analytics.byPaymentMethod(sales);
                  return Column(children: [
                    StatGrid(children: [
                      StatCard(label: 'Bills today', value: '${s.billCount}', icon: Icons.receipt_long_rounded),
                      StatCard(label: 'Collected today', value: Money.compact(s.revenuePaise), icon: Icons.currency_rupee_rounded),
                      StatCard(label: 'Sarees sold', value: '${s.itemsSold}', icon: Icons.checkroom_rounded),
                      StatCard(label: 'Customers served', value: '${s.customerCount}', icon: Icons.people_alt_rounded),
                    ]),
                    const SizedBox(height: 12),
                    AppCard(
                      child: Row(children: [
                        for (final m in byMethod)
                          Expanded(
                            child: Column(children: [
                              Text(m.label, style: Theme.of(context).textTheme.labelMedium),
                              const SizedBox(height: 2),
                              MoneyText(Money.compact(m.valuePaise), size: 15),
                            ]),
                          ),
                      ]),
                    ),
                    SectionHeader("Today's bills", action: 'History', onAction: () => context.go('/manager/bills')),
                    if (sales.isEmpty)
                      const AppCard(
                        child: Row(children: [
                          Icon(Icons.wb_sunny_outlined, color: AppColors.goldDeep),
                          SizedBox(width: 12),
                          Expanded(child: Text('No bills yet today. The first one is a tap away.')),
                        ]),
                      )
                    else
                      for (final sale in sales.take(8)) SaleTile(sale: sale),
                  ]);
                },
              ),
              const SectionHeader('Quick actions'),
              StatGrid(children: [
                _Action(icon: Icons.person_add_alt_1_outlined, label: 'Add customer', onTap: () => context.push('/customers/new')),
                _Action(icon: Icons.add_box_outlined, label: 'Add saree', onTap: () => context.push('/products/new')),
                _Action(
                  icon: Icons.print_outlined,
                  label: printer?.isConfigured == true ? 'Printer ready' : 'Set up printer',
                  sub: printer?.summary,
                  onTap: () => context.push('/settings/printer'),
                ),
                _Action(icon: Icons.history_rounded, label: 'All bills', onTap: () => context.go('/manager/bills')),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap, this.sub});
  final IconData icon;
  final String label;
  final String? sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Icon(icon, color: AppColors.maroon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (sub != null)
                Text(sub!, style: const TextStyle(fontSize: 11, color: AppColors.inkMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
      );
}

