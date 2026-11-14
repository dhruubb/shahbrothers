import 'package:flutter_test/flutter_test.dart';
import 'package:shah_brothers/data/models/models.dart';
import 'package:shah_brothers/domain/billing_calculator.dart';
import 'package:shah_brothers/domain/exceptions.dart';

SaleItemInput item(double price, {int qty = 1, DiscountType type = DiscountType.amount, double discount = 0}) =>
    SaleItemInput(
      productName: 'Saree',
      productCode: 'X',
      quantity: qty,
      unitPricePaise: (price * 100).round(),
      discountType: type,
      discountValue: discount,
    );

void main() {
  // Expected values come from the reference maths that the Supabase
  // create_sale_internal() function was tested against.
  group('BillingCalculator.compute', () {
    test('percent + amount discounts, 5% GST, negative round-off', () {
      final t = BillingCalculator.compute([
        item(24500, type: DiscountType.percent, discount: 7.5),
        item(149.99, qty: 3, discount: 50.5),
      ], 5);
      expect(t.subtotalPaise, 2494997);
      expect(t.discountPaise, 188800);
      expect(t.taxablePaise, 2306197);
      expect(t.gstPaise, 115310);
      expect(t.cgstPaise, 57655);
      expect(t.sgstPaise, 57655);
      expect(t.roundOffPaise, -7);
      expect(t.totalPaise, 2421500);
      expect(t.lines[0].discountPaise, 183750);
      expect(t.lines[1].netPaise, 44997 - 5050);
    });

    test('odd GST splits CGST up and rounds total up', () {
      final t = BillingCalculator.compute([
        item(1650, qty: 2, type: DiscountType.percent, discount: 10),
        item(3450.5),
      ], 5);
      expect(t.subtotalPaise, 675050);
      expect(t.discountPaise, 33000);
      expect(t.gstPaise, 32103);
      expect(t.cgstPaise, 16052);
      expect(t.sgstPaise, 16051);
      expect(t.cgstPaise + t.sgstPaise, t.gstPaise);
      expect(t.roundOffPaise, 47);
      expect(t.totalPaise, 674200);
    });

    test('configurable GST rate (12%)', () {
      final t = BillingCalculator.compute([item(999.99)], 12);
      expect(t.gstPaise, 12000);
      expect(t.totalPaise, 112000);
      expect(t.roundOffPaise, 1);
    });

    test('zero GST', () {
      final t = BillingCalculator.compute([item(1234.56, type: DiscountType.percent, discount: 15)], 0);
      expect(t.discountPaise, 18518);
      expect(t.gstPaise, 0);
      expect(t.totalPaise, 104900);
    });

    test('total is always whole rupees', () {
      for (var p = 100.01; p < 130; p += 3.37) {
        final t = BillingCalculator.compute([item(p, type: DiscountType.percent, discount: 3.3)], 5);
        expect(t.totalPaise % 100, 0);
        expect((t.totalPaise - (t.taxablePaise + t.gstPaise)).abs() <= 50, isTrue);
      }
    });

    test('rejects invalid lines', () {
      expect(() => BillingCalculator.compute([item(1000, discount: 1500)], 5), throwsA(isA<ValidationException>()));
      expect(() => BillingCalculator.compute([item(1000, type: DiscountType.percent, discount: 101)], 5),
          throwsA(isA<ValidationException>()));
      expect(() => BillingCalculator.compute([item(1000, qty: 0)], 5), throwsA(isA<ValidationException>()));
      expect(() => BillingCalculator.compute([item(1000)], 30), throwsA(isA<ValidationException>()));
    });

    test('preview never throws while typing', () {
      final t = BillingCalculator.preview([item(1000, discount: 5000), item(500)], 5);
      expect(t.subtotalPaise, 150000);
      expect(t.discountPaise, 0);
    });
  });

  group('validatePayments', () {
    const total = 674200;
    test('single method', () {
      expect(BillingCalculator.validatePayments([const Payment(method: PaymentMethod.upi, amountPaise: total)], total),
          PaymentMode.upi);
    });
    test('split', () {
      expect(
          BillingCalculator.validatePayments([
            const Payment(method: PaymentMethod.cash, amountPaise: 200000),
            const Payment(method: PaymentMethod.card, amountPaise: total - 200000),
          ], total),
          PaymentMode.split);
    });
    test('mismatch and empty are rejected', () {
      expect(() => BillingCalculator.validatePayments([const Payment(method: PaymentMethod.cash, amountPaise: total - 100)], total),
          throwsA(isA<ValidationException>()));
      expect(() => BillingCalculator.validatePayments([], total), throwsA(isA<ValidationException>()));
      expect(
          () => BillingCalculator.validatePayments([
                const Payment(method: PaymentMethod.cash, amountPaise: total),
                const Payment(method: PaymentMethod.upi, amountPaise: 0),
              ], total),
          throwsA(isA<ValidationException>()));
    });
  });
}
