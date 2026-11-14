import '../data/models/models.dart';

enum Permission {
  viewBusinessAnalytics,
  viewAllSales,
  viewOwnSales,
  createBill,
  cancelInvoice,
  printInvoice,
  viewCustomers,
  manageCustomers,
  viewProducts,
  manageProducts,
  manageSettings,
  manageStaff,
  manageBonuses,
  viewOwnBonus,
}

/// Role → permissions. The database enforces the same rules with Row Level
/// Security; this map drives navigation and which buttons are shown.
const Map<UserRole, Set<Permission>> rolePermissions = {
  UserRole.owner: {
    Permission.viewBusinessAnalytics,
    Permission.viewAllSales,
    Permission.createBill,
    Permission.cancelInvoice,
    Permission.printInvoice,
    Permission.viewCustomers,
    Permission.manageCustomers,
    Permission.viewProducts,
    Permission.manageProducts,
    Permission.manageSettings,
    Permission.manageStaff,
    Permission.manageBonuses,
  },
  UserRole.manager: {
    Permission.viewAllSales,
    Permission.createBill,
    Permission.printInvoice,
    Permission.viewCustomers,
    Permission.manageCustomers,
    Permission.viewProducts,
    Permission.manageProducts,
  },
  UserRole.salesperson: {
    Permission.viewOwnSales,
    Permission.viewOwnBonus,
  },
};

extension UserPermissions on AppUser {
  bool can(Permission p) => isActive && (rolePermissions[role]?.contains(p) ?? false);

  /// Home route for each role.
  String get homePath => switch (role) {
        UserRole.owner => '/owner/dashboard',
        UserRole.manager => '/manager/home',
        UserRole.salesperson => '/sales/dashboard',
      };
}
