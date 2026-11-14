import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../core/utils/validators.dart';
import '../../domain/exceptions.dart';
import '../demo_seed.dart';
import '../models/models.dart';
import 'data_repository.dart';
import 'local_repository.dart';

/// Supabase backend. Permissions are enforced server-side by Row Level
/// Security and the create_sale / cancel_sale / finalize_bonuses RPCs
/// (see supabase/migrations/0001_init.sql).
class SupabaseRepository implements DataRepository {
  SupabaseRepository(this._client);

  final SupabaseClient _client;
  AppUser? _currentUser;

  static const _saleSelect = '*, '
      'customer:customers!sales_customer_id_fkey(name, phone), '
      'salesperson:users!sales_salesperson_id_fkey(full_name), '
      'manager:users!sales_manager_id_fkey(full_name), '
      'sale_items(*), payments(*)';

  @override
  bool get isDemoMode => false;

  @override
  String get backendLabel => 'Supabase (${Uri.tryParse(_client.rest.url)?.host ?? 'cloud'})';

  @override
  AppUser? get currentUser => _currentUser;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PostgrestException catch (e) {
      if (e.code == '42501') throw PermissionDeniedException(e.message);
      throw AppException(e.message);
    } on AuthException catch (e) {
      throw AuthFailedException(
          e.message.contains('Invalid login credentials') ? 'Incorrect email or password.' : e.message);
    }
  }

  Future<AppUser?> _loadProfile(String id) async {
    final row = await _client.from('users').select().eq('id', id).maybeSingle();
    return row == null ? null : AppUser.fromJson(row);
  }

  // ---- auth --------------------------------------------------------------

  @override
  Future<AppUser?> restoreSession() async {
    final session = _client.auth.currentSession;
    if (session == null) return null;
    try {
      final user = await _loadProfile(session.user.id);
      if (user == null || !user.isActive) {
        await _client.auth.signOut();
        return null;
      }
      return _currentUser = user;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AppUser> signIn(String email, String password) => _guard(() async {
        final res = await _client.auth.signInWithPassword(email: email.trim().toLowerCase(), password: password);
        final id = res.user?.id;
        if (id == null) throw const AuthFailedException();
        final user = await _loadProfile(id);
        if (user == null || !user.isActive) {
          await _client.auth.signOut();
          throw const AuthFailedException('This account is not set up for Shah Brothers. Ask the owner to activate it.');
        }
        return _currentUser = user;
      });

  @override
  Future<void> signOut() async {
    _currentUser = null;
    await _client.auth.signOut();
  }

  @override
  Future<List<DemoCredential>> demoCredentials() async => DemoSeed.credentialsFrom(await DemoSeed.load());

  // ---- staff -------------------------------------------------------------

  @override
  Future<List<AppUser>> getStaff() => _guard(() async {
        final rows = await _client.from('users').select().order('role').order('full_name');
        return rows.map(AppUser.fromJson).toList();
      });

  @override
  Future<AppUser> updateStaff(AppUser user) => _guard(() async {
        if (user.id == _currentUser?.id && (!user.isActive || user.role != UserRole.owner)) {
          throw const ValidationException('You cannot deactivate or demote your own account.');
        }
        final rows = await _client
            .from('users')
            .update({
              'full_name': user.fullName,
              'phone': user.phone,
              'role': user.role.name,
              'monthly_target': Money.toRupees(user.monthlyTargetPaise),
              'is_active': user.isActive,
            })
            .eq('id', user.id)
            .select();
        if (rows.isEmpty) throw const PermissionDeniedException('Only the owner can manage staff.');
        return AppUser.fromJson(rows.first);
      });

  @override
  Future<AppUser> addStaff(NewStaffInput input) async {
    throw const AppException(
        'New staff logins are created in the Supabase dashboard (Authentication → Users) with '
        'app_metadata {"role": "salesperson"}. They appear here automatically. See README.');
  }

  // ---- customers ---------------------------------------------------------

  @override
  Future<List<Customer>> getCustomers() => _guard(() async {
        final rows = await _client.from('customers').select().order('name');
        return rows.map(Customer.fromJson).toList();
      });

  @override
  Future<Map<String, CustomerStats>> getCustomerStats() => _guard(() async {
        final rows = await _client.from('customer_stats').select();
        return {for (final r in rows.map(CustomerStats.fromJson)) r.customerId: r};
      });

  @override
  Future<Customer> saveCustomer(Customer customer) => _guard(() async {
        final phone = Validators.normalizePhone(customer.phone);
        if (customer.name.trim().isEmpty) throw const ValidationException('Customer name is required');
        if (!Validators.isMobile(phone)) throw const ValidationException('Enter a valid 10-digit mobile number');
        final data = customer.copyWith(phone: phone).toWriteJson();
        final Map<String, dynamic> row;
        if (customer.isNew) {
          row = await _client
              .from('customers')
              .insert({...data, 'created_by': _currentUser?.id})
              .select()
              .single();
        } else {
          final rows = await _client.from('customers').update(data).eq('id', customer.id).select();
          if (rows.isEmpty) throw const PermissionDeniedException('Only owners and managers can edit customers.');
          row = rows.first;
        }
        return Customer.fromJson(row);
      });

  // ---- products ----------------------------------------------------------

  @override
  Future<List<Product>> getProducts() => _guard(() async {
        final rows = await _client.from('products').select().order('category').order('name');
        return rows.map(Product.fromJson).toList();
      });

  @override
  Future<Product> saveProduct(Product product) => _guard(() async {
        if (product.name.trim().isEmpty) throw const ValidationException('Product name is required');
        if (product.sku.trim().isEmpty) throw const ValidationException('SKU / code is required');
        final data = product.toWriteJson();
        if (product.isNew) {
          return Product.fromJson(await _client.from('products').insert(data).select().single());
        }
        final rows = await _client.from('products').update(data).eq('id', product.id).select();
        if (rows.isEmpty) throw const PermissionDeniedException('Only owners and managers can edit products.');
        return Product.fromJson(rows.first);
      });

  // ---- sales -------------------------------------------------------------

  @override
  Future<List<Sale>> getSales(SalesQuery query) => _guard(() async {
        const pageSize = 1000;
        final out = <Sale>[];
        var offset = 0;
        while (true) {
          var q = _client.from('sales').select(_saleSelect);
          if (query.from != null) q = q.gte('created_at', query.from!.toUtc().toIso8601String());
          if (query.to != null) q = q.lt('created_at', query.to!.toUtc().toIso8601String());
          if (query.salespersonId != null) q = q.eq('salesperson_id', query.salespersonId!);
          if (query.customerId != null) q = q.eq('customer_id', query.customerId!);
          final rows = await q.order('created_at', ascending: false).range(offset, offset + pageSize - 1);
          out.addAll(rows.map(Sale.fromJson));
          if (rows.length < pageSize) break;
          offset += pageSize;
        }
        return out;
      });

  @override
  Future<Sale?> getSale(String id) => _guard(() async {
        final row = await _client.from('sales').select(_saleSelect).eq('id', id).maybeSingle();
        return row == null ? null : Sale.fromJson(row);
      });

  @override
  Future<Sale> createSale(SaleInput input) => _guard(() async {
        final id = await _client.rpc('create_sale', params: {'payload': input.toPayload()});
        final sale = await getSale(id as String);
        if (sale == null) throw const AppException('Bill saved, but it could not be loaded. Pull to refresh.');
        return sale;
      });

  @override
  Future<void> cancelSale(String id, String reason) => _guard(() async {
        await _client.rpc('cancel_sale', params: {'p_sale_id': id, 'p_reason': reason});
      });

  // ---- settings & rules --------------------------------------------------

  @override
  Future<AppSettings> getSettings() => _guard(() async {
        final row = await _client.from('app_settings').select().eq('id', 1).maybeSingle();
        return row == null ? const AppSettings() : AppSettings.fromJson(row);
      });

  @override
  Future<AppSettings> updateSettings(AppSettings settings) => _guard(() async {
        final rows = await _client
            .from('app_settings')
            .update({...settings.toJson(), 'updated_at': DateTime.now().toUtc().toIso8601String()})
            .eq('id', 1)
            .select();
        if (rows.isEmpty) throw const PermissionDeniedException('Only the owner can change store settings.');
        return AppSettings.fromJson(rows.first);
      });

  @override
  Future<List<CommissionRule>> getCommissionRules() => _guard(() async {
        final rows = await _client.from('commission_rules').select().order('min_achievement_pct');
        return rows.map(CommissionRule.fromJson).toList();
      });

  @override
  Future<void> saveCommissionRules(List<CommissionRule> rules) => _guard(() async {
        LocalRepository.validateRules(rules);
        final existing = await getCommissionRules();
        final keep = rules.where((r) => r.id.isNotEmpty).map((r) => r.id).toSet();
        for (final r in existing.where((r) => !keep.contains(r.id))) {
          await _client.from('commission_rules').delete().eq('id', r.id);
        }
        for (final r in rules) {
          final data = r.toJson()..remove('id');
          if (r.id.isEmpty) {
            await _client.from('commission_rules').insert(data);
          } else {
            await _client.from('commission_rules').update(data).eq('id', r.id);
          }
        }
      });

  // ---- bonuses -----------------------------------------------------------

  @override
  Future<List<Bonus>> getBonuses({String? salespersonId}) => _guard(() async {
        var q = _client.from('bonuses').select();
        if (salespersonId != null) q = q.eq('salesperson_id', salespersonId);
        final rows = await q.order('period_start', ascending: false);
        return rows.map(Bonus.fromJson).toList();
      });

  @override
  Future<void> finalizeBonuses(DateTime month) => _guard(() async {
        await _client.rpc('finalize_bonuses', params: {'p_period': Dates.isoDate(DateTime(month.year, month.month))});
      });

  @override
  Future<void> markBonusPaid(String bonusId) => _guard(() async {
        final rows = await _client
            .from('bonuses')
            .update({'status': 'paid', 'paid_at': DateTime.now().toUtc().toIso8601String()})
            .eq('id', bonusId)
            .select();
        if (rows.isEmpty) throw const PermissionDeniedException('Only the owner can mark bonuses as paid.');
      });

  @override
  Future<void> resetDemoData() async {
    throw const AppException('Re-run supabase/seed.sql in the Supabase SQL editor to reset demo data.');
  }
}
