import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/models.dart';
import '../../data/repositories/data_repository.dart';
import '../../domain/bonus_calculator.dart';
import '../../providers/providers.dart';

class BonusLine {
  const BonusLine(this.user, this.result);
  final AppUser user;
  final BonusResult result;
}

/// Live bonus calculation for every salesperson for [month] (first day of
/// month), from that month's completed bills and the current rules.
final monthBonusProvider = FutureProvider.autoDispose.family<List<BonusLine>, DateTime>((ref, month) async {
  final start = DateTime(month.year, month.month);
  final end = DateTime(month.year, month.month + 1);
  final sales = await ref.watch(salesProvider(SalesQuery(from: start, to: end)).future);
  final staff = await ref.watch(staffProvider.future);
  final rules = await ref.watch(commissionRulesProvider.future);
  final lines = staff
      .where((u) => u.role == UserRole.salesperson && (u.isActive || sales.any((s) => s.salespersonId == u.id)))
      .map((u) => BonusLine(
            u,
            BonusCalculator.compute(
              basePaise: BonusCalculator.monthlyBase(sales, u.id, start),
              targetPaise: u.monthlyTargetPaise,
              rules: rules,
            ),
          ))
      .toList()
    ..sort((a, b) => b.result.basePaise.compareTo(a.result.basePaise));
  return lines;
});
