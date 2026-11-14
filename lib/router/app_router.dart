import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models/models.dart';
import '../domain/permissions.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/billing/billing_history_screen.dart';
import '../features/billing/invoice_screen.dart';
import '../features/billing/new_bill_screen.dart';
import '../features/billing/bill_review_screen.dart';
import '../features/customers/customer_detail_screen.dart';
import '../features/customers/customer_form_screen.dart';
import '../features/customers/customers_screen.dart';
import '../features/manager/manager_home_screen.dart';
import '../features/owner/bonuses_screen.dart';
import '../features/owner/owner_dashboard_screen.dart';
import '../features/owner/salesperson_detail_screen.dart';
import '../features/owner/team_screen.dart';
import '../features/products/product_form_screen.dart';
import '../features/products/products_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/salesperson/salesperson_dashboard_screen.dart';
import '../features/salesperson/salesperson_profile_screen.dart';
import '../features/settings/add_staff_screen.dart';
import '../features/settings/commission_rules_screen.dart';
import '../features/settings/more_screen.dart';
import '../features/settings/printer_settings_screen.dart';
import '../features/settings/store_settings_screen.dart';
import '../providers/providers.dart';
import 'role_shell.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Which permission each top-level path needs. Shell prefixes are checked
/// by role in [_guard].
const _routePermissions = <String, Permission>{
  '/bill': Permission.createBill,
  '/customers': Permission.viewCustomers,
  '/products': Permission.viewProducts,
  '/team': Permission.viewBusinessAnalytics,
  '/bonuses': Permission.manageBonuses,
  '/reports': Permission.viewBusinessAnalytics,
  '/settings/store': Permission.manageSettings,
  '/settings/commission': Permission.manageSettings,
  '/settings/staff': Permission.manageStaff,
  '/settings/printer': Permission.printInvoice,
};

/// Bridges Riverpod auth state to GoRouter's refreshListenable.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen<AsyncValue<AppUser?>>(authControllerProvider, (_, __) => notifyListeners());
  }
}

String? guardRoute(AsyncValue<AppUser?> auth, String location) {
  if (auth.isLoading && !auth.hasValue) return location == '/splash' ? null : '/splash';
  final user = auth.valueOrNull;
  final atAuth = location == '/login' || location == '/splash';
  if (user == null) return location == '/login' ? null : '/login';
  if (atAuth) return user.homePath;

  // Role shells
  if (location.startsWith('/owner')) return user.role == UserRole.owner ? null : user.homePath;
  if (location.startsWith('/manager')) return user.role == UserRole.manager ? null : user.homePath;
  if (location.startsWith('/sales')) return user.role == UserRole.salesperson ? null : user.homePath;

  // Shared pages
  for (final e in _routePermissions.entries) {
    if (location == e.key || location.startsWith('${e.key}/')) {
      return user.can(e.value) ? null : user.homePath;
    }
  }
  if (location.startsWith('/invoice/')) {
    return (user.can(Permission.viewAllSales) || user.can(Permission.viewOwnSales)) ? null : user.homePath;
  }
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthListenable(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) => guardRoute(ref.read(authControllerProvider), state.matchedLocation),
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),

      // ---------------- Owner
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => RoleShell(shell: shell, destinations: RoleShell.owner),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/owner/dashboard', builder: (_, __) => const OwnerDashboardScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/owner/sales', builder: (_, __) => const BillingHistoryScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/owner/team', builder: (_, __) => const TeamScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/owner/customers', builder: (_, __) => const CustomersScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/owner/more', builder: (_, __) => const MoreScreen())]),
        ],
      ),

      // ---------------- Manager
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => RoleShell(shell: shell, destinations: RoleShell.manager),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/manager/home', builder: (_, __) => const ManagerHomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/manager/bills', builder: (_, __) => const BillingHistoryScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/manager/customers', builder: (_, __) => const CustomersScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/manager/products', builder: (_, __) => const ProductsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/manager/more', builder: (_, __) => const MoreScreen())]),
        ],
      ),

      // ---------------- Salesperson
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => RoleShell(shell: shell, destinations: RoleShell.salesperson),
        branches: [
          StatefulShellBranch(
              routes: [GoRoute(path: '/sales/dashboard', builder: (_, __) => const SalespersonDashboardScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/sales/history', builder: (_, __) => const BillingHistoryScreen())]),
          StatefulShellBranch(
              routes: [GoRoute(path: '/sales/profile', builder: (_, __) => const SalespersonProfileScreen())]),
        ],
      ),

      // ---------------- Shared full-screen pages
      GoRoute(parentNavigatorKey: _rootKey, path: '/bill/new', builder: (_, __) => const NewBillScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/bill/review', builder: (_, __) => const BillReviewScreen()),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/invoice/:id',
        builder: (_, s) => InvoiceScreen(saleId: s.pathParameters['id']!, justCreated: s.uri.queryParameters['new'] == '1'),
      ),
      GoRoute(parentNavigatorKey: _rootKey, path: '/customers/new', builder: (_, __) => const CustomerFormScreen()),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/customers/:id',
        builder: (_, s) => CustomerDetailScreen(customerId: s.pathParameters['id']!),
        routes: [
          GoRoute(
            parentNavigatorKey: _rootKey,
            path: 'edit',
            builder: (_, s) => CustomerFormScreen(customerId: s.pathParameters['id']),
          ),
        ],
      ),
      GoRoute(parentNavigatorKey: _rootKey, path: '/products', builder: (_, __) => const ProductsScreen(standalone: true)),
      GoRoute(parentNavigatorKey: _rootKey, path: '/products/new', builder: (_, __) => const ProductFormScreen()),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/products/:id/edit',
        builder: (_, s) => ProductFormScreen(productId: s.pathParameters['id']),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/team/:id',
        builder: (_, s) => SalespersonDetailScreen(userId: s.pathParameters['id']!),
      ),
      GoRoute(parentNavigatorKey: _rootKey, path: '/bonuses', builder: (_, __) => const BonusesScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/reports', builder: (_, __) => const ReportsScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/settings/store', builder: (_, __) => const StoreSettingsScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/settings/commission', builder: (_, __) => const CommissionRulesScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/settings/printer', builder: (_, __) => const PrinterSettingsScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/settings/staff/new', builder: (_, __) => const AddStaffScreen()),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(),
      body: Center(child: Text('Page not found: ${state.uri.path}')),
    ),
  );
});
