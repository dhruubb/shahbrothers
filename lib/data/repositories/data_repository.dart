import '../models/models.dart';

/// Query for sales lists. Equality makes it usable as a Riverpod family key.
class SalesQuery {
  const SalesQuery({this.from, this.to, this.salespersonId, this.customerId});

  final DateTime? from;

  /// Exclusive upper bound.
  final DateTime? to;
  final String? salespersonId;
  final String? customerId;

  @override
  bool operator ==(Object other) =>
      other is SalesQuery &&
      other.from == from &&
      other.to == to &&
      other.salespersonId == salespersonId &&
      other.customerId == customerId;

  @override
  int get hashCode => Object.hash(from, to, salespersonId, customerId);
}

/// New staff member (local demo mode only — on Supabase, staff accounts are
/// created in the Supabase dashboard; see README).
class NewStaffInput {
  const NewStaffInput({
    required this.fullName,
    required this.email,
    required this.password,
    required this.role,
    this.phone,
    this.monthlyTargetPaise = 0,
  });

  final String fullName;
  final String email;
  final String password;
  final UserRole role;
  final String? phone;
  final int monthlyTargetPaise;
}

/// Everything the UI needs from a backend. Implemented by
/// [LocalRepository] (offline demo mode) and [SupabaseRepository].
///
/// Implementations enforce role permissions themselves (Supabase via Row
/// Level Security; the local repository mirrors those rules) so the UI can
/// never bypass them.
abstract class DataRepository {
  bool get isDemoMode;
  String get backendLabel;

  AppUser? get currentUser;
  Future<AppUser?> restoreSession();
  Future<AppUser> signIn(String email, String password);
  Future<void> signOut();

  /// Demo login details shown on the login screen.
  Future<List<DemoCredential>> demoCredentials();

  Future<List<AppUser>> getStaff();
  Future<AppUser> updateStaff(AppUser user);
  Future<AppUser> addStaff(NewStaffInput input);

  Future<List<Customer>> getCustomers();
  Future<Map<String, CustomerStats>> getCustomerStats();
  Future<Customer> saveCustomer(Customer customer);

  Future<List<Product>> getProducts();
  Future<Product> saveProduct(Product product);

  Future<List<Sale>> getSales(SalesQuery query);
  Future<Sale?> getSale(String id);
  Future<Sale> createSale(SaleInput input);
  Future<void> cancelSale(String id, String reason);

  Future<AppSettings> getSettings();
  Future<AppSettings> updateSettings(AppSettings settings);

  Future<List<CommissionRule>> getCommissionRules();
  Future<void> saveCommissionRules(List<CommissionRule> rules);

  Future<List<Bonus>> getBonuses({String? salespersonId});
  Future<void> finalizeBonuses(DateTime month);
  Future<void> markBonusPaid(String bonusId);

  /// Local demo mode: wipe and reload demo data.
  Future<void> resetDemoData();
}

class DemoCredential {
  const DemoCredential({required this.role, required this.name, required this.email, required this.password});
  final UserRole role;
  final String name;
  final String email;
  final String password;
}
