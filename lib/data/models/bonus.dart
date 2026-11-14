import '../../core/utils/money.dart';
import 'enums.dart';

/// A finalised monthly bonus (row in the bonuses table).
class Bonus {
  const Bonus({
    required this.id,
    required this.salespersonId,
    required this.periodStart,
    required this.salesPaise,
    required this.targetPaise,
    required this.achievementPct,
    required this.commissionPct,
    required this.commissionPaise,
    required this.flatBonusPaise,
    required this.totalPaise,
    required this.status,
    this.ruleName,
    this.approvedAt,
    this.paidAt,
  });

  final String id;
  final String salespersonId;
  final DateTime periodStart;
  final int salesPaise;
  final int targetPaise;
  final double achievementPct;
  final String? ruleName;
  final double commissionPct;
  final int commissionPaise;
  final int flatBonusPaise;
  final int totalPaise;
  final BonusStatus status;
  final DateTime? approvedAt;
  final DateTime? paidAt;

  factory Bonus.fromJson(Map<String, dynamic> j) => Bonus(
        id: j['id'] as String,
        salespersonId: j['salesperson_id'] as String,
        periodStart: parseDateOnly(j['period_start'])!,
        salesPaise: Money.toPaise(j['sales_amount'] as num?),
        targetPaise: Money.toPaise(j['target_amount'] as num?),
        achievementPct: toDouble(j['achievement_pct']),
        ruleName: j['rule_name'] as String?,
        commissionPct: toDouble(j['commission_pct']),
        commissionPaise: Money.toPaise(j['commission_amount'] as num?),
        flatBonusPaise: Money.toPaise(j['flat_bonus'] as num?),
        totalPaise: Money.toPaise(j['total_bonus'] as num?),
        status: BonusStatus.parse(j['status'] as String?),
        approvedAt: parseDate(j['approved_at']),
        paidAt: parseDate(j['paid_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'salesperson_id': salespersonId,
        'period_start': encodeDateOnly(periodStart),
        'sales_amount': Money.toRupees(salesPaise),
        'target_amount': Money.toRupees(targetPaise),
        'achievement_pct': achievementPct,
        'rule_name': ruleName,
        'commission_pct': commissionPct,
        'commission_amount': Money.toRupees(commissionPaise),
        'flat_bonus': Money.toRupees(flatBonusPaise),
        'total_bonus': Money.toRupees(totalPaise),
        'status': status.name,
        'approved_at': encodeDate(approvedAt),
        'paid_at': encodeDate(paidAt),
      };
}
