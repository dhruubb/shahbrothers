import '../core/utils/dates.dart';
import '../data/models/models.dart';

/// Date range presets for dashboards and reports.
enum RangePreset {
  today('Today'),
  last7('7 days'),
  last30('30 days'),
  thisMonth('This month'),
  lastMonth('Last month'),
  last90('90 days'),
  financialYear('This FY'),
  custom('Custom');

  const RangePreset(this.label);
  final String label;
}

/// A half-open [start, end) date range.
class DateRangeFilter {
  const DateRangeFilter(this.preset, this.start, this.end);

  final RangePreset preset;
  final DateTime start;
  final DateTime end; // exclusive

  factory DateRangeFilter.forPreset(RangePreset preset, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final today = Dates.startOfDay(n);
    final tomorrow = today.add(const Duration(days: 1));
    switch (preset) {
      case RangePreset.today:
        return DateRangeFilter(preset, today, tomorrow);
      case RangePreset.last7:
        return DateRangeFilter(preset, today.subtract(const Duration(days: 6)), tomorrow);
      case RangePreset.last30:
        return DateRangeFilter(preset, today.subtract(const Duration(days: 29)), tomorrow);
      case RangePreset.last90:
        return DateRangeFilter(preset, today.subtract(const Duration(days: 89)), tomorrow);
      case RangePreset.thisMonth:
        return DateRangeFilter(preset, Dates.startOfMonth(n), tomorrow);
      case RangePreset.lastMonth:
        return DateRangeFilter(preset, Dates.addMonths(n, -1), Dates.startOfMonth(n));
      case RangePreset.financialYear:
        final fyStart = DateTime(n.month >= 4 ? n.year : n.year - 1, 4);
        return DateRangeFilter(preset, fyStart, tomorrow);
      case RangePreset.custom:
        return DateRangeFilter(preset, today.subtract(const Duration(days: 29)), tomorrow);
    }
  }

  factory DateRangeFilter.custom(DateTime first, DateTime lastInclusive) => DateRangeFilter(
        RangePreset.custom,
        Dates.startOfDay(first),
        Dates.startOfDay(lastInclusive).add(const Duration(days: 1)),
      );

  DateTime get lastDay => end.subtract(const Duration(days: 1));
  int get days => (end.difference(start).inHours / 24).round();

  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(end);

  String get label => preset == RangePreset.custom
      ? '${Dates.dayShort(start)} – ${Dates.dayShort(lastDay)}'
      : preset.label;

  @override
  bool operator ==(Object other) =>
      other is DateRangeFilter && other.preset == preset && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(preset, start, end);
}

class SalesSummary {
  const SalesSummary({
    required this.revenuePaise,
    required this.netSalesPaise,
    required this.gstPaise,
    required this.discountPaise,
    required this.billCount,
    required this.itemsSold,
    required this.customerCount,
  });

  /// Total billed incl. GST.
  final int revenuePaise;

  /// Taxable value excl. GST (basis for bonuses).
  final int netSalesPaise;
  final int gstPaise;
  final int discountPaise;
  final int billCount;
  final int itemsSold;
  final int customerCount;

  int get averageBillPaise => billCount == 0 ? 0 : (revenuePaise / billCount).round();
}

class SeriesPoint {
  const SeriesPoint(this.start, this.label, this.valuePaise, this.count);
  final DateTime start;
  final String label;
  final int valuePaise;
  final int count;
}

class SalespersonPerformance {
  const SalespersonPerformance({
    required this.user,
    required this.revenuePaise,
    required this.netSalesPaise,
    required this.billCount,
    required this.itemsSold,
    required this.sharePct,
  });

  final AppUser user;
  final int revenuePaise;
  final int netSalesPaise;
  final int billCount;
  final int itemsSold;
  final double sharePct;
  int get averageBillPaise => billCount == 0 ? 0 : (revenuePaise / billCount).round();
}

class BreakdownEntry {
  const BreakdownEntry(this.label, this.valuePaise, this.count);
  final String label;
  final int valuePaise;
  final int count;
}

enum ChartGranularity {
  daily('Daily'),
  weekly('Weekly'),
  monthly('Monthly');

  const ChartGranularity(this.label);
  final String label;
}

