import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../domain/exceptions.dart';
import '../../providers/providers.dart';
import 'bonus_projection.dart';

/// Owner view of monthly bonuses: live projection for the current month,
/// finalise + mark paid for completed months.
class BonusesScreen extends ConsumerStatefulWidget {
  const BonusesScreen({super.key});

  @override
  ConsumerState<BonusesScreen> createState() => _BonusesScreenState();
}

class _BonusesScreenState extends ConsumerState<BonusesScreen> {
  late DateTime _month = Dates.startOfMonth(DateTime.now());
  bool _busy = false;

  bool get _isCurrent => _month == Dates.startOfMonth(DateTime.now());

  Future<void> _finalize() async {
    final ok = await confirmDialog(context,
        title: 'Finalise ${Dates.month(_month)}?',
        message: 'Bonuses will be calculated from this month\'s completed bills and the current rules, and saved as approved. '
            'Paid bonuses are not changed.',
        confirm: 'Finalise');
    if (!ok) return;
    await _run(() => ref.read(repositoryProvider).finalizeBonuses(_month), 'Bonuses finalised');
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.refreshData();
      if (mounted) showSnack(context, done);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = [for (var i = 0; i < 6; i++) Dates.addMonths(now, -i)];
    final live = ref.watch(monthBonusProvider(_month));
    final stored = (ref.watch(bonusesProvider(null)).valueOrNull ?? const <Bonus>[])
        .where((b) => b.periodStart == _month)
        .toList();
    final storedById = {for (final b in stored) b.salespersonId: b};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bonuses'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/settings/commission'),
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text('Rules'),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              children: [
                for (final m in months)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(m == months.first ? 'This month' : Dates.monthYearShort(m)),
                      selected: _month == m,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _month = m),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AsyncView<List<BonusLine>>(
              value: live,
              onRetry: () => ref.refreshData(),
              builder: (lines) {
                final finalized = stored.isNotEmpty;
                final total = finalized
                    ? stored.fold<int>(0, (s, b) => s + b.totalPaise)
                    : lines.fold<int>(0, (s, l) => s + l.result.totalPaise);
                final unpaid = stored.where((b) => b.status == BonusStatus.approved).toList();
                return MaxWidth(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      AppCard(
                        color: AppColors.goldPale,
                        borderColor: AppColors.goldLight,
                        child: Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(
                                _isCurrent ? 'Projected payout' : (finalized ? 'Finalised payout' : 'Calculated payout'),
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              MoneyText(Money.format(total, decimals: false), size: 26, weight: FontWeight.w700, color: AppColors.maroon),
                              Text(
                                _isCurrent
                                    ? 'Updates live as bills are added. Finalise after month end.'
                                    : finalized
                                        ? '${stored.length - unpaid.length} of ${stored.length} paid'
                                        : 'Not finalised yet',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ]),
                          ),
                          if (!_isCurrent && (!finalized || unpaid.isNotEmpty))
                            FilledButton(
                              onPressed: _busy ? null : _finalize,
                              child: Text(finalized ? 'Recalculate' : 'Finalise'),
                            ),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      for (final l in lines)
                        _BonusRow(
                          line: l,
                          stored: storedById[l.user.id],
                          busy: _busy,
                          onMarkPaid: (b) => _run(() => ref.read(repositoryProvider).markBonusPaid(b.id), 'Marked as paid'),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        'Bonus = commission % of net sales (excl. GST) for the highest slab reached, plus any flat bonus. '
                        'Edit slabs under Rules.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BonusRow extends StatelessWidget {
  const _BonusRow({required this.line, required this.stored, required this.busy, required this.onMarkPaid});

  final BonusLine line;
  final Bonus? stored;
  final bool busy;
  final ValueChanged<Bonus> onMarkPaid;

  @override
  Widget build(BuildContext context) {
    final r = line.result;
    final sales = stored?.salesPaise ?? r.basePaise;
    final target = stored?.targetPaise ?? r.targetPaise;
    final pct = stored?.achievementPct ?? r.achievementPct;
    final rule = stored?.ruleName ?? r.rule?.name ?? '—';
    final total = stored?.totalPaise ?? r.totalPaise;
    final commission = stored?.commissionPaise ?? r.commissionPaise;
    final flat = stored?.flatBonusPaise ?? r.flatBonusPaise;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            InitialsAvatar(line.user.initials, size: 40, highlight: pct >= 100),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(line.user.fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                Text('${pct.toStringAsFixed(1)}% of ${Money.compact(target)} · $rule',
                    style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              MoneyText(Money.format(total, decimals: false), size: 17, weight: FontWeight.w700, color: AppColors.maroon),
              if (stored != null)
                Pill(stored!.status.label, tone: stored!.status == BonusStatus.paid ? PillTone.success : PillTone.warning),
            ]),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _kv('Net sales', Money.compact(sales)),
            _kv('Commission', Money.compact(commission)),
            _kv('Flat bonus', flat == 0 ? '—' : Money.compact(flat)),
          ]),
          if (stored != null && stored!.status == BonusStatus.approved) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: busy ? null : () => onMarkPaid(stored!),
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: const Text('Mark as paid'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: const TextStyle(fontSize: 11.5, color: AppColors.inkMuted)),
          MoneyText(v, size: 14),
        ]),
      );
}
