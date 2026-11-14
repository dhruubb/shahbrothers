import 'package:flutter_test/flutter_test.dart';
import 'package:shah_brothers/data/models/models.dart';
import 'package:shah_brothers/domain/bonus_calculator.dart';
import 'package:shah_brothers/domain/permissions.dart';

const rules = [
  CommissionRule(id: 'b', name: 'Base', minAchievementPct: 0, commissionPct: 1),
  CommissionRule(id: 's', name: 'Silver', minAchievementPct: 80, commissionPct: 1.5),
  CommissionRule(id: 'g', name: 'Gold', minAchievementPct: 100, commissionPct: 2, flatBonusPaise: 200000),
  CommissionRule(id: 'p', name: 'Platinum', minAchievementPct: 120, commissionPct: 2.5, flatBonusPaise: 500000),
];

void main() {
  group('BonusCalculator', () {
    const target = 10000000; // ₹1,00,000

    test('below 80% earns base commission and shows next slab', () {
      final r = BonusCalculator.compute(basePaise: 5000000, targetPaise: target, rules: rules);
      expect(r.rule!.name, 'Base');
      expect(r.commissionPaise, 50000); // 1% of ₹50,000
      expect(r.totalPaise, 50000);
      expect(r.achievementPct, 50);
      expect(r.nextRule!.name, 'Silver');
      expect(r.paiseToNextRule, 3000000);
    });

    test('exactly 100% reaches Gold with flat bonus', () {
      final r = BonusCalculator.compute(basePaise: target, targetPaise: target, rules: rules);
      expect(r.rule!.name, 'Gold');
      expect(r.commissionPaise, 200000);
      expect(r.totalPaise, 400000);
      expect(r.nextRule!.name, 'Platinum');
    });

    test('one paisa short of 80% stays on Base', () {
      final r = BonusCalculator.compute(basePaise: 7999999, targetPaise: target, rules: rules);
      expect(r.rule!.name, 'Base');
      expect(r.paiseToNextRule, 1);
    });

    test('top slab has no next rule; inactive rules ignored', () {
      final r = BonusCalculator.compute(basePaise: 15000000, targetPaise: target, rules: rules);
      expect(r.rule!.name, 'Platinum');
      expect(r.nextRule, isNull);
      expect(r.totalPaise, 375000 + 500000);
      final noPlatinum = [...rules.take(3), rules[3].copyWith(isActive: false)];
      expect(BonusCalculator.compute(basePaise: 15000000, targetPaise: target, rules: noPlatinum).rule!.name, 'Gold');
    });

    test('zero target only allows the 0% rule', () {
      final r = BonusCalculator.compute(basePaise: 5000000, targetPaise: 0, rules: rules);
      expect(r.rule!.name, 'Base');
      expect(r.achievementPct, 0);
    });
  });

  group('Permissions', () {
    AppUser user(UserRole role, {bool active = true}) =>
        AppUser(id: role.name, fullName: 'X Y', email: 'x@y.in', role: role, isActive: active);

    test('owner has full access', () {
      final o = user(UserRole.owner);
      for (final p in [
        Permission.viewBusinessAnalytics,
        Permission.createBill,
        Permission.cancelInvoice,
        Permission.manageBonuses,
        Permission.manageSettings,
      ]) {
        expect(o.can(p), isTrue, reason: p.name);
      }
    });

    test('manager bills but cannot see analytics, bonuses or settings', () {
      final m = user(UserRole.manager);
      expect(m.can(Permission.createBill), isTrue);
      expect(m.can(Permission.manageCustomers), isTrue);
      expect(m.can(Permission.printInvoice), isTrue);
      expect(m.can(Permission.viewBusinessAnalytics), isFalse);
      expect(m.can(Permission.manageBonuses), isFalse);
      expect(m.can(Permission.manageSettings), isFalse);
      expect(m.can(Permission.cancelInvoice), isFalse);
    });

    test('salesperson only sees own performance', () {
      final s = user(UserRole.salesperson);
      expect(s.can(Permission.viewOwnSales), isTrue);
      expect(s.can(Permission.viewOwnBonus), isTrue);
      expect(s.can(Permission.createBill), isFalse);
      expect(s.can(Permission.viewCustomers), isFalse);
      expect(s.can(Permission.viewAllSales), isFalse);
    });

    test('inactive users have no permissions', () {
      expect(user(UserRole.owner, active: false).can(Permission.createBill), isFalse);
    });

    test('home routes per role', () {
      expect(user(UserRole.owner).homePath, '/owner/dashboard');
      expect(user(UserRole.manager).homePath, '/manager/home');
      expect(user(UserRole.salesperson).homePath, '/sales/dashboard');
    });
  });
}
