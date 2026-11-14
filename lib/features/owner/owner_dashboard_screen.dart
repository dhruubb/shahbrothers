import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../data/repositories/data_repository.dart';
import '../../domain/analytics.dart';
import '../../providers/providers.dart';
import '../billing/billing_history_screen.dart';
import '../dashboard/charts.dart';
import '../dashboard/filter_bar.dart';
import '../settings/account_menu.dart';
import 'bonus_projection.dart';

/// Previous period of the same length, for growth comparison.
final _previousSalesProvider = FutureProvider.autoDispose<List<Sale>>((ref) {
  final f = ref.watch(dashboardFilterProvider);
  final len = f.range.end.difference(f.range.start);
  return ref.watch(salesProvider(SalesQuery(from: f.range.start.subtract(len), to: f.range.start, salespersonId: f.salespersonId)).future);
});

class OwnerDashboardScreen extends ConsumerWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final filter = ref.watch(dashboardFilterProvider);
    final salesAsync = ref.watch(dashboardSalesProvider);
    final staffAsync = ref.watch(staffProvider);

    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.maroon,
        onRefresh: () async => ref.refreshData(),
        child: CustomScrollView(
          slivers: [
            SliverSafeArea(
              bottom: false,
              sliver: SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
                  child: Row(children: [
                    const BrandMark(size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${Dates.greeting()}, ${user?.firstName ?? ''}', style: Theme.of(context).textTheme.titleLarge),
                        Text('Shah Brothers · Owner', style: Theme.of(context).textTheme.bodySmall),
                      ]),
                    ),
                    const AccountMenuButton(),
                  ]),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverToBoxAdapter(
                child: MaxWidth(
                  width: 900,
                  child: salesAsync.when(
                    skipLoadingOnRefresh: true,
                    skipLoadingOnReload: true,
                    loading: () => const SizedBox(height: 600, child: LoadingView(blocks: 5)),
                    error: (e, _) => ErrorView(error: e, onRetry: () => ref.refreshData()),
                    data: (sales) => _Body(sales: sales, staff: staffAsync.valueOrNull ?? const [], filter: filter),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.sales, required this.staff, required this.filter});

  final List<Sale> sales;
  final List<AppUser> staff;
  final DashboardFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = Analytics.summarize(sales);
    final prev = ref.watch(_previousSalesProvider).valueOrNull;
    final growth = prev == null ? null : Analytics.growthPct(s.revenuePaise, Analytics.summarize(prev).revenuePaise);
    final perf = Analytics.bySalesperson(sales, staff);
    final top = perf.isNotEmpty && perf.first.revenuePaise > 0 ? perf.first : null;
    final selectedName = staff.where((u) => u.id == filter.salespersonId).firstOrNull?.fullName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'REVENUE · ${filter.range.label.toUpperCase()}${selectedName == null ? '' : ' · ${selectedName.toUpperCase()}'}',
                style: const TextStyle(color: AppColors.goldLight, fontSize: 11.5, letterSpacing: 1.2, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  Money.format(s.revenuePaise, decimals: false),
                  style: const TextStyle(
                    fontFamily: AppTheme.sans,
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ivory,
                    letterSpacing: -1,
                    fontFeatures: AppTheme.tabular,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(children: [
                if (growth != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (growth >= 0 ? AppColors.success : AppColors.error).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(growth >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 15, color: AppColors.ivory),
                      const SizedBox(width: 4),
                      Text('${growth >= 0 ? '+' : ''}${growth.toStringAsFixed(1)}%',
                          style: const TextStyle(color: AppColors.ivory, fontWeight: FontWeight.w700, fontSize: 12.5)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  const Text('vs previous period', style: TextStyle(color: AppColors.goldLight, fontSize: 12.5)),
                ] else
                  const Text('No earlier data to compare', style: TextStyle(color: AppColors.goldLight, fontSize: 12.5)),
              ]),
              const SizedBox(height: 18),
              Row(children: [
                _HeroStat('Bills', '${s.billCount}'),
                _HeroStat('Avg bill', Money.compact(s.averageBillPaise)),
                _HeroStat('Customers', '${s.customerCount}'),
              ]),
              const SizedBox(height: 6),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const DashboardFilterBar(),
        const SizedBox(height: 8),
        StatGrid(children: [
          StatCard(label: 'Sarees sold', value: '${s.itemsSold}', icon: Icons.checkroom_rounded),
          StatCard(label: 'Bills', value: '${s.billCount}', icon: Icons.receipt_long_rounded, onTap: () => context.go('/owner/sales')),
          StatCard(
              label: 'Customers', value: '${s.customerCount}', icon: Icons.people_alt_rounded, onTap: () => context.go('/owner/customers')),
          StatCard(label: 'Average bill', value: Money.format(s.averageBillPaise, decimals: false), icon: Icons.analytics_outlined),
          StatCard(
            label: 'Net sales (excl. GST)',
            value: Money.compact(s.netSalesPaise),
            icon: Icons.account_balance_wallet_outlined,
            caption: 'GST collected ${Money.compact(s.gstPaise)}',
          ),
          StatCard(
            label: 'Discounts given',
            value: Money.compact(s.discountPaise),
            icon: Icons.local_offer_outlined,
            caption: s.revenuePaise == 0 ? null : '${(s.discountPaise * 100 / (s.netSalesPaise + s.discountPaise)).toStringAsFixed(1)}% of list value',
          ),
        ]),
        const SectionHeader('Sales trend'),
        AppCard(
          padding: const EdgeInsets.fromLTRB(12, 14, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: SegmentedButton<ChartGranularity>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: [for (final g in ChartGranularity.values) ButtonSegment(value: g, label: Text(g.label))],
                  selected: {filter.granularity},
                  onSelectionChanged: (v) =>
                      ref.read(dashboardFilterProvider.notifier).state = filter.copyWith(granularity: v.first),
                ),
              ),
              const SizedBox(height: 14),
              _TrendChart(granularity: filter.granularity),
            ],
          ),
        ),
        if (top != null) ...[
          const SectionHeader('Top performer'),
          AppCard(
            color: AppColors.maroon,
            borderColor: AppColors.maroon,
            onTap: () => context.push('/team/${top.user.id}'),
            child: Row(children: [
              Stack(clipBehavior: Clip.none, children: [
                InitialsAvatar(top.user.initials, size: 56, highlight: true),
                const Positioned(
                  right: -4,
                  top: -8,
                  child: Icon(Icons.workspace_premium_rounded, color: AppColors.gold, size: 24),
                ),
              ]),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(top.user.fullName,
                      style: const TextStyle(fontFamily: AppTheme.serif, fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.ivory)),
                  const SizedBox(height: 2),
                  Text('${top.billCount} bills · ${top.itemsSold} sarees · ${top.sharePct.toStringAsFixed(0)}% of revenue',
                      style: const TextStyle(color: AppColors.goldLight, fontSize: 12.5)),
                ]),
              ),
              MoneyText(Money.compact(top.revenuePaise), size: 20, weight: FontWeight.w700, color: AppColors.ivory),
            ]),
          ),
        ],
        SectionHeader('Salesperson performance', action: 'Team', onAction: () => context.go('/owner/team')),
        AppCard(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: perf.isEmpty
              ? const Padding(padding: EdgeInsets.all(16), child: Text('No salespeople yet'))
              : RankingBars(
                  entries: [
                    for (final p in perf)
                      (
                        id: p.user.id,
                        label: p.user.fullName,
                        initials: p.user.initials,
                        valuePaise: p.revenuePaise,
                        caption: '${p.billCount} bills · avg ${Money.compact(p.averageBillPaise)} · ${p.sharePct.toStringAsFixed(0)}%',
                      ),
                  ],
                  onTap: (id) => context.push('/team/$id'),
                ),
        ),
        const _BonusSummary(),
        const SectionHeader('Payment methods'),
        AppCard(child: BreakdownDonut(entries: Analytics.byPaymentMethod(sales), centerLabel: 'collected')),
        _CategorySection(sales: sales),
        SectionHeader('Recent transactions', action: 'View all', onAction: () => context.go('/owner/sales')),
        if (sales.isEmpty)
          const AppCard(child: Text('No bills in this period.'))
        else
          for (final sale in sales.take(6)) SaleTile(sale: sale),
        const SizedBox(height: 8),
        AppCard(
          onTap: () => context.push('/reports'),
          child: const Row(children: [
            Icon(Icons.summarize_outlined, color: AppColors.maroon),
            SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Sales reports', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                Text('Day-wise, salesperson, category and payment summaries. Export as PDF.',
                    style: TextStyle(color: AppColors.inkMuted, fontSize: 12.5)),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.inkSoft),
          ]),
        ),
      ],
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: const TextStyle(
                  color: AppColors.ivory, fontWeight: FontWeight.w700, fontSize: 18, fontFeatures: AppTheme.tabular)),
          Text(label, style: const TextStyle(color: AppColors.goldLight, fontSize: 12)),
        ]),
      );
}

