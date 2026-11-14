import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/models.dart';
import '../data/repositories/data_repository.dart';
import '../domain/analytics.dart';
import '../domain/exceptions.dart';

/// Overridden in main() with LocalRepository or SupabaseRepository.
final repositoryProvider = Provider<DataRepository>(
  (ref) => throw UnimplementedError('repositoryProvider must be overridden'),
);

// ---------------------------------------------------------------- auth

class AuthController extends AsyncNotifier<AppUser?> {
  @override
  Future<AppUser?> build() => ref.read(repositoryProvider).restoreSession();

  /// Throws an [AppException] on failure; the login screen shows it.
  Future<void> signIn(String email, String password) async {
    final user = await ref.read(repositoryProvider).signIn(email, password);
    state = AsyncData(user);
  }

  Future<void> signOut() async {
    await ref.read(repositoryProvider).signOut();
    state = const AsyncData(null);
  }

  /// Refresh the signed-in profile (e.g. after the owner edits it).
  void updateUser(AppUser user) {
    if (state.valueOrNull?.id == user.id) state = AsyncData(user);
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AppUser?>(AuthController.new);

final currentUserProvider = Provider<AppUser?>((ref) => ref.watch(authControllerProvider).valueOrNull);

AppUser requireUser(Ref ref) {
  final u = ref.watch(currentUserProvider);
  if (u == null) throw const PermissionDeniedException('Please sign in again.');
  return u;
}

// ------------------------------------------------------- data providers

/// Bumped after every write so all lists and dashboards refresh.
final dataRevisionProvider = StateProvider<int>((ref) => 0);

extension DataRefresh on WidgetRef {
  void refreshData() => read(dataRevisionProvider.notifier).state++;
}

final settingsProvider = FutureProvider<AppSettings>((ref) {
  ref.watch(dataRevisionProvider);
  requireUser(ref);
  return ref.read(repositoryProvider).getSettings();
});

final staffProvider = FutureProvider<List<AppUser>>((ref) {
  ref.watch(dataRevisionProvider);
  requireUser(ref);
  return ref.read(repositoryProvider).getStaff();
});

final salespeopleProvider = FutureProvider<List<AppUser>>((ref) async {
  final staff = await ref.watch(staffProvider.future);
  return staff.where((u) => u.role == UserRole.salesperson && u.isActive).toList();
});

final customersProvider = FutureProvider<List<Customer>>((ref) {
  ref.watch(dataRevisionProvider);
  requireUser(ref);
  return ref.read(repositoryProvider).getCustomers();
});

final customerStatsProvider = FutureProvider<Map<String, CustomerStats>>((ref) {
  ref.watch(dataRevisionProvider);
  requireUser(ref);
  return ref.read(repositoryProvider).getCustomerStats();
});

final productsProvider = FutureProvider<List<Product>>((ref) {
  ref.watch(dataRevisionProvider);
  requireUser(ref);
  return ref.read(repositoryProvider).getProducts();
});

final commissionRulesProvider = FutureProvider<List<CommissionRule>>((ref) {
  ref.watch(dataRevisionProvider);
  requireUser(ref);
  return ref.read(repositoryProvider).getCommissionRules();
});

final bonusesProvider = FutureProvider.family<List<Bonus>, String?>((ref, salespersonId) {
  ref.watch(dataRevisionProvider);
  requireUser(ref);
  return ref.read(repositoryProvider).getBonuses(salespersonId: salespersonId);
});

final salesProvider = FutureProvider.autoDispose.family<List<Sale>, SalesQuery>((ref, query) {
  ref.watch(dataRevisionProvider);
  requireUser(ref);
  return ref.read(repositoryProvider).getSales(query);
});

final saleProvider = FutureProvider.autoDispose.family<Sale?, String>((ref, id) {
  ref.watch(dataRevisionProvider);
  requireUser(ref);
  return ref.read(repositoryProvider).getSale(id);
});

// ---------------------------------------------------- dashboard filters

class DashboardFilter {
  const DashboardFilter({required this.range, this.salespersonId, this.granularity = ChartGranularity.daily});

  final DateRangeFilter range;
  final String? salespersonId;
  final ChartGranularity granularity;

  DashboardFilter copyWith({DateRangeFilter? range, String? salespersonId, bool clearSalesperson = false, ChartGranularity? granularity}) =>
      DashboardFilter(
        range: range ?? this.range,
        salespersonId: clearSalesperson ? null : (salespersonId ?? this.salespersonId),
        granularity: granularity ?? this.granularity,
      );
}

final dashboardFilterProvider = StateProvider<DashboardFilter>(
  (ref) => DashboardFilter(range: DateRangeFilter.forPreset(RangePreset.last30)),
);

/// Sales for the dashboard range + salesperson filter.
final dashboardSalesProvider = FutureProvider.autoDispose<List<Sale>>((ref) {
  final f = ref.watch(dashboardFilterProvider);
  return ref.watch(salesProvider(SalesQuery(from: f.range.start, to: f.range.end, salespersonId: f.salespersonId)).future);
});

/// Sales covering the trend chart window (independent of the range filter).
final trendSalesProvider = FutureProvider.autoDispose<List<Sale>>((ref) {
  final f = ref.watch(dashboardFilterProvider);
  final from = Analytics.seriesStart(f.granularity);
  return ref.watch(salesProvider(SalesQuery(from: from, salespersonId: f.salespersonId)).future);
});
