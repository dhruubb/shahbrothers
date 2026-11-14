import '../../core/utils/money.dart';
import 'enums.dart';

class AppSettings {
  const AppSettings({
    this.storeName = 'Shah Brothers',
    this.tagline,
    this.address,
    this.phone,
    this.email,
    this.gstin,
    this.gstRate = 5,
    this.invoicePrefix = 'SB',
    this.invoiceFooter,
  });

  final String storeName;
  final String? tagline;
  final String? address;
  final String? phone;
  final String? email;
  final String? gstin;

  /// Percent, e.g. 5.0. Split equally into CGST + SGST on invoices.
  final double gstRate;
  final String invoicePrefix;
  final String? invoiceFooter;

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        storeName: j['store_name'] as String? ?? 'Shah Brothers',
        tagline: j['tagline'] as String?,
        address: j['address'] as String?,
        phone: j['phone'] as String?,
        email: j['email'] as String?,
        gstin: j['gstin'] as String?,
        gstRate: toDouble(j['gst_rate']),
        invoicePrefix: j['invoice_prefix'] as String? ?? 'SB',
        invoiceFooter: j['invoice_footer'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'store_name': storeName,
        'tagline': tagline,
        'address': address,
        'phone': phone,
        'email': email,
        'gstin': gstin,
        'gst_rate': gstRate,
        'invoice_prefix': invoicePrefix,
        'invoice_footer': invoiceFooter,
      };

  AppSettings copyWith({
    String? storeName,
    String? tagline,
    String? address,
    String? phone,
    String? email,
    String? gstin,
    double? gstRate,
    String? invoicePrefix,
    String? invoiceFooter,
  }) =>
      AppSettings(
        storeName: storeName ?? this.storeName,
        tagline: tagline ?? this.tagline,
        address: address ?? this.address,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        gstin: gstin ?? this.gstin,
        gstRate: gstRate ?? this.gstRate,
        invoicePrefix: invoicePrefix ?? this.invoicePrefix,
        invoiceFooter: invoiceFooter ?? this.invoiceFooter,
      );
}

/// A bonus slab. The highest slab whose [minAchievementPct] the salesperson
/// reaches in a month applies: commission on net sales + a flat bonus.
class CommissionRule {
  const CommissionRule({
    required this.id,
    required this.name,
    required this.minAchievementPct,
    required this.commissionPct,
    this.flatBonusPaise = 0,
    this.isActive = true,
  });

  final String id;
  final String name;
  final double minAchievementPct;
  final double commissionPct;
  final int flatBonusPaise;
  final bool isActive;

  factory CommissionRule.fromJson(Map<String, dynamic> j) => CommissionRule(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        minAchievementPct: toDouble(j['min_achievement_pct']),
        commissionPct: toDouble(j['commission_pct']),
        flatBonusPaise: Money.toPaise(j['flat_bonus'] as num?),
        isActive: j['is_active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'min_achievement_pct': minAchievementPct,
        'commission_pct': commissionPct,
        'flat_bonus': Money.toRupees(flatBonusPaise),
        'is_active': isActive,
      };

  CommissionRule copyWith({
    String? id,
    String? name,
    double? minAchievementPct,
    double? commissionPct,
    int? flatBonusPaise,
    bool? isActive,
  }) =>
      CommissionRule(
        id: id ?? this.id,
        name: name ?? this.name,
        minAchievementPct: minAchievementPct ?? this.minAchievementPct,
        commissionPct: commissionPct ?? this.commissionPct,
        flatBonusPaise: flatBonusPaise ?? this.flatBonusPaise,
        isActive: isActive ?? this.isActive,
      );
}
