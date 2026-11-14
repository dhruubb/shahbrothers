import 'package:flutter_test/flutter_test.dart';
import 'package:shah_brothers/core/utils/dates.dart';
import 'package:shah_brothers/core/utils/money.dart';
import 'package:shah_brothers/core/utils/validators.dart';
import 'package:shah_brothers/data/models/models.dart';
import 'package:shah_brothers/domain/analytics.dart';

Sale sale(String id, DateTime at, int totalPaise, {String sp = 'sp1', bool cancelled = false, String customer = 'c1'}) => Sale(
      id: id,
      invoiceNumber: id,
      customerId: customer,
      salespersonId: sp,
      managerId: 'm',
      subtotalPaise: totalPaise,
      discountPaise: 0,
      taxablePaise: totalPaise,
      gstRate: 0,
      cgstPaise: 0,
      sgstPaise: 0,
      gstPaise: 0,
      roundOffPaise: 0,
      totalPaise: totalPaise,
      paymentMode: PaymentMode.cash,
      status: cancelled ? SaleStatus.cancelled : SaleStatus.completed,
      createdAt: at,
      payments: [Payment(method: PaymentMethod.cash, amountPaise: totalPaise)],
      items: [
        SaleItem(
            productName: 'A',
            productCode: 'A',
            quantity: 2,
            unitPricePaise: totalPaise ~/ 2,
            discountType: DiscountType.amount,
            discountValue: 0,
            discountPaise: 0,
            lineTotalPaise: totalPaise),
      ],
    );

void main() {
  group('Money', () {
    test('Indian grouping', () {
      expect(Money.format(123456789, decimals: false), '₹12,34,568');
      expect(Money.format(123456789, decimals: true), '₹12,34,567.89');
      expect(Money.format(99900), '₹999');
      expect(Money.format(100000000), '₹10,00,000');
      expect(Money.format(-150050), '-₹1,500.50');
    });
    test('compact', () {
      expect(Money.compact(95000), '₹950');
      expect(Money.compact(1250000), '₹12.5K');
      expect(Money.compact(34200000), '₹3.42L');
      expect(Money.compact(1200000000), '₹1.2Cr');
    });
    test('parse and ascii', () {
      expect(Money.parse('1,250.50'), 125050);
      expect(Money.parse('abc'), isNull);
      expect(Money.ascii(125050), 'Rs. 1,250.50');
    });
  });

  group('Validators & dates', () {
    test('mobile numbers', () {
      expect(Validators.isMobile('98200 12345'), isTrue);
      expect(Validators.isMobile('+91 98200-12345'), isTrue);
      expect(Validators.isMobile('5820012345'), isFalse);
      expect(Validators.isMobile('98200'), isFalse);
    });
    test('financial year codes', () {
      expect(Dates.financialYearCode(DateTime(2026, 11, 13)), '26-27');
      expect(Dates.financialYearCode(DateTime(2027, 3, 31)), '26-27');
      expect(Dates.financialYearCode(DateTime(2027, 4, 1)), '27-28');
    });
  });

  group('Analytics', () {
    final now = DateTime(2026, 11, 13, 18);
    final sales = [
      sale('1', DateTime(2026, 11, 13, 12), 100000),
      sale('2', DateTime(2026, 11, 12, 12), 300000, sp: 'sp2', customer: 'c2'),
      sale('3', DateTime(2026, 11, 12, 15), 50000, cancelled: true),
      sale('4', DateTime(2026, 10, 2, 12), 250000),
    ];

    test('summary excludes cancelled bills', () {
      final s = Analytics.summarize(sales);
      expect(s.revenuePaise, 650000);
      expect(s.billCount, 3);
      expect(s.itemsSold, 6);
      expect(s.customerCount, 2);
      expect(s.averageBillPaise, 216667);
    });

    test('daily and monthly buckets', () {
      final d = Analytics.daily(sales, days: 7, now: now);
      expect(d.length, 7);
      expect(d.last.valuePaise, 100000);
      expect(d[5].valuePaise, 300000);
      final m = Analytics.monthly(sales, months: 3, now: now);
      expect(m.map((p) => p.valuePaise).toList(), [0, 250000, 400000]);
    });

    test('salesperson ranking and share', () {
      const staff = [
        AppUser(id: 'sp1', fullName: 'Priya S', email: 'a', role: UserRole.salesperson),
        AppUser(id: 'sp2', fullName: 'Rahul V', email: 'b', role: UserRole.salesperson),
        AppUser(id: 'm', fullName: 'Amit', email: 'c', role: UserRole.manager),
      ];
      final r = Analytics.bySalesperson(sales, staff);
      expect(r.length, 2);
      expect(r.first.user.id, 'sp1');
      expect(r.first.revenuePaise, 350000);
      expect(r.first.sharePct, closeTo(53.85, 0.01));
    });

    test('date range presets', () {
      final m = DateRangeFilter.forPreset(RangePreset.thisMonth, now: now);
      expect(m.start, DateTime(2026, 11));
      expect(m.end, DateTime(2026, 11, 14));
      final lm = DateRangeFilter.forPreset(RangePreset.lastMonth, now: now);
      expect(lm.start, DateTime(2026, 10));
      expect(lm.end, DateTime(2026, 11));
      expect(DateRangeFilter.forPreset(RangePreset.last7, now: now).days, 7);
      expect(DateRangeFilter.forPreset(RangePreset.financialYear, now: now).start, DateTime(2026, 4));
    });
  });
}
