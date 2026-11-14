import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../domain/analytics.dart';
import '../../domain/bonus_calculator.dart';
import '../dashboard/charts.dart';

/// Maroon hero with the monthly target ring and projected bonus.
class TargetHero extends StatelessWidget {
  const TargetHero({super.key, required this.result, required this.month, this.title});

  final BonusResult result;
  final DateTime month;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final pct = result.targetPaise == 0 ? 0.0 : result.basePaise * 100 / result.targetPaise;
    return HeroPanel(
      child: Row(
        children: [
          TargetRing(
            progress: result.progress,
            onDark: true,
            size: 120,
            center: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${pct.toStringAsFixed(0)}%',
                  style: const TextStyle(
                      color: AppColors.ivory, fontSize: 26, fontWeight: FontWeight.w700, fontFeatures: AppTheme.tabular)),
              const Text('of target', style: TextStyle(color: AppColors.goldLight, fontSize: 11)),
            ]),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((title ?? Dates.month(month)).toUpperCase(),
                    style: const TextStyle(color: AppColors.goldLight, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(Money.format(result.basePaise, decimals: false),
                      style: const TextStyle(
                          color: AppColors.ivory, fontSize: 28, fontWeight: FontWeight.w700, fontFeatures: AppTheme.tabular)),
                ),
                Text('net sales of ${Money.format(result.targetPaise, decimals: false)} target',
                    style: const TextStyle(color: AppColors.goldLight, fontSize: 12.5)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.emoji_events_rounded, size: 16, color: AppColors.goldLight),
                    const SizedBox(width: 6),
                    Text('Bonus ${Money.format(result.totalPaise, decimals: false)}',
                        style: const TextStyle(color: AppColors.ivory, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Explains the current slab and what unlocks the next one.
class SlabCard extends StatelessWidget {
  const SlabCard({super.key, required this.result, required this.rules});
  final BonusResult result;
  final List<CommissionRule> rules;

  @override
  Widget build(BuildContext context) {
    final active = rules.where((r) => r.isActive).toList()..sort((a, b) => a.minAchievementPct.compareTo(b.minAchievementPct));
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.stairs_outlined, color: AppColors.maroon, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                result.rule == null ? 'No bonus slab yet' : '${result.rule!.name} slab · ${_pct(result.rule!.commissionPct)}% commission',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ]),
          if (result.nextRule != null && result.paiseToNextRule != null) ...[
            const SizedBox(height: 6),
            Text(
              'Sell ${Money.format(result.paiseToNextRule!, decimals: false)} more (net) this month to reach '
              '${result.nextRule!.name}: ${_pct(result.nextRule!.commissionPct)}%'
              '${result.nextRule!.flatBonusPaise > 0 ? ' + ${Money.format(result.nextRule!.flatBonusPaise)} bonus' : ''}.',
              style: const TextStyle(color: AppColors.inkMuted),
            ),
          ] else if (result.rule != null) ...[
            const SizedBox(height: 6),
            const Text('Top slab reached — outstanding!', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 12),
          Row(children: [
            for (final r in active)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: result.rule?.id == r.id ? AppColors.maroon : AppColors.cream,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(children: [
                    Text(r.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: result.rule?.id == r.id ? AppColors.ivory : AppColors.ink)),
                    Text('${_pct(r.minAchievementPct)}%+',
                        style: TextStyle(fontSize: 10.5, color: result.rule?.id == r.id ? AppColors.goldLight : AppColors.inkMuted)),
                  ]),
                ),
              ),
          ]),
        ],
      ),
    );
  }

  static String _pct(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

/// Finalised monthly bonuses.
class BonusHistoryCard extends StatelessWidget {
  const BonusHistoryCard({super.key, required this.bonuses});
  final List<Bonus> bonuses;

  @override
  Widget build(BuildContext context) {
    if (bonuses.isEmpty) {
      return const AppCard(child: Text('No finalised bonuses yet.', style: TextStyle(color: AppColors.inkMuted)));
    }
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(children: [
        for (final b in bonuses)
          ListTile(
            title: Text(Dates.month(b.periodStart), style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
                '${b.achievementPct.toStringAsFixed(0)}% of target · ${b.ruleName ?? '—'} · net ${Money.compact(b.salesPaise)}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                MoneyText(Money.format(b.totalPaise, decimals: false), size: 15),
                const SizedBox(height: 2),
                Pill(b.status.label, tone: b.status == BonusStatus.paid ? PillTone.success : PillTone.warning),
              ],
            ),
          ),
      ]),
    );
  }
}

/// Six-month revenue chart for one salesperson.
class MonthlyTrendCard extends StatelessWidget {
  const MonthlyTrendCard({super.key, required this.sales});
  final List<Sale> sales;

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.fromLTRB(10, 16, 16, 10),
        child: SalesTrendChart(points: Analytics.monthly(sales), height: 190),
      );
}

/// Month-to-date counters.
class MonthStats extends StatelessWidget {
  const MonthStats({super.key, required this.monthSales});
  final List<Sale> monthSales;

  @override
  Widget build(BuildContext context) {
    final s = Analytics.summarize(monthSales);
    return StatGrid(children: [
      StatCard(label: 'Bills this month', value: '${s.billCount}', icon: Icons.receipt_long_rounded),
      StatCard(label: 'Sarees sold', value: '${s.itemsSold}', icon: Icons.checkroom_rounded),
      StatCard(label: 'Revenue (incl. GST)', value: Money.compact(s.revenuePaise), icon: Icons.currency_rupee_rounded),
      StatCard(label: 'Average bill', value: Money.compact(s.averageBillPaise), icon: Icons.analytics_outlined),
    ]);
  }
}

/// Computes this month's bonus for [user] from [sales].
BonusResult currentBonus(AppUser user, List<Sale> sales, List<CommissionRule> rules, DateTime month) =>
    BonusCalculator.compute(
      basePaise: BonusCalculator.monthlyBase(sales, user.id, month),
      targetPaise: user.monthlyTargetPaise,
      rules: rules,
    );
