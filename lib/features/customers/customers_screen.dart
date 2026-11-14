import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../domain/permissions.dart';
import '../../providers/providers.dart';

enum _Sort {
  recent('Recent'),
  spend('Top spenders'),
  alpha('A–Z');

  const _Sort(this.label);
  final String label;
}

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _q = '';
  _Sort _sort = _Sort.recent;
  bool _consentOnly = false;

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider);
    final stats = ref.watch(customerStatsProvider).valueOrNull ?? const <String, CustomerStats>{};
    final canEdit = ref.watch(currentUserProvider)?.can(Permission.manageCustomers) ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              heroTag: 'customers-add',
              onPressed: () => context.push('/customers/new'),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Add customer'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: AppTextField(
              hint: 'Search by name or mobile number',
              prefixIcon: Icons.search_rounded,
              dense: true,
              keyboardType: TextInputType.text,
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final s in _Sort.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(s.label),
                      selected: _sort == s,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _sort = s),
                    ),
                  ),
                FilterChip(
                  avatar: const Icon(Icons.campaign_outlined, size: 16),
                  label: const Text('Marketing consent'),
                  selected: _consentOnly,
                  onSelected: (v) => setState(() => _consentOnly = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncView<List<Customer>>(
              value: customers,
              onRetry: () => ref.refreshData(),
              builder: (all) {
                final digits = _q.replaceAll(RegExp(r'\D'), '');
                final list = all.where((c) {
                  if (_consentOnly && !c.marketingConsent) return false;
                  if (_q.isEmpty) return true;
                  return c.name.toLowerCase().contains(_q) ||
                      (digits.isNotEmpty && c.phone.contains(digits)) ||
                      (c.city ?? '').toLowerCase().contains(_q);
                }).toList();
                switch (_sort) {
                  case _Sort.recent:
                    list.sort((a, b) {
                      final la = stats[a.id]?.lastPurchaseAt ?? a.createdAt ?? DateTime(2000);
                      final lb = stats[b.id]?.lastPurchaseAt ?? b.createdAt ?? DateTime(2000);
                      return lb.compareTo(la);
                    });
                  case _Sort.spend:
                    list.sort((a, b) => (stats[b.id]?.totalSpentPaise ?? 0).compareTo(stats[a.id]?.totalSpentPaise ?? 0));
                  case _Sort.alpha:
                    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                }
                if (list.isEmpty) {
                  return EmptyState(
                    icon: Icons.people_outline_rounded,
                    title: all.isEmpty ? 'No customers yet' : 'No matches',
                    message: all.isEmpty ? 'Customers are added automatically when you create a bill.' : 'Try another name or number.',
                    action: canEdit && all.isEmpty ? 'Add customer' : null,
                    onAction: () => context.push('/customers/new'),
                  );
                }
                final totalSpend = all.fold<int>(0, (s, c) => s + (stats[c.id]?.totalSpentPaise ?? 0));
                final consenting = all.where((c) => c.marketingConsent).length;
                return RefreshIndicator(
                  color: AppColors.maroon,
                  onRefresh: () async => ref.refreshData(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    itemCount: list.length + 1,
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10, left: 4, top: 4),
                          child: Text(
                            '${all.length} customers · ${Money.compact(totalSpend)} lifetime · $consenting opted in to updates',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        );
                      }
                      final c = list[i - 1];
                      final s = stats[c.id];
                      return AppCard(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        onTap: () => context.push('/customers/${c.id}'),
                        child: Row(children: [
                          InitialsAvatar(c.initials, size: 42),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Flexible(
                                  child: Text(c.name,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15), overflow: TextOverflow.ellipsis),
                                ),
                                if (c.marketingConsent) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.campaign_rounded, size: 15, color: AppColors.goldDeep),
                                ],
                              ]),
                              Text(
                                [Validators.prettyPhone(c.phone), if (c.city != null) c.city!].join(' · '),
                                style: const TextStyle(fontSize: 12.5, color: AppColors.inkMuted),
                              ),
                            ]),
                          ),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            MoneyText(Money.format(s?.totalSpentPaise ?? 0, decimals: false), size: 14.5),
                            Text(
                              s == null || s.purchaseCount == 0
                                  ? 'No purchases'
                                  : '${s.purchaseCount} visit${s.purchaseCount == 1 ? '' : 's'} · ${Dates.dayShort(s.lastPurchaseAt!)}',
                              style: const TextStyle(fontSize: 11.5, color: AppColors.inkMuted),
                            ),
                          ]),
                        ]),
                      );
                    },
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
