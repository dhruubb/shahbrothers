import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import 'bonus_projection.dart';

class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = Dates.startOfMonth(DateTime.now());
    final lines = ref.watch(monthBonusProvider(month));
    final staff = ref.watch(staffProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team'),
        actions: [
          IconButton(
            tooltip: 'Bonuses',
            icon: const Icon(Icons.emoji_events_outlined),
            onPressed: () => context.push('/bonuses'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'team-add',
        onPressed: () => context.push('/settings/staff/new'),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add staff'),
      ),
      body: RefreshIndicator(
        color: AppColors.maroon,
        onRefresh: () async => ref.refreshData(),
        child: AsyncView<List<BonusLine>>(
          value: lines,
          onRetry: () => ref.refreshData(),
          builder: (list) {
            final others = (staff.valueOrNull ?? const <AppUser>[]).where((u) => u.role != UserRole.salesperson).toList();
            final totalTarget = list.fold<int>(0, (s, l) => s + l.result.targetPaise);
            final totalSales = list.fold<int>(0, (s, l) => s + l.result.basePaise);
            return MaxWidth(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                children: [
                  AppCard(
                    color: AppColors.goldPale,
                    borderColor: AppColors.goldLight,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${Dates.month(month)} · team progress', style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 8),
                      Row(children: [
                        MoneyText(Money.compact(totalSales), size: 22, weight: FontWeight.w700, color: AppColors.maroon),
                        Text('  of ${Money.compact(totalTarget)} target', style: const TextStyle(color: AppColors.inkMuted)),
                      ]),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: totalTarget == 0 ? 0 : (totalSales / totalTarget).clamp(0, 1).toDouble(),
                          minHeight: 8,
                          backgroundColor: AppColors.ivory,
                          color: AppColors.maroon,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('Net sales excl. GST. Bonuses use the same figure.', style: Theme.of(context).textTheme.bodySmall),
                    ]),
                  ),
                  const SectionHeader('Salespeople'),
                  for (final l in list) _SalespersonCard(line: l),
                  if (others.isNotEmpty) ...[
                    const SectionHeader('Owner & managers'),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(children: [
                        for (final u in others)
                          ListTile(
                            leading: InitialsAvatar(u.initials, size: 38),
                            title: Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(u.email),
                            trailing: Pill(u.role.label, tone: u.role == UserRole.owner ? PillTone.maroon : PillTone.gold),
                          ),
                      ]),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SalespersonCard extends StatelessWidget {
  const _SalespersonCard({required this.line});
  final BonusLine line;

  @override
  Widget build(BuildContext context) {
    final r = line.result;
    final pct = r.targetPaise == 0 ? 0.0 : r.basePaise * 100 / r.targetPaise;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: () => context.push('/team/${line.user.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            InitialsAvatar(line.user.initials, size: 44, highlight: pct >= 100),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Text(line.user.fullName,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5), overflow: TextOverflow.ellipsis),
                  ),
                  if (!line.user.isActive) ...[const SizedBox(width: 6), const Pill('Inactive', tone: PillTone.danger)],
                ]),
                Text('Target ${Money.compact(r.targetPaise)} · ${r.rule?.name ?? 'No'} slab',
                    style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              MoneyText(Money.compact(r.basePaise), size: 16, weight: FontWeight.w700),
              Text('${pct.toStringAsFixed(0)}%',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: pct >= 100 ? AppColors.success : (pct >= 80 ? AppColors.goldDeep : AppColors.inkMuted))),
            ]),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: r.progress,
              minHeight: 7,
              backgroundColor: AppColors.cream,
              color: pct >= 100 ? AppColors.gold : AppColors.maroon,
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.emoji_events_outlined, size: 15, color: AppColors.goldDeep),
            const SizedBox(width: 4),
            Text('Bonus so far ${Money.format(r.totalPaise, decimals: false)}',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            const Spacer(),
            if (r.nextRule != null && r.paiseToNextRule != null)
              Text('${Money.compact(r.paiseToNextRule!)} to ${r.nextRule!.name}',
                  style: const TextStyle(fontSize: 12, color: AppColors.inkMuted)),
          ]),
        ],
      ),
    );
  }
}
