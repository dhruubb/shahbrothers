import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shah_brothers/data/models/models.dart';
import 'package:shah_brothers/data/repositories/data_repository.dart';
import 'package:shah_brothers/data/repositories/local_persistence.dart';
import 'package:shah_brothers/data/repositories/local_repository.dart';
import 'package:shah_brothers/domain/analytics.dart';
import 'package:shah_brothers/domain/exceptions.dart';

/// End-to-end tests of the billing and role-permission workflows against the
/// local demo backend (which mirrors the Supabase RLS rules).
void main() {
  final seedJson = jsonDecode(File('assets/demo/seed.json').readAsStringSync()) as Map<String, dynamic>;
  final now = DateTime(2026, 11, 13, 18, 30);

  late MemoryLocalPersistence store;
  late LocalRepository repo;

  LocalRepository newRepo() => LocalRepository(
        persistence: store,
        seedLoader: () async => seedJson,
        clock: () => now,
      );

  setUp(() async {
    store = MemoryLocalPersistence();
    repo = newRepo();
    await repo.init();
  });

  Future<AppUser> login(String email, String password) => repo.signIn(email, password);
  Future<AppUser> asOwner() => login('owner@shahbrothers.in', 'Owner@123');
  Future<AppUser> asManager() => login('manager@shahbrothers.in', 'Manager@123');
  Future<AppUser> asPriya() => login('priya@shahbrothers.in', 'Sales@123');

  Future<SaleInput> sampleBill({String? customerId, String name = 'Leela Rao', String phone = '9012345678', int? payPaise}) async {
    await asManager();
    final products = await repo.getProducts();
    final kanj = products.firstWhere((p) => p.sku == 'KAN-001');
    final sp = (await repo.getStaff()).firstWhere((u) => u.email == 'rahul@shahbrothers.in');
    final items = [
      SaleItemInput(
        productId: kanj.id,
        productName: kanj.name,
        productCode: kanj.sku,
        quantity: 1,
        unitPricePaise: kanj.sellingPricePaise,
        discountType: DiscountType.percent,
        discountValue: 7.5,
      ),
      const SaleItemInput(productName: 'Fall & pico', productCode: 'SRV', quantity: 3, unitPricePaise: 14999, discountValue: 50.5),
    ];
    // ₹24,215 — verified against Postgres in the SQL tests
    final total = payPaise ?? 2421500;
    return SaleInput(
      customerId: customerId,
      customerName: name,
      customerPhone: phone,
      salespersonId: sp.id,
      items: items,
      payments: [
        const Payment(method: PaymentMethod.cash, amountPaise: 500000),
        Payment(method: PaymentMethod.upi, amountPaise: total - 500000, reference: 'UPI123'),
      ],
    );
  }

  group('seeded demo data', () {
    test('is complete and consistent', () async {
      await asOwner();
      final staff = await repo.getStaff();
      expect(staff.length, 9);
      expect((await repo.getCustomers()).length, greaterThanOrEqualTo(30));
      expect((await repo.getProducts()).length, greaterThanOrEqualTo(25));
      final sales = await repo.getSales(const SalesQuery());
      expect(sales.length, greaterThanOrEqualTo(50));
      expect(sales.map((s) => s.invoiceNumber).toSet().length, sales.length);
      expect(sales.every((s) => s.customerName.isNotEmpty && s.salespersonName.isNotEmpty && s.managerName.isNotEmpty), isTrue);
      expect(sales.every((s) => s.payments.fold<int>(0, (a, p) => a + p.amountPaise) == s.totalPaise), isTrue);
      expect(sales.every((s) => !s.createdAt.isAfter(now)), isTrue);
      expect((await repo.getProducts()).every((p) => p.stockQty >= 0), isTrue);
      // invoice numbers are sequential in time order
      final ordered = [...sales]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      expect(ordered.first.invoiceNumber, 'SB/26-27/00001');
      // three months of bonuses, older two paid
      final bonuses = await repo.getBonuses();
      expect(bonuses.length, 3 * 6);
      expect(bonuses.where((b) => b.status == BonusStatus.paid).length, 2 * 6);
      // last 30 days have activity for the dashboard
      final recent = await repo.getSales(SalesQuery(from: now.subtract(const Duration(days: 30))));
      expect(Analytics.summarize(recent).billCount, greaterThan(10));
    });

    test('persists across restarts, including the session', () async {
      await asManager();
      final before = (await repo.getSales(const SalesQuery())).length;
      final reopened = newRepo();
      final restored = await reopened.restoreSession();
      expect(restored?.email, 'manager@shahbrothers.in');
      expect((await reopened.getSales(const SalesQuery())).length, before);
    });
  });

  group('authentication', () {
    test('every demo credential works', () async {
      final creds = await repo.demoCredentials();
      expect(creds.map((c) => c.role).toSet(), UserRole.values.toSet());
      for (final c in creds) {
        final u = await repo.signIn(c.email, c.password);
        expect(u.role, c.role);
      }
    });

    test('wrong password and unknown user fail', () async {
      await expectLater(repo.signIn('owner@shahbrothers.in', 'wrong'), throwsA(isA<AuthFailedException>()));
      await expectLater(repo.signIn('nobody@shahbrothers.in', 'Owner@123'), throwsA(isA<AuthFailedException>()));
    });

    test('sign out clears the session', () async {
      await asOwner();
      await repo.signOut();
      expect(repo.currentUser, isNull);
      expect(await newRepo().restoreSession(), isNull);
      await expectLater(repo.getSales(const SalesQuery()), throwsA(isA<PermissionDeniedException>()));
    });
  });

  group('billing workflow (manager)', () {
    test('creates a split-payment bill with a new customer', () async {
      final input = await sampleBill();
      final stockBefore = (await repo.getProducts()).firstWhere((p) => p.sku == 'KAN-001').stockQty;
      final countBefore = (await repo.getSales(const SalesQuery())).length;
      final sale = await repo.createSale(input);

      expect(sale.invoiceNumber, 'SB/26-27/${(countBefore + 1).toString().padLeft(5, '0')}');
      expect(sale.subtotalPaise, 2494997);
      expect(sale.discountPaise, 188800);
      expect(sale.gstPaise, 115310);
      expect(sale.cgstPaise + sale.sgstPaise, sale.gstPaise);
      expect(sale.roundOffPaise, -7);
      expect(sale.totalPaise, 2421500);
      expect(sale.paymentMode, PaymentMode.split);
      expect(sale.customerName, 'Leela Rao');
      expect(sale.salespersonName, 'Rahul Verma');
      expect(sale.managerName, 'Amit Shah');
      expect(sale.items.length, 2);
      expect(sale.items.first.productCode, 'KAN-001');
      expect((await repo.getProducts()).firstWhere((p) => p.sku == 'KAN-001').stockQty, stockBefore - 1);
      expect((await repo.getCustomers()).where((c) => c.phone == '9012345678').length, 1);
      expect((await repo.getCustomerStats())[sale.customerId]!.purchaseCount, 1);
    });

    test('reuses an existing customer by phone', () async {
      await repo.createSale(await sampleBill());
      final second = await repo.createSale(await sampleBill(name: 'Someone Else'));
      expect(second.customerName, 'Leela Rao');
      expect((await repo.getCustomers()).where((c) => c.phone == '9012345678').length, 1);
      expect((await repo.getCustomerStats())[second.customerId]!.purchaseCount, 2);
    });

    test('rejects a payment mismatch without side effects', () async {
      await asManager();
      final countBefore = (await repo.getSales(const SalesQuery())).length;
      final customersBefore = (await repo.getCustomers()).length;
      await expectLater(repo.createSale(await sampleBill(payPaise: 2421400)), throwsA(isA<ValidationException>()));
      expect((await repo.getSales(const SalesQuery())).length, countBefore);
      expect((await repo.getCustomers()).length, customersBefore);
      // the next invoice number was not consumed
      final sale = await repo.createSale(await sampleBill());
      expect(sale.invoiceNumber, endsWith((countBefore + 1).toString().padLeft(5, '0')));
    });

    test('validates customer details and salesperson', () async {
      final bad = await sampleBill(phone: '12345');
      await expectLater(repo.createSale(bad), throwsA(isA<ValidationException>()));
      final input = await sampleBill();
      final mgrId = repo.currentUser!.id;
      final wrongSp = SaleInput(
        customerId: null,
        customerName: input.customerName,
        customerPhone: input.customerPhone,
        salespersonId: mgrId,
        items: input.items,
        payments: input.payments,
      );
      await expectLater(repo.createSale(wrongSp), throwsA(isA<ValidationException>()));
    });

    test('GST rate change applies to new bills', () async {
      await asOwner();
      final s = await repo.getSettings();
      await repo.updateSettings(s.copyWith(gstRate: 12));
      final input = await sampleBill(payPaise: 2583000); // 23061.97 + 12% = 25829.41 -> 25829
      await expectLater(repo.createSale(input), throwsA(isA<ValidationException>()));
      final ok = await sampleBill(payPaise: 2582900);
      final sale = await repo.createSale(ok);
      expect(sale.gstRate, 12);
      expect(sale.totalPaise, 2582900);
    });
  });

  group('role permissions', () {
    test('salesperson sees only their own sales, customers and bonuses', () async {
      final me = await asPriya();
      final sales = await repo.getSales(const SalesQuery());
      expect(sales, isNotEmpty);
      expect(sales.every((s) => s.salespersonId == me.id), isTrue);
      final customers = await repo.getCustomers();
      expect(customers.map((c) => c.id).toSet(), sales.map((s) => s.customerId).toSet());
      final bonuses = await repo.getBonuses();
      expect(bonuses, isNotEmpty);
      expect(bonuses.every((b) => b.salespersonId == me.id), isTrue);
      // cannot read another salesperson's invoice
      await asOwner();
      final other = (await repo.getSales(const SalesQuery())).firstWhere((s) => s.salespersonId != me.id);
      await asPriya();
      expect(await repo.getSale(other.id), isNull);
    });

    test('salesperson cannot bill, edit products/customers or settings', () async {
      final input = await sampleBill();
      await asPriya();
      await expectLater(repo.createSale(input), throwsA(isA<PermissionDeniedException>()));
      final p = (await repo.getProducts()).first;
      await expectLater(repo.saveProduct(p), throwsA(isA<PermissionDeniedException>()));
      await expectLater(repo.saveCustomer(const Customer(id: '', name: 'A', phone: '9876543210')),
          throwsA(isA<PermissionDeniedException>()));
      await expectLater(repo.updateSettings(const AppSettings()), throwsA(isA<PermissionDeniedException>()));
    });

    test('manager cannot cancel, see bonuses, change settings or rules', () async {
      await asManager();
      final sale = (await repo.getSales(const SalesQuery())).first;
      await expectLater(repo.cancelSale(sale.id, 'x'), throwsA(isA<PermissionDeniedException>()));
      expect(await repo.getBonuses(), isEmpty);
      await expectLater(repo.finalizeBonuses(DateTime(2026, 10)), throwsA(isA<PermissionDeniedException>()));
      await expectLater(repo.updateSettings(const AppSettings(gstRate: 12)), throwsA(isA<PermissionDeniedException>()));
      await expectLater(repo.saveCommissionRules(const []), throwsA(isA<PermissionDeniedException>()));
      await expectLater(repo.updateStaff((await repo.getStaff()).last), throwsA(isA<PermissionDeniedException>()));
    });

    test('owner cancels an invoice: stock restored, excluded from analytics', () async {
      final sale = await repo.createSale(await sampleBill());
      await asOwner();
      final stock = (await repo.getProducts()).firstWhere((p) => p.sku == 'KAN-001').stockQty;
      final revenueBefore = Analytics.summarize(await repo.getSales(const SalesQuery())).revenuePaise;
      await expectLater(repo.cancelSale(sale.id, ''), throwsA(isA<ValidationException>()));
      await repo.cancelSale(sale.id, 'Customer returned');
      final after = await repo.getSale(sale.id);
      expect(after!.isCancelled, isTrue);
      expect(after.cancelReason, 'Customer returned');
      expect((await repo.getProducts()).firstWhere((p) => p.sku == 'KAN-001').stockQty, stock + 1);
      expect(Analytics.summarize(await repo.getSales(const SalesQuery())).revenuePaise, revenueBefore - sale.totalPaise);
      await expectLater(repo.cancelSale(sale.id, 'again'), throwsA(isA<ValidationException>()));
    });

    test('owner finalises bonuses only for completed months; paid ones are kept', () async {
      await asOwner();
      await expectLater(repo.finalizeBonuses(DateTime(2026, 11)), throwsA(isA<ValidationException>()));
      final paidBefore = (await repo.getBonuses()).where((b) => b.status == BonusStatus.paid).toList();
      await repo.finalizeBonuses(DateTime(2026, 9));
      final paidAfter = (await repo.getBonuses()).where((b) => b.status == BonusStatus.paid).toList();
      expect(paidAfter.length, paidBefore.length);
      final approved = (await repo.getBonuses()).firstWhere((b) => b.status == BonusStatus.approved);
      await repo.markBonusPaid(approved.id);
      expect((await repo.getBonuses()).firstWhere((b) => b.id == approved.id).status, BonusStatus.paid);
    });

    test('commission rules are validated', () async {
      await asOwner();
      await expectLater(repo.saveCommissionRules(const []), throwsA(isA<ValidationException>()));
      await expectLater(
          repo.saveCommissionRules(const [
            CommissionRule(id: '', name: 'A', minAchievementPct: 0, commissionPct: 1),
            CommissionRule(id: '', name: 'B', minAchievementPct: 0, commissionPct: 2),
          ]),
          throwsA(isA<ValidationException>()));
      await repo.saveCommissionRules(const [CommissionRule(id: '', name: 'Flat', minAchievementPct: 0, commissionPct: 1.25)]);
      final rules = await repo.getCommissionRules();
      expect(rules.single.id, isNotEmpty);
    });

    test('customer consent: opt-ins require consent', () async {
      await asManager();
      final saved = await repo.saveCustomer(const Customer(
        id: '',
        name: 'Tara Kulkarni',
        phone: '+91 99887 76655',
        whatsappOptIn: true, // no consent -> must be stored false
      ));
      expect(saved.phone, '9988776655');
      expect(saved.whatsappOptIn, isFalse);
      final consented = await repo.saveCustomer(saved.copyWith(marketingConsent: true, whatsappOptIn: true));
      expect(consented.whatsappOptIn, isTrue);
      expect(consented.marketingConsentAt, isNotNull);
      await expectLater(repo.saveCustomer(const Customer(id: '', name: 'Dup', phone: '9988776655')),
          throwsA(isA<ValidationException>()));
    });
  });
}