/// Pure analytics over a list of sales. Cancelled bills are excluded.
class Analytics {
  const Analytics._();

  static Iterable<Sale> completed(Iterable<Sale> sales) => sales.where((s) => !s.isCancelled);

  static SalesSummary summarize(Iterable<Sale> sales) {
    var revenue = 0, net = 0, gst = 0, disc = 0, bills = 0, items = 0;
    final customers = <String>{};
    for (final s in completed(sales)) {
      revenue += s.totalPaise;
      net += s.taxablePaise;
      gst += s.gstPaise;
      disc += s.discountPaise;
      bills++;
      items += s.itemCount;
      customers.add(s.customerId);
    }
    return SalesSummary(
      revenuePaise: revenue,
      netSalesPaise: net,
      gstPaise: gst,
      discountPaise: disc,
      billCount: bills,
      itemsSold: items,
      customerCount: customers.length,
    );
  }

  /// One point per day for the last [days] days ending today.
  static List<SeriesPoint> daily(Iterable<Sale> sales, {int days = 14, DateTime? now}) {
    final today = Dates.startOfDay(now ?? DateTime.now());
    final buckets = List.generate(days, (i) => today.subtract(Duration(days: days - 1 - i)));
    return _bucket(sales, buckets, (d) => d.add(const Duration(days: 1)),
        (d) => days <= 7 ? Dates.weekday(d) : '${d.day}');
  }

  /// One point per week (Mon–Sun) for the last [weeks] weeks.
  static List<SeriesPoint> weekly(Iterable<Sale> sales, {int weeks = 12, DateTime? now}) {
    final thisWeek = Dates.startOfWeek(now ?? DateTime.now());
    final buckets = List.generate(weeks, (i) => thisWeek.subtract(Duration(days: 7 * (weeks - 1 - i))));
    return _bucket(sales, buckets, (d) => d.add(const Duration(days: 7)), Dates.dayShort);
  }

  /// One point per calendar month for the last [months] months.
  static List<SeriesPoint> monthly(Iterable<Sale> sales, {int months = 6, DateTime? now}) {
    final n = now ?? DateTime.now();
    final buckets = List.generate(months, (i) => Dates.addMonths(n, -(months - 1 - i)));
    return _bucket(sales, buckets, (d) => Dates.addMonths(d, 1), Dates.monthShort);
  }

  static List<SeriesPoint> series(Iterable<Sale> sales, ChartGranularity g, {DateTime? now}) => switch (g) {
        ChartGranularity.daily => daily(sales, now: now),
        ChartGranularity.weekly => weekly(sales, now: now),
        ChartGranularity.monthly => monthly(sales, now: now),
      };

  /// Earliest date the chart for [g] needs.
  static DateTime seriesStart(ChartGranularity g, {DateTime? now}) {
    final n = now ?? DateTime.now();
    return switch (g) {
      ChartGranularity.daily => Dates.startOfDay(n).subtract(const Duration(days: 13)),
      ChartGranularity.weekly => Dates.startOfWeek(n).subtract(const Duration(days: 7 * 11)),
      ChartGranularity.monthly => Dates.addMonths(n, -5),
    };
  }

  static List<SeriesPoint> _bucket(
    Iterable<Sale> sales,
    List<DateTime> starts,
    DateTime Function(DateTime) next,
    String Function(DateTime) label,
  ) {
    final values = List<int>.filled(starts.length, 0);
    final counts = List<int>.filled(starts.length, 0);
    if (starts.isEmpty) return const [];
    final first = starts.first;
    final last = next(starts.last);
    for (final s in completed(sales)) {
      final t = s.createdAt;
      if (t.isBefore(first) || !t.isBefore(last)) continue;
      for (var i = starts.length - 1; i >= 0; i--) {
        if (!t.isBefore(starts[i])) {
          values[i] += s.totalPaise;
          counts[i]++;
          break;
        }
      }
    }
    return [for (var i = 0; i < starts.length; i++) SeriesPoint(starts[i], label(starts[i]), values[i], counts[i])];
  }

