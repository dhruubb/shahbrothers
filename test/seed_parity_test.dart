import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shah_brothers/data/models/models.dart';
import 'package:shah_brothers/domain/billing_calculator.dart';

/// The seed generator (Python), the Supabase SQL function and the Dart
/// calculator must agree to the paisa. Supabase rejects a seeded sale when
/// they do not; this test checks the Dart side.
void main() {
  final seed = jsonDecode(File('assets/demo/seed.json').readAsStringSync()) as Map<String, dynamic>;

  test('demo data meets the brief', () {
    final users = (seed['users'] as List).cast<Map<String, dynamic>>();
    expect(users.where((u) => u['role'] == 'owner').length, 1);
    expect(users.where((u) => u['role'] == 'manager').length, 2);
    expect(users.where((u) => u['role'] == 'salesperson').length, greaterThanOrEqualTo(5));
    expect((seed['customers'] as List).length, greaterThanOrEqualTo(30));
    expect((seed['products'] as List).length, greaterThanOrEqualTo(25));
    expect((seed['sales'] as List).length, greaterThanOrEqualTo(50));
    final methods = (seed['sales'] as List)
        .expand((s) => (s['payments'] as List).map((p) => p['method']))
        .toSet();
    expect(methods, containsAll(['cash', 'upi', 'card']));
  });

  test('Dart totals match generator totals for every seeded bill', () {
    final sales = (seed['sales'] as List).cast<Map<String, dynamic>>();
    final expected = (seed['expected_totals'] as List).cast<Map<String, dynamic>>();
    final gst = (seed['settings']['gst_rate'] as num).toDouble();
    for (var i = 0; i < sales.length; i++) {
      final items = (sales[i]['items'] as List).cast<Map<String, dynamic>>().map(SaleItemInput.fromJson).toList();
      final t = BillingCalculator.compute(items, gst);
      expect(t.subtotalPaise, expected[i]['subtotal'], reason: 'sale $i subtotal');
      expect(t.discountPaise, expected[i]['discount'], reason: 'sale $i discount');
      expect(t.taxablePaise, expected[i]['taxable'], reason: 'sale $i taxable');
      expect(t.gstPaise, expected[i]['gst'], reason: 'sale $i gst');
      expect(t.totalPaise, expected[i]['total'], reason: 'sale $i total');
      final paid = (sales[i]['payments'] as List).fold<int>(0, (s, p) => s + ((p['amount'] as num) * 100).round());
      expect(paid, t.totalPaise, reason: 'sale $i payments');
    }
  });
}
