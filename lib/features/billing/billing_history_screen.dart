import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../data/repositories/data_repository.dart';
import '../../domain/analytics.dart';
import '../../domain/permissions.dart';
import '../../providers/providers.dart';

/// Complete billing history with search and filters. Salespeople see only
/// their own bills (enforced by the repository / RLS).
class BillingHistoryScreen extends ConsumerStatefulWidget {
  const BillingHistoryScreen({super.key});

  @override
  ConsumerState<BillingHistoryScreen> createState() => _BillingHistoryScreenState();
}

class _BillingHistoryScreenState extends ConsumerState<BillingHistoryScreen> {
  RangePreset? _preset = RangePreset.last30; // null = all time
  DateRangeFilter? _custom;
  PaymentMode? _mode;
  String? _salespersonId;
  bool _showCancelled = true;
  String _q = '';

  SalesQuery get _query {
    if (_custom != null) return SalesQuery(from: _custom!.start, to: _custom!.end, salespersonId: _salespersonId);
    if (_preset == null) return SalesQuery(salespersonId: _salespersonId);
    final r = DateRangeFilter.forPreset(_preset!);
    return SalesQuery(from: r.start, to: r.end, salespersonId: _salespersonId);
  }

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(context: context, firstDate: DateTime(now.year - 3), lastDate: now);
    if (picked != null) setState(() => _custom = DateRangeFilter.custom(picked.start, picked.end));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isSalesperson = user?.role == UserRole.salesperson;
    final canBill = user?.can(Permission.createBill) ?? false;
    final salesAsync = ref.watch(salesProvider(_query));
    final people = isSalesperson ? const <AppUser>[] : (ref.watch(salespeopleProvider).valueOrNull ?? const <AppUser>[]);

