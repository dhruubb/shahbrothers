import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../data/repositories/data_repository.dart';
import '../../domain/exceptions.dart';
import '../../providers/providers.dart';
import '../billing/billing_history_screen.dart';
import '../salesperson/performance_widgets.dart';

class SalespersonDetailScreen extends ConsumerWidget {
  const SalespersonDetailScreen({super.key, required this.userId});
  final String userId;

  Future<void> _editTarget(BuildContext context, WidgetRef ref, AppUser user) async {
    final ctrl = TextEditingController(text: '${user.monthlyTargetPaise ~/ 100}');
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.ivory,
        surfaceTintColor: Colors.transparent,
        title: const Text('Monthly target'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Net sales (excl. GST) target for ${user.firstName}.'),
          const SizedBox(height: 12),
          AppTextField(
            controller: ctrl,
            prefixText: '₹ ',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofocus: true,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, Money.parse(ctrl.text)), child: const Text('Save')),
        ],
      ),
    );
    ctrl.dispose();
    if (value == null) return;
    try {
      await ref.read(repositoryProvider).updateStaff(user.copyWith(monthlyTargetPaise: value));
      ref.refreshData();
      if (context.mounted) showSnack(context, 'Target updated');
    } catch (e) {
      if (context.mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  Future<void> _toggleActive(BuildContext context, WidgetRef ref, AppUser user) async {
    final ok = await confirmDialog(
      context,
      title: user.isActive ? 'Deactivate ${user.firstName}?' : 'Reactivate ${user.firstName}?',
      message: user.isActive
          ? 'They will no longer be able to sign in or be selected on new bills. Their sales history is kept.'
          : 'They will be able to sign in and be selected on bills again.',
      confirm: user.isActive ? 'Deactivate' : 'Reactivate',
      destructive: user.isActive,
    );
    if (!ok) return;
    try {
      await ref.read(repositoryProvider).updateStaff(user.copyWith(isActive: !user.isActive));
      ref.refreshData();
    } catch (e) {
      if (context.mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(staffProvider);
    final month = Dates.startOfMonth(DateTime.now());
    final from = Dates.addMonths(month, -5);
    final sales = ref.watch(salesProvider(SalesQuery(from: from, salespersonId: userId)));
    final rules = ref.watch(commissionRulesProvider).valueOrNull ?? const <CommissionRule>[];
    final bonuses = ref.watch(bonusesProvider(userId)).valueOrNull ?? const <Bonus>[];

    final user = staff.valueOrNull?.where((u) => u.id == userId).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(user?.fullName ?? 'Salesperson'),
        actions: [
          if (user != null)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'target') _editTarget(context, ref, user);
                if (v == 'active') _toggleActive(context, ref, user);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'target', child: Text('Edit monthly target')),
                PopupMenuItem(value: 'active', child: Text(user.isActive ? 'Deactivate' : 'Reactivate')),
              ],
            ),
        ],
      ),
      body: user == null
          ? (staff.isLoading ? const LoadingView() : const EmptyState(icon: Icons.person_off_outlined, title: 'Not found'))
          : AsyncView<List<Sale>>(
              value: sales,
              onRetry: () => ref.refreshData(),
              builder: (list) {
                final monthSales = list.where((s) => !s.createdAt.isBefore(month)).toList();
                final result = currentBonus(user, list, rules, month);
                return MaxWidth(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    children: [
                      AppCard(
                        child: Row(children: [
                          InitialsAvatar(user.initials, size: 52, highlight: true),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                                if (!user.isActive) ...[const SizedBox(width: 8), const Pill('Inactive', tone: PillTone.danger)],
                              ]),
                              Text(user.email, style: Theme.of(context).textTheme.bodySmall),
                              if (user.phone != null) Text('+91 ${Validators.prettyPhone(user.phone!)}', style: Theme.of(context).textTheme.bodySmall),
                              if (user.joinedOn != null) Text('Joined ${Dates.day(user.joinedOn!)}', style: Theme.of(context).textTheme.bodySmall),
                            ]),
                          ),
                          IconButton(
                            tooltip: 'Edit target',
                            onPressed: () => _editTarget(context, ref, user),
                            icon: const Icon(Icons.flag_outlined),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 14),
                      TargetHero(result: result, month: month),
                      const SizedBox(height: 12),
                      SlabCard(result: result, rules: rules),
                      const SizedBox(height: 12),
                      MonthStats(monthSales: monthSales),
                      const SectionHeader('Last 6 months'),
                      MonthlyTrendCard(sales: list),
                      const SectionHeader('Bonus history'),
                      BonusHistoryCard(bonuses: bonuses),
                      const SectionHeader('Recent sales'),
                      if (list.isEmpty)
                        const AppCard(child: Text('No sales yet.'))
                      else
                        for (final s in list.take(8)) SaleTile(sale: s, showSalesperson: false),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
