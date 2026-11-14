import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/dates.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../data/repositories/data_repository.dart';
import '../../providers/providers.dart';
import '../billing/billing_history_screen.dart';
import '../settings/account_menu.dart';
import 'performance_widgets.dart';

class SalespersonDashboardScreen extends ConsumerWidget {
  const SalespersonDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    if (me == null) return const SizedBox.shrink();
    // Fresh profile (the owner may have changed the target)
    final fresh = ref.watch(staffProvider).valueOrNull?.where((u) => u.id == me.id).firstOrNull ?? me;
    final month = Dates.startOfMonth(DateTime.now());
    final sales = ref.watch(salesProvider(SalesQuery(from: Dates.addMonths(month, -5), salespersonId: me.id)));
    final rules = ref.watch(commissionRulesProvider).valueOrNull ?? const <CommissionRule>[];

    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.maroon,
        onRefresh: () async => ref.refreshData(),
        child: AsyncView<List<Sale>>(
          value: sales,
          onRetry: () => ref.refreshData(),
          builder: (list) {
            final monthSales = list.where((s) => !s.createdAt.isBefore(month)).toList();
            final result = currentBonus(fresh, list, rules, month);
            final daysLeft = Dates.addMonths(month, 1).difference(Dates.startOfDay(DateTime.now())).inDays;
            return MaxWidth(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 12, 16, 32),
                children: [
                  Row(children: [
                    const BrandMark(size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${Dates.greeting()}, ${me.firstName}', style: Theme.of(context).textTheme.titleLarge),
                        Text('$daysLeft day${daysLeft == 1 ? '' : 's'} left in ${Dates.monthShort(month)}',
                            style: Theme.of(context).textTheme.bodySmall),
                      ]),
                    ),
                    const AccountMenuButton(),
                  ]),
                  const SizedBox(height: 16),
                  TargetHero(result: result, month: month),
                  const SizedBox(height: 12),
                  SlabCard(result: result, rules: rules),
                  const SizedBox(height: 12),
                  MonthStats(monthSales: monthSales),
                  const SectionHeader('My last 6 months'),
                  MonthlyTrendCard(sales: list),
                  SectionHeader('Recent sales', action: 'See all', onAction: () => context.go('/sales/history')),
                  if (list.isEmpty)
                    const EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No sales yet',
                      message: 'Bills where you are selected as the salesperson will appear here.',
                    )
                  else
                    for (final s in list.take(6)) SaleTile(sale: s, showSalesperson: false),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