    return Scaffold(
      appBar: AppBar(
        title: Text(isSalesperson ? 'My sales' : 'Billing history'),
        actions: [
          if (!isSalesperson && people.isNotEmpty)
            PopupMenuButton<String>(
              tooltip: 'Salesperson',
              icon: Icon(Icons.person_search_outlined, color: _salespersonId == null ? null : AppColors.gold),
              onSelected: (v) => setState(() => _salespersonId = v.isEmpty ? null : v),
              itemBuilder: (_) => [
                const PopupMenuItem(value: '', child: Text('All salespeople')),
                for (final p in people) PopupMenuItem(value: p.id, child: Text(p.fullName)),
              ],
            ),
        ],
      ),
      floatingActionButton: canBill
          ? FloatingActionButton.extended(
              heroTag: 'history-new-bill',
              onPressed: () => context.push('/bill/new'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New bill'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: AppTextField(
              hint: isSalesperson ? 'Search invoice or customer' : 'Search invoice, customer or mobile',
              prefixIcon: Icons.search_rounded,
              dense: true,
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final p in [RangePreset.today, RangePreset.last7, RangePreset.last30, RangePreset.thisMonth, RangePreset.lastMonth])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(p.label),
                      showCheckmark: false,
                      selected: _custom == null && _preset == p,
                      onSelected: (_) => setState(() {
                        _preset = p;
                        _custom = null;
                      }),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('All time'),
                    showCheckmark: false,
                    selected: _custom == null && _preset == null,
                    onSelected: (_) => setState(() {
                      _preset = null;
                      _custom = null;
                    }),
                  ),
                ),
                ChoiceChip(
                  label: Text(_custom?.label ?? 'Custom'),
                  showCheckmark: false,
                  selected: _custom != null,
                  onSelected: (_) => _pickCustom(),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final m in PaymentMode.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(m.label),
                      selected: _mode == m,
                      onSelected: (s) => setState(() => _mode = s ? m : null),
                    ),
                  ),
                FilterChip(
                  label: const Text('Show cancelled'),
                  selected: _showCancelled,
                  onSelected: (s) => setState(() => _showCancelled = s),
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncView<List<Sale>>(
              value: salesAsync,
              onRetry: () => ref.invalidate(salesProvider(_query)),
              builder: (all) {
                final list = all.where((s) {
                  if (_mode != null && s.paymentMode != _mode) return false;
                  if (!_showCancelled && s.isCancelled) return false;
                  if (_q.isEmpty) return true;
                  return s.invoiceNumber.toLowerCase().contains(_q) ||
                      s.customerName.toLowerCase().contains(_q) ||
                      s.customerPhone.contains(_q.replaceAll(' ', '')) ||
                      s.salespersonName.toLowerCase().contains(_q);
                }).toList();
                if (list.isEmpty) {
                  return EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No bills found',
                    message: all.isEmpty ? 'Bills for this period will appear here.' : 'Try a different search or filter.',
                    action: canBill && all.isEmpty ? 'Create a bill' : null,
                    onAction: () => context.push('/bill/new'),
                  );
                }
                final summary = Analytics.summarize(list);
                // Group by day
                final groups = <DateTime, List<Sale>>{};
                for (final s in list) {
                  groups.putIfAbsent(Dates.startOfDay(s.createdAt), () => []).add(s);
                }
                final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));
                return RefreshIndicator(
                  color: AppColors.maroon,
                  onRefresh: () async => ref.refreshData(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    children: [
                      AppCard(
                        color: AppColors.goldPale,
                        borderColor: AppColors.goldLight,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(children: [
                          Expanded(child: _Mini(label: 'Bills', value: '${summary.billCount}')),
                          Expanded(child: _Mini(label: 'Revenue', value: Money.compact(summary.revenuePaise))),
                          Expanded(child: _Mini(label: 'Avg bill', value: Money.compact(summary.averageBillPaise))),
                        ]),
                      ),
                      for (final day in days) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
                          child: Row(children: [
                            Expanded(
                              child: Text(
                                Dates.sameDay(day, DateTime.now())
                                    ? 'Today'
                                    : Dates.sameDay(day, DateTime.now().subtract(const Duration(days: 1)))
                                        ? 'Yesterday'
                                        : '${Dates.weekday(day)}, ${Dates.day(day)}',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                            MoneyText(Money.format(Analytics.summarize(groups[day]!).revenuePaise, decimals: false),
                                size: 13, color: AppColors.inkMuted),
                          ]),
                        ),
                        for (final s in groups[day]!) SaleTile(sale: s, showSalesperson: !isSalesperson),
                      ],
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

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(children: [
        MoneyText(value, size: 17, weight: FontWeight.w700, color: AppColors.maroon),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ]);
}

/// One bill in a list.
class SaleTile extends StatelessWidget {
  const SaleTile({super.key, required this.sale, this.showSalesperson = true});

  final Sale sale;
  final bool showSalesperson;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      onTap: () => context.push('/invoice/${sale.id}'),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: sale.isCancelled ? AppColors.errorBg : AppColors.goldPale,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              sale.isCancelled
                  ? Icons.block_rounded
                  : switch (sale.paymentMode) {
                      PaymentMode.cash => Icons.payments_outlined,
                      PaymentMode.upi => Icons.qr_code_2_rounded,
                      PaymentMode.card => Icons.credit_card_rounded,
                      PaymentMode.split => Icons.call_split_rounded,
                    },
              color: sale.isCancelled ? AppColors.error : AppColors.maroon,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sale.customerName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  [
                    sale.invoiceNumber,
                    Dates.time(sale.createdAt),
                    if (showSalesperson && sale.salespersonName.isNotEmpty) sale.salespersonName.split(' ').first,
                  ].join(' · '),
                  style: const TextStyle(fontSize: 12.5, color: AppColors.inkMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              MoneyText(
                Money.format(sale.totalPaise, decimals: false),
                size: 15,
                color: sale.isCancelled ? AppColors.inkSoft : null,
              ),
              const SizedBox(height: 2),
              Text(
                sale.isCancelled ? 'Cancelled' : '${sale.itemCount} item${sale.itemCount == 1 ? '' : 's'} · ${sale.paymentMode.label}',
                style: TextStyle(fontSize: 11.5, color: sale.isCancelled ? AppColors.error : AppColors.inkMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
