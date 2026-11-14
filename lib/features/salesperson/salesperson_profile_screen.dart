import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../settings/account_menu.dart';
import 'performance_widgets.dart';

class SalespersonProfileScreen extends ConsumerWidget {
  const SalespersonProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    if (me == null) return const SizedBox.shrink();
    final fresh = ref.watch(staffProvider).valueOrNull?.where((u) => u.id == me.id).firstOrNull ?? me;
    final bonuses = ref.watch(bonusesProvider(me.id));
    final rules = ref.watch(commissionRulesProvider).valueOrNull ?? const <CommissionRule>[];
    final active = rules.where((r) => r.isActive).toList()..sort((a, b) => a.minAchievementPct.compareTo(b.minAchievementPct));

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: MaxWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            AppCard(
              child: Row(children: [
                InitialsAvatar(fresh.initials, size: 56, highlight: true),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(fresh.fullName, style: Theme.of(context).textTheme.titleLarge),
                    Text(fresh.email, style: Theme.of(context).textTheme.bodySmall),
                    if (fresh.phone != null)
                      Text('+91 ${Validators.prettyPhone(fresh.phone!)}', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 6),
                    Pill('Monthly target ${Money.format(fresh.monthlyTargetPaise, decimals: false)}', tone: PillTone.gold),
                  ]),
                ),
              ]),
            ),
            const SectionHeader('Earned bonuses'),
            AsyncView<List<Bonus>>(
              value: bonuses,
              loading: const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
              builder: (list) {
                final paid = list.where((b) => b.status == BonusStatus.paid).fold<int>(0, (s, b) => s + b.totalPaise);
                final due = list.where((b) => b.status == BonusStatus.approved).fold<int>(0, (s, b) => s + b.totalPaise);
                return Column(children: [
                  Row(children: [
                    Expanded(
                      child: StatCard(label: 'Paid to date', value: Money.format(paid, decimals: false), icon: Icons.savings_outlined),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                          label: 'Approved, awaiting payment', value: Money.format(due, decimals: false), icon: Icons.pending_actions_outlined),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  BonusHistoryCard(bonuses: list),
                ]);
              },
            ),
            const SectionHeader('How bonuses work'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Each month your net sales (bill value before GST) are compared with your target. '
                    'The highest slab you reach sets your commission on all net sales that month.',
                    style: TextStyle(color: AppColors.inkMuted),
                  ),
                  const SizedBox(height: 10),
                  for (final r in active)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        SizedBox(width: 84, child: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                        Expanded(
                          child: Text(
                            '${r.minAchievementPct == 0 ? 'Any sales' : '${r.minAchievementPct.toStringAsFixed(0)}% of target'}'
                            ' → ${r.commissionPct}%${r.flatBonusPaise > 0 ? ' + ${Money.format(r.flatBonusPaise)}' : ''}',
                          ),
                        ),
                      ]),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => signOut(context, ref),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign out'),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text('Member since ${fresh.joinedOn == null ? '—' : Dates.month(fresh.joinedOn!)}',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
      ),
    );
  }
}