class _TrendChart extends ConsumerWidget {
  const _TrendChart({required this.granularity});
  final ChartGranularity granularity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trend = ref.watch(trendSalesProvider);
    return trend.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const SizedBox(height: 210, child: Center(child: CircularProgressIndicator())),
      error: (e, _) => SizedBox(height: 210, child: Center(child: Text('$e'))),
      data: (sales) => SalesTrendChart(points: Analytics.series(sales, granularity)),
    );
  }
}

class _BonusSummary extends ConsumerWidget {
  const _BonusSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = Dates.startOfMonth(DateTime.now());
    final lines = ref.watch(monthBonusProvider(month)).valueOrNull;
    if (lines == null) return const SizedBox.shrink();
    final total = lines.fold<int>(0, (s, l) => s + l.result.totalPaise);
    final hitTarget = lines.where((l) => l.result.targetPaise > 0 && l.result.basePaise >= l.result.targetPaise).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('Bonuses · ${Dates.month(month)}', action: 'Details', onAction: () => context.push('/bonuses')),
        AppCard(
          onTap: () => context.push('/bonuses'),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.goldPale, borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.emoji_events_outlined, color: AppColors.goldDeep),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                MoneyText(Money.format(total, decimals: false), size: 20, weight: FontWeight.w700),
                Text('Projected payout · $hitTarget of ${lines.length} on target', style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.inkSoft),
          ]),
        ),
      ],
    );
  }
}

class _CategorySection extends ConsumerWidget {
  const _CategorySection({required this.sales});
  final List<Sale> sales;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider).valueOrNull ?? const <Product>[];
    final cats = Analytics.byCategory(sales, products);
    if (cats.isEmpty) return const SizedBox.shrink();
    final top = cats.take(5).toList();
    final rest = cats.skip(5).fold<int>(0, (s, e) => s + e.valuePaise);
    final restCount = cats.skip(5).fold<int>(0, (s, e) => s + e.count);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Top categories'),
        AppCard(
          child: BreakdownDonut(
            entries: [...top, if (rest > 0) BreakdownEntry('Others', rest, restCount)],
            centerLabel: 'net sales',
          ),
        ),
      ],
    );
  }
}
