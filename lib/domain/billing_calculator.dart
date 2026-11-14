import '../data/models/models.dart';
import 'exceptions.dart';

/// Amounts for one bill line, in paise.
class LineAmounts {
  const LineAmounts({required this.grossPaise, required this.discountPaise});
  final int grossPaise;
  final int discountPaise;
  int get netPaise => grossPaise - discountPaise;
}

/// Bill totals, in paise.
class BillTotals {
  const BillTotals({
    required this.lines,
    required this.subtotalPaise,
    required this.discountPaise,
    required this.taxablePaise,
    required this.gstRate,
    required this.gstPaise,
    required this.cgstPaise,
    required this.sgstPaise,
    required this.roundOffPaise,
    required this.totalPaise,
  });

  static const empty = BillTotals(
    lines: [],
    subtotalPaise: 0,
    discountPaise: 0,
    taxablePaise: 0,
    gstRate: 0,
    gstPaise: 0,
    cgstPaise: 0,
    sgstPaise: 0,
    roundOffPaise: 0,
    totalPaise: 0,
  );

  final List<LineAmounts> lines;
  final int subtotalPaise;
  final int discountPaise;
  final int taxablePaise;
  final double gstRate;
  final int gstPaise;
  final int cgstPaise;
  final int sgstPaise;
  final int roundOffPaise;
  final int totalPaise;

  int get itemCount => lines.length;
}

/// Single source of truth for bill maths in the app.
///
/// MUST stay identical to `create_sale_internal()` in
/// supabase/migrations/0001_init.sql and `compute()` in tool/generate_seed.py:
///   gross     = qty × unit price
///   discount  = percent: round½↑(gross × pct / 100); amount: value (≤ gross)
///   taxable   = subtotal − discounts
///   gst       = round½↑(taxable × rate / 100); CGST = ⌈gst/2⌉, SGST = rest
///   total     = taxable + gst, rounded ½↑ to whole rupees
class BillingCalculator {
  const BillingCalculator._();

  static int _bp(double value) => (value * 100).round();

  static int lineDiscountPaise(int grossPaise, DiscountType type, double value) {
    if (value == 0) return 0;
    if (value < 0) throw const ValidationException('Discount cannot be negative');
    if (type == DiscountType.percent) {
      if (value > 100) throw const ValidationException('Discount cannot exceed 100%');
      return (grossPaise * _bp(value) + 5000) ~/ 10000;
    }
    final d = _bp(value);
    if (d > grossPaise) throw const ValidationException('Discount is more than the item value');
    return d;
  }

  static LineAmounts line(SaleItemInput item) {
    if (item.quantity <= 0) throw const ValidationException('Quantity must be at least 1');
    if (item.unitPricePaise < 0) throw const ValidationException('Price cannot be negative');
    final gross = item.quantity * item.unitPricePaise;
    return LineAmounts(
      grossPaise: gross,
      discountPaise: lineDiscountPaise(gross, item.discountType, item.discountValue),
    );
  }

  static BillTotals compute(List<SaleItemInput> items, double gstRatePct) {
    if (gstRatePct < 0 || gstRatePct > 28) {
      throw const ValidationException('GST rate must be between 0% and 28%');
    }
    final lines = items.map(line).toList();
    final subtotal = lines.fold<int>(0, (s, l) => s + l.grossPaise);
    final discount = lines.fold<int>(0, (s, l) => s + l.discountPaise);
    final taxable = subtotal - discount;
    final gst = (taxable * _bp(gstRatePct) + 5000) ~/ 10000;
    final cgst = (gst + 1) ~/ 2;
    final pre = taxable + gst;
    final total = ((pre + 50) ~/ 100) * 100;
    return BillTotals(
      lines: lines,
      subtotalPaise: subtotal,
      discountPaise: discount,
      taxablePaise: taxable,
      gstRate: gstRatePct,
      gstPaise: gst,
      cgstPaise: cgst,
      sgstPaise: gst - cgst,
      roundOffPaise: total - pre,
      totalPaise: total,
    );
  }

  /// Like [compute] but never throws — invalid lines count as zero. Used for
  /// live totals while the user is still typing.
  static BillTotals preview(List<SaleItemInput> items, double gstRatePct) {
    try {
      return compute(items, gstRatePct);
    } on ValidationException {
      final safe = items.map((i) {
        try {
          line(i);
          return i;
        } on ValidationException {
          return i.copyWith(discountValue: 0, quantity: i.quantity <= 0 ? 1 : i.quantity);
        }
      }).toList();
      try {
        return compute(safe, gstRatePct.clamp(0, 28).toDouble());
      } on ValidationException {
        return BillTotals.empty;
      }
    }
  }

  /// Validates the payments against the bill total and returns the mode.
  static PaymentMode validatePayments(List<Payment> payments, int totalPaise) {
    if (payments.isEmpty) throw const ValidationException('Record at least one payment');
    for (final p in payments) {
      if (p.amountPaise <= 0) throw const ValidationException('Payment amounts must be more than zero');
    }
    final sum = payments.fold<int>(0, (s, p) => s + p.amountPaise);
    if (sum != totalPaise) {
      throw ValidationException(
          'Payments add up to ₹${(sum / 100).toStringAsFixed(2)} but the bill total is ₹${(totalPaise / 100).toStringAsFixed(2)}');
    }
    final methods = payments.map((p) => p.method).toSet();
    if (methods.length == 1 && payments.length == 1) {
      return PaymentMode.values.byName(methods.first.name);
    }
    return PaymentMode.split;
  }
}
