import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/analytics.dart';
import '../../providers/providers.dart';

/// Date-range chips + salesperson filter shared by the owner dashboard and
/// reports. Writes to [dashboardFilterProvider].
class DashboardFilterBar extends ConsumerWidget {
  const DashboardFilterBar({super.key, this.showSalesperson = true, this.onDark = false});

  final bool showSalesperson;
  final bool onDark;

  static const presets = [
    RangePreset.today,
    RangePreset.last7,
    RangePreset.last30,
    RangePreset.thisMonth,
    RangePreset.lastMonth,
    RangePreset.last90,
    RangePreset.financialYear,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(dashboardFilterProvider);
    final staff = ref.watch(salespeopleProvider).valueOrNull ?? const [];
    final selectedPerson = staff.where((u) => u.id == filter.salespersonId).firstOrNull;

    Future<void> pickCustom() async {
      final now = DateTime.now();
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 3),
        lastDate: now,
        initialDateRange: DateTimeRange(start: filter.range.start, end: filter.range.lastDay),
        helpText: 'Select date range',
      );
      if (picked != null) {
        ref.read(dashboardFilterProvider.notifier).state =
            filter.copyWith(range: DateRangeFilter.custom(picked.start, picked.end));
      }
    }

    Future<void> pickPerson() async {
      final id = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('Filter by salesperson', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ),
              ListTile(
                leading: const Icon(Icons.groups_2_outlined),
                title: const Text('All salespeople'),
                trailing: filter.salespersonId == null ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.pop(ctx, ''),
              ),
              for (final u in staff)
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: Text(u.fullName),
                  trailing: filter.salespersonId == u.id ? const Icon(Icons.check_rounded) : null,
                  onTap: () => Navigator.pop(ctx, u.id),
                ),
            ],
          ),
        ),
      );
      if (id == null) return;
      ref.read(dashboardFilterProvider.notifier).state =
          id.isEmpty ? filter.copyWith(clearSalesperson: true) : filter.copyWith(salespersonId: id);
    }

    final fg = onDark ? AppColors.ivory : AppColors.ink;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final p in presets)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(p.label),
                    selected: filter.range.preset == p,
                    showCheckmark: false,
                    onSelected: (_) => ref.read(dashboardFilterProvider.notifier).state =
                        filter.copyWith(range: DateRangeFilter.forPreset(p)),
                  ),
                ),
              ChoiceChip(
                avatar: Icon(Icons.date_range_rounded,
                    size: 16, color: filter.range.preset == RangePreset.custom ? AppColors.ivory : AppColors.maroon),
                label: Text(filter.range.preset == RangePreset.custom ? filter.range.label : 'Custom'),
                selected: filter.range.preset == RangePreset.custom,
                showCheckmark: false,
                onSelected: (_) => pickCustom(),
              ),
            ],
          ),
        ),
        if (showSalesperson) ...[
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: pickPerson,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.filter_list_rounded, size: 18, color: onDark ? AppColors.goldLight : AppColors.maroon),
                  const SizedBox(width: 6),
                  Text(
                    selectedPerson == null ? 'All salespeople' : selectedPerson.fullName,
                    style: TextStyle(fontWeight: FontWeight.w600, color: fg),
                  ),
                  Icon(Icons.expand_more_rounded, size: 18, color: fg),
                  if (selectedPerson != null) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => ref.read(dashboardFilterProvider.notifier).state = filter.copyWith(clearSalesperson: true),
                      child: Icon(Icons.close_rounded, size: 16, color: fg),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
