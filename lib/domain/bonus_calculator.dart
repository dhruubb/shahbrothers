import '../data/models/models.dart';

class BonusResult {
  const BonusResult({
    required this.basePaise,
    required this.targetPaise,
    required this.achievementPct,
    required this.commissionPaise,
    required this.flatBonusPaise,
    this.rule,
    this.nextRule,
    this.paiseToNextRule,
  });

  /// Net sales (excl. GST) for the month.
  final int basePaise;
  final int targetPaise;
  final double achievementPct;
  final CommissionRule? rule;
  final int commissionPaise;
  final int flatBonusPaise;
  final CommissionRule? nextRule;

  /// Additional net sales needed to unlock [nextRule].
  final int? paiseToNextRule;

  int get totalPaise => commissionPaise + flatBonusPaise;

  /// Progress towards target, clamped to 0..1 for progress bars.
  double get progress => targetPaise <= 0 ? 0 : (basePaise / targetPaise).clamp(0, 1).toDouble();
}

/// Bonus maths. MUST stay identical to `finalize_bonuses_internal()` in
/// supabase/migrations/0001_init.sql.
///
/// Base = net sales (taxable value, excl. GST) of completed bills in the
/// month. The active rule with the highest threshold reached applies:
/// bonus = round½↑(base × commission%) + flat bonus.
class BonusCalculator {
  const BonusCalculator._();

  static int _bp(double v) => (v * 100).round();

  static bool _reached(CommissionRule r, int base, int target) =>
      r.minAchievementPct == 0 || (target > 0 && base * 10000 >= _bp(r.minAchievementPct) * target);

  static BonusResult compute({
    required int basePaise,
    required int targetPaise,
    required List<CommissionRule> rules,
  }) {
    final active = rules.where((r) => r.isActive).toList()
      ..sort((a, b) => b.minAchievementPct.compareTo(a.minAchievementPct));
    CommissionRule? rule;
    for (final r in active) {
      if (_reached(r, basePaise, targetPaise)) {
        rule = r;
        break;
      }
    }
    final commission = rule == null ? 0 : (basePaise * _bp(rule.commissionPct) + 5000) ~/ 10000;
    final flat = rule?.flatBonusPaise ?? 0;

    CommissionRule? next;
    for (final r in active.reversed) {
      if (!_reached(r, basePaise, targetPaise) && (rule == null || r.minAchievementPct > rule.minAchievementPct)) {
        next = r;
        break;
      }
    }
    int? toNext;
    if (next != null && targetPaise > 0) {
      final needed = (_bp(next.minAchievementPct) * targetPaise + 9999) ~/ 10000; // ceil
      toNext = needed - basePaise;
    }

    return BonusResult(
      basePaise: basePaise,
      targetPaise: targetPaise,
      achievementPct: targetPaise > 0 ? (basePaise * 10000 / targetPaise).round() / 100 : 0,
      rule: rule,
      commissionPaise: commission,
      flatBonusPaise: flat,
      nextRule: next,
      paiseToNextRule: toNext,
    );
  }

  /// Net sales of completed bills for [salespersonId] within [month].
  static int monthlyBase(List<Sale> sales, String salespersonId, DateTime month) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    return sales
        .where((s) =>
            s.salespersonId == salespersonId &&
            !s.isCancelled &&
            !s.createdAt.isBefore(start) &&
            s.createdAt.isBefore(end))
        .fold<int>(0, (sum, s) => sum + s.taxablePaise);
  }
}