  static List<SalespersonPerformance> bySalesperson(Iterable<Sale> sales, List<AppUser> staff) {
    final people = staff.where((u) => u.role == UserRole.salesperson).toList();
    final revenue = <String, int>{}, net = <String, int>{}, bills = <String, int>{}, items = <String, int>{};
    var total = 0;
    for (final s in completed(sales)) {
      revenue[s.salespersonId] = (revenue[s.salespersonId] ?? 0) + s.totalPaise;
      net[s.salespersonId] = (net[s.salespersonId] ?? 0) + s.taxablePaise;
      bills[s.salespersonId] = (bills[s.salespersonId] ?? 0) + 1;
      items[s.salespersonId] = (items[s.salespersonId] ?? 0) + s.itemCount;
      total += s.totalPaise;
    }
    final list = people
        .map((u) => SalespersonPerformance(
              user: u,
              revenuePaise: revenue[u.id] ?? 0,
              netSalesPaise: net[u.id] ?? 0,
              billCount: bills[u.id] ?? 0,
              itemsSold: items[u.id] ?? 0,
              sharePct: total == 0 ? 0 : (revenue[u.id] ?? 0) * 100 / total,
            ))
        .toList()
      ..sort((a, b) => b.revenuePaise.compareTo(a.revenuePaise));
    return list;
  }

  /// Collected amounts per payment method (split bills counted per part).
  static List<BreakdownEntry> byPaymentMethod(Iterable<Sale> sales) {
    final amounts = {for (final m in PaymentMethod.values) m: 0};
    final counts = {for (final m in PaymentMethod.values) m: 0};
    for (final s in completed(sales)) {
      for (final p in s.payments) {
        amounts[p.method] = amounts[p.method]! + p.amountPaise;
        counts[p.method] = counts[p.method]! + 1;
      }
    }
    return PaymentMethod.values.map((m) => BreakdownEntry(m.label, amounts[m]!, counts[m]!)).toList();
  }

  /// Net line value per product category (needs product catalogue).
  static List<BreakdownEntry> byCategory(Iterable<Sale> sales, List<Product> products) {
    final catById = {for (final p in products) p.id: p.category};
    final catBySku = {for (final p in products) p.sku: p.category};
    final amounts = <String, int>{}, counts = <String, int>{};
    for (final s in completed(sales)) {
      for (final i in s.items) {
        final cat = catById[i.productId] ?? catBySku[i.productCode] ?? 'Other';
        amounts[cat] = (amounts[cat] ?? 0) + i.lineTotalPaise;
        counts[cat] = (counts[cat] ?? 0) + i.quantity;
      }
    }
    return amounts.entries.map((e) => BreakdownEntry(e.key, e.value, counts[e.key]!)).toList()
      ..sort((a, b) => b.valuePaise.compareTo(a.valuePaise));
  }

  /// Top products by quantity sold.
  static List<BreakdownEntry> topProducts(Iterable<Sale> sales, {int limit = 5}) {
    final amounts = <String, int>{}, counts = <String, int>{};
    for (final s in completed(sales)) {
      for (final i in s.items) {
        amounts[i.productName] = (amounts[i.productName] ?? 0) + i.lineTotalPaise;
        counts[i.productName] = (counts[i.productName] ?? 0) + i.quantity;
      }
    }
    final list = amounts.entries.map((e) => BreakdownEntry(e.key, e.value, counts[e.key]!)).toList()
      ..sort((a, b) => b.valuePaise.compareTo(a.valuePaise));
    return list.take(limit).toList();
  }

  /// Purchase stats per customer.
  static Map<String, CustomerStats> customerStats(Iterable<Sale> sales) {
    final count = <String, int>{}, spent = <String, int>{};
    final last = <String, DateTime>{};
    for (final s in completed(sales)) {
      count[s.customerId] = (count[s.customerId] ?? 0) + 1;
      spent[s.customerId] = (spent[s.customerId] ?? 0) + s.totalPaise;
      final l = last[s.customerId];
      if (l == null || s.createdAt.isAfter(l)) last[s.customerId] = s.createdAt;
    }
    return {
      for (final id in count.keys)
        id: CustomerStats(
            customerId: id, purchaseCount: count[id]!, totalSpentPaise: spent[id]!, lastPurchaseAt: last[id]),
    };
  }

  /// Percentage change from [previous] to [current]; null when no baseline.
  static double? growthPct(int current, int previous) =>
      previous == 0 ? null : (current - previous) * 100 / previous;
}
