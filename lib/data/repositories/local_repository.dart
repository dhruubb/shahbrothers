import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/dates.dart';
import '../../core/utils/validators.dart';
import '../../domain/analytics.dart';
import '../../domain/billing_calculator.dart';
import '../../domain/bonus_calculator.dart';
import '../../domain/exceptions.dart';
import '../demo_seed.dart';
import '../models/models.dart';
import 'data_repository.dart';
import 'local_persistence.dart';

/// Offline demo backend: a JSON database on the device, seeded from
/// assets/demo/seed.json on first launch.
///
/// It mirrors the Supabase rules: the same billing maths, invoice numbering,
/// and the same role permissions as the Row Level Security policies.
class LocalRepository implements DataRepository {
  LocalRepository({
    required LocalPersistence persistence,
    Future<Map<String, dynamic>> Function()? seedLoader,
    DateTime Function()? clock,
  })  : _persistence = persistence,
        _seedLoader = seedLoader ?? DemoSeed.load,
        _clock = clock ?? DateTime.now;

  final LocalPersistence _persistence;
  final Future<Map<String, dynamic>> Function() _seedLoader;
  final DateTime Function() _clock;
  static const _uuid = Uuid();

  // ---- state -------------------------------------------------------------
  List<AppUser> _users = [];
  Map<String, String> _passwordHashes = {};
  AppSettings _settings = const AppSettings();
  List<CommissionRule> _rules = [];
  List<Product> _products = [];
  List<Customer> _customers = [];
  List<Sale> _sales = []; // stored without joined names
  List<Bonus> _bonuses = [];
  Map<String, int> _invoiceCounters = {};
  String? _sessionUserId;
  AppUser? _currentUser;
  Future<void> _saveChain = Future.value();
  bool _ready = false;

  @override
  bool get isDemoMode => true;

  @override
  String get backendLabel => 'Local demo database';

  @override
  AppUser? get currentUser => _currentUser;

  // ---- lifecycle ---------------------------------------------------------

  Future<void> init() async {
    if (_ready) return;
    final raw = await _persistence.read();
    if (raw == null || raw.isEmpty) {
      await _seed();
    } else {
      try {
        _load(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        await _seed(); // corrupted file: start fresh
      }
    }
    _ready = true;
  }

  static String hashPassword(String email, String password) =>
      sha256.convert(utf8.encode('shahbrothers:${email.trim().toLowerCase()}:$password')).toString();

  void _load(Map<String, dynamic> db) {
    List<Map<String, dynamic>> list(String key) =>
        ((db[key] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    _users = list('users').map(AppUser.fromJson).toList();
    _passwordHashes = Map<String, String>.from(db['password_hashes'] as Map? ?? {});
    _settings = AppSettings.fromJson(Map<String, dynamic>.from(db['settings'] as Map? ?? {}));
    _rules = list('commission_rules').map(CommissionRule.fromJson).toList();
    _products = list('products').map(Product.fromJson).toList();
    _customers = list('customers').map(Customer.fromJson).toList();
    _sales = list('sales').map(Sale.fromJson).toList();
    _bonuses = list('bonuses').map(Bonus.fromJson).toList();
    _invoiceCounters = Map<String, int>.from(
        (db['invoice_counters'] as Map? ?? {}).map((k, v) => MapEntry(k as String, (v as num).toInt())));
    _sessionUserId = db['session_user_id'] as String?;
  }

  Map<String, dynamic> _dump() => {
        'version': 1,
        'session_user_id': _sessionUserId,
        'users': _users.map((e) => e.toJson()).toList(),
        'password_hashes': _passwordHashes,
        'settings': _settings.toJson(),
        'commission_rules': _rules.map((e) => e.toJson()).toList(),
        'products': _products.map((e) => e.toJson()).toList(),
        'customers': _customers.map((e) => e.toJson()).toList(),
        'sales': _sales.map((e) => e.toJson()).toList(),
        'bonuses': _bonuses.map((e) => e.toJson()).toList(),
        'invoice_counters': _invoiceCounters,
      };

  /// Serialised writes so concurrent saves never interleave.
  Future<void> _save() {
    final snapshot = jsonEncode(_dump());
    // A failed earlier write must not block later ones.
    _saveChain = _saveChain.catchError((Object _) {}).then((_) => _persistence.write(snapshot));
    return _saveChain;
  }

  Future<void> _seed() async {
    final seed = await _seedLoader();
    final now = _clock();
    final today = Dates.startOfDay(now);

    _users = [];
    _passwordHashes = {};
    for (final u in (seed['users'] as List).cast<Map<String, dynamic>>()) {
      final user = AppUser.fromJson(u).copyWith();
      final joined = today.subtract(Duration(days: (u['joined_days_ago'] as num?)?.toInt() ?? 0));
      _users.add(AppUser(
        id: user.id,
        fullName: user.fullName,
        email: user.email,
        phone: user.phone,
        role: user.role,
        monthlyTargetPaise: user.monthlyTargetPaise,
        isActive: true,
        joinedOn: joined,
      ));
      _passwordHashes[user.id] = u['password_hash'] as String;
    }
    _settings = AppSettings.fromJson(seed['settings'] as Map<String, dynamic>);
    _rules = (seed['commission_rules'] as List).cast<Map<String, dynamic>>().map(CommissionRule.fromJson).toList();
    _products = (seed['products'] as List).cast<Map<String, dynamic>>().map((p) {
      final product = Product.fromJson(p);
      return product.copyWith(stockQty: (p['opening_stock'] as num?)?.toInt() ?? product.stockQty);
    }).toList();
    _customers = (seed['customers'] as List).cast<Map<String, dynamic>>().map((c) {
      final created = now.subtract(Duration(days: (c['created_days_ago'] as num?)?.toInt() ?? 0));
      final consentDays = (c['consent_days_ago'] as num?)?.toInt();
      return Customer.fromJson(c).copyWith(
        createdAt: created,
        marketingConsentAt: consentDays == null ? null : now.subtract(Duration(days: consentDays)),
      );
    }).toList();
    _sales = [];
    _bonuses = [];
    _invoiceCounters = {};

    for (final s in (seed['sales'] as List).cast<Map<String, dynamic>>()) {
      final daysAgo = (s['days_ago'] as num).toInt();
      final minute = (s['minute_of_day'] as num).toInt();
      final createdAt = DateTime(today.year, today.month, today.day - daysAgo).add(Duration(minutes: minute));
      final input = SaleInput(
        customerId: s['customer_id'] as String,
        customerName: '',
        customerPhone: '',
        salespersonId: s['salesperson_id'] as String,
        notes: s['notes'] as String?,
        items: (s['items'] as List).cast<Map<String, dynamic>>().map(SaleItemInput.fromJson).toList(),
        payments: (s['payments'] as List)
            .cast<Map<String, dynamic>>()
            .map((p) => Payment(
                  method: PaymentMethod.parse(p['method'] as String?),
                  amountPaise: ((p['amount'] as num) * 100).round(),
                  reference: p['reference'] as String?,
                ))
            .toList(),
      );
      _insertSale(input, s['manager_id'] as String, createdAt);
    }

    final owner = _users.firstWhere((u) => u.role == UserRole.owner);
    final paidBack = ((seed['bonus_paid_months_back'] as List?) ?? const []).map((e) => (e as num).toInt()).toSet();
    for (final m in ((seed['bonus_months_back'] as List?) ?? const []).map((e) => (e as num).toInt())) {
      final month = DateTime(now.year, now.month - m);
      _finalize(month, owner.id);
      if (paidBack.contains(m)) {
        final paidAt = DateTime(now.year, now.month - m + 1, 5);
        _bonuses = _bonuses
            .map((b) => b.periodStart == month ? _withStatus(b, BonusStatus.paid, paidAt) : b)
            .toList();
      }
    }
    await _save();
  }

  // ---- auth --------------------------------------------------------------

  @override
  Future<AppUser?> restoreSession() async {
    await init();
    if (_sessionUserId == null) return null;
    final u = _userById(_sessionUserId!);
    if (u == null || !u.isActive) {
      _sessionUserId = null;
      return null;
    }
    return _currentUser = u;
  }

  @override
  Future<AppUser> signIn(String email, String password) async {
    await init();
    final e = email.trim().toLowerCase();
    final user = _users.where((u) => u.email.toLowerCase() == e).firstOrNull;
    if (user == null || _passwordHashes[user.id] != hashPassword(e, password)) {
      throw const AuthFailedException();
    }
    if (!user.isActive) throw const AuthFailedException('This account has been deactivated.');
    _currentUser = user;
    _sessionUserId = user.id;
    await _save();
    return user;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _sessionUserId = null;
    await _save();
  }

  @override
  Future<List<DemoCredential>> demoCredentials() async => DemoSeed.credentialsFrom(await _seedLoader());

  // ---- permission helpers (mirror RLS) ------------------------------------

  AppUser _requireUser() {
    final u = _currentUser;
    if (u == null) throw const PermissionDeniedException('Please sign in again.');
    return u;
  }

  AppUser _requireRole(Set<UserRole> roles, [String? message]) {
    final u = _requireUser();
    if (!roles.contains(u.role)) throw PermissionDeniedException(message ?? 'You do not have permission to do this.');
    return u;
  }

  static const _billing = {UserRole.owner, UserRole.manager};
  static const _owner = {UserRole.owner};

  AppUser? _userById(String id) => _users.where((u) => u.id == id).firstOrNull;
  Customer? _customerById(String id) => _customers.where((c) => c.id == id).firstOrNull;

  /// Sales the current user may see (RLS: owner/manager all, salesperson own).
  Iterable<Sale> _visibleSales() {
    final u = _requireUser();
    if (u.role == UserRole.salesperson) return _sales.where((s) => s.salespersonId == u.id);
    return _sales;
  }

  Sale _join(Sale s) {
    final c = _customerById(s.customerId);
    final sp = _userById(s.salespersonId);
    final m = _userById(s.managerId);
    final json = s.toJson()
      ..['customer'] = {'name': c?.name ?? '', 'phone': c?.phone ?? ''}
      ..['salesperson'] = {'full_name': sp?.fullName ?? ''}
      ..['manager'] = {'full_name': m?.fullName ?? ''};
    return Sale.fromJson(json);
  }

  // ---- staff -------------------------------------------------------------

  @override
  Future<List<AppUser>> getStaff() async {
    _requireUser();
    return [..._users]..sort((a, b) {
        final r = a.role.index.compareTo(b.role.index);
        return r != 0 ? r : a.fullName.compareTo(b.fullName);
      });
  }

  @override
  Future<AppUser> updateStaff(AppUser user) async {
    final me = _requireRole(_owner, 'Only the owner can manage staff.');
    if (user.id == me.id && (!user.isActive || user.role != UserRole.owner)) {
      throw const ValidationException('You cannot deactivate or demote your own account.');
    }
    if (user.monthlyTargetPaise < 0) throw const ValidationException('Target cannot be negative');
    final i = _users.indexWhere((u) => u.id == user.id);
    if (i < 0) throw const ValidationException('Staff member not found');
    _users[i] = user;
    await _save();
    return user;
  }

  @override
  Future<AppUser> addStaff(NewStaffInput input) async {
    _requireRole(_owner, 'Only the owner can add staff.');
    final email = input.email.trim().toLowerCase();
    if (input.fullName.trim().isEmpty) throw const ValidationException('Name is required');
    if (Validators.email(email, optional: false) != null) throw const ValidationException('Enter a valid email');
    if (_users.any((u) => u.email.toLowerCase() == email)) {
      throw const ValidationException('A staff member with this email already exists');
    }
    if (input.password.length < 6) throw const ValidationException('Password must be at least 6 characters');
    final user = AppUser(
      id: _uuid.v4(),
      fullName: input.fullName.trim(),
      email: email,
      phone: input.phone,
      role: input.role,
      monthlyTargetPaise: input.monthlyTargetPaise,
      joinedOn: Dates.startOfDay(_clock()),
    );
    _users.add(user);
    _passwordHashes[user.id] = hashPassword(email, input.password);
    await _save();
    return user;
  }

  // ---- customers ---------------------------------------------------------

  @override
  Future<List<Customer>> getCustomers() async {
    final u = _requireUser();
    Iterable<Customer> list = _customers;
    if (u.role == UserRole.salesperson) {
      final mine = _sales.where((s) => s.salespersonId == u.id).map((s) => s.customerId).toSet();
      list = list.where((c) => mine.contains(c.id));
    }
    return list.toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  @override
  Future<Map<String, CustomerStats>> getCustomerStats() async => Analytics.customerStats(_visibleSales());

  @override
  Future<Customer> saveCustomer(Customer customer) async {
    _requireRole(_billing, 'Only owners and managers can edit customers.');
    final phone = Validators.normalizePhone(customer.phone);
    if (customer.name.trim().isEmpty) throw const ValidationException('Customer name is required');
    if (!Validators.isMobile(phone)) throw const ValidationException('Enter a valid 10-digit mobile number');
    if (_customers.any((c) => c.phone == phone && c.id != customer.id)) {
      throw const ValidationException('Another customer already uses this mobile number');
    }
    final existing = customer.isNew ? null : _customerById(customer.id);
    if (!customer.isNew && existing == null) throw const ValidationException('Customer not found');
    final now = _clock();
    // Normalise through the same write-JSON the database receives.
    final data = customer.copyWith(phone: phone).toWriteJson();
    if (customer.marketingConsent) {
      data['marketing_consent_at'] = encodeDate(
          existing?.marketingConsent == true ? (existing!.marketingConsentAt ?? now) : (customer.marketingConsentAt ?? now));
    }
    final saved = Customer.fromJson({
      ...data,
      'id': existing?.id ?? _uuid.v4(),
      'created_at': encodeDate(existing?.createdAt ?? now),
    });
    if (existing == null) {
      _customers.add(saved);
    } else {
      _customers[_customers.indexWhere((c) => c.id == saved.id)] = saved;
    }
    await _save();
    return saved;
  }

  // ---- products ----------------------------------------------------------

  @override
  Future<List<Product>> getProducts() async {
    _requireUser();
    return [..._products]..sort((a, b) {
        final c = a.category.compareTo(b.category);
        return c != 0 ? c : a.name.compareTo(b.name);
      });
  }

  @override
  Future<Product> saveProduct(Product product) async {
    _requireRole(_billing, 'Only owners and managers can edit products.');
    final sku = product.sku.trim().toUpperCase();
    if (product.name.trim().isEmpty) throw const ValidationException('Product name is required');
    if (sku.isEmpty) throw const ValidationException('SKU / code is required');
    if (product.sellingPricePaise < 0) throw const ValidationException('Price cannot be negative');
    if (_products.any((p) => p.sku.toUpperCase() == sku && p.id != product.id)) {
      throw const ValidationException('Another product already uses this SKU');
    }
    final saved = Product.fromJson({
      ...product.toWriteJson(),
      'id': product.isNew ? _uuid.v4() : product.id,
    });
    final i = _products.indexWhere((p) => p.id == saved.id);
    if (i < 0) {
      if (!product.isNew) throw const ValidationException('Product not found');
      _products.add(saved);
    } else {
      _products[i] = saved;
    }
    await _save();
    return saved;
  }

  // ---- sales -------------------------------------------------------------

  @override
  Future<List<Sale>> getSales(SalesQuery query) async {
    final list = _visibleSales().where((s) {
      if (query.from != null && s.createdAt.isBefore(query.from!)) return false;
      if (query.to != null && !s.createdAt.isBefore(query.to!)) return false;
      if (query.salespersonId != null && s.salespersonId != query.salespersonId) return false;
      if (query.customerId != null && s.customerId != query.customerId) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list.map(_join).toList();
  }

  @override
  Future<Sale?> getSale(String id) async {
    final s = _visibleSales().where((s) => s.id == id).firstOrNull;
    return s == null ? null : _join(s);
  }

  @override
  Future<Sale> createSale(SaleInput input) async {
    final me = _requireRole(_billing, 'Only owners and managers can create bills.');
    final sale = _insertSale(input, me.id, _clock());
    await _save();
    return _join(sale);
  }

  String _nextInvoice(DateTime at) {
    final fy = Dates.financialYearCode(at);
    final n = (_invoiceCounters[fy] ?? 0) + 1;
    _invoiceCounters[fy] = n;
    return '${_settings.invoicePrefix}/$fy/${n.toString().padLeft(5, '0')}';
  }

  /// Validates and stores a sale. Mirrors create_sale_internal() in SQL.
  Sale _insertSale(SaleInput input, String managerId, DateTime createdAt) {
    final sp = _userById(input.salespersonId);
    if (sp == null || sp.role != UserRole.salesperson || !sp.isActive) {
      throw const ValidationException('Select a valid salesperson for this bill');
    }

    // Validate everything before changing any state.
    if (input.items.isEmpty) throw const ValidationException('Add at least one saree to the bill');
    final totals = BillingCalculator.compute(input.items, _settings.gstRate);
    final mode = BillingCalculator.validatePayments(input.payments, totals.totalPaise);

    String customerId;
    if (input.customerId != null && input.customerId!.isNotEmpty) {
      if (_customerById(input.customerId!) == null) throw const ValidationException('Customer not found');
      customerId = input.customerId!;
    } else {
      final phone = Validators.normalizePhone(input.customerPhone);
      if (!Validators.isMobile(phone)) throw const ValidationException('Enter a valid 10-digit mobile number');
      if (input.customerName.trim().isEmpty) throw const ValidationException('Customer name is required');
      final existing = _customers.where((c) => c.phone == phone).firstOrNull;
      if (existing != null) {
        customerId = existing.id;
      } else {
        final c = Customer(id: _uuid.v4(), name: input.customerName.trim(), phone: phone, createdAt: createdAt);
        _customers.add(c);
        customerId = c.id;
      }
    }

    final items = <SaleItem>[];
    for (var i = 0; i < input.items.length; i++) {
      final it = input.items[i];
      final line = totals.lines[i];
      items.add(SaleItem(
        id: _uuid.v4(),
        productId: it.productId,
        productName: it.productName.trim().isEmpty ? 'Saree' : it.productName.trim(),
        productCode: it.productCode.trim().isEmpty ? '-' : it.productCode.trim(),
        quantity: it.quantity,
        unitPricePaise: it.unitPricePaise,
        discountType: it.discountType,
        discountValue: it.discountValue,
        discountPaise: line.discountPaise,
        lineTotalPaise: line.netPaise,
      ));
    }

    final sale = Sale(
      id: _uuid.v4(),
      invoiceNumber: _nextInvoice(createdAt),
      customerId: customerId,
      salespersonId: sp.id,
      managerId: managerId,
      subtotalPaise: totals.subtotalPaise,
      discountPaise: totals.discountPaise,
      taxablePaise: totals.taxablePaise,
      gstRate: totals.gstRate,
      cgstPaise: totals.cgstPaise,
      sgstPaise: totals.sgstPaise,
      gstPaise: totals.gstPaise,
      roundOffPaise: totals.roundOffPaise,
      totalPaise: totals.totalPaise,
      paymentMode: mode,
      status: SaleStatus.completed,
      notes: (input.notes?.trim().isEmpty ?? true) ? null : input.notes!.trim(),
      createdAt: createdAt,
      items: items,
      payments: input.payments
          .map((p) => Payment(
                id: _uuid.v4(),
                method: p.method,
                amountPaise: p.amountPaise,
                reference: (p.reference?.trim().isEmpty ?? true) ? null : p.reference!.trim(),
              ))
          .toList(),
    );
    _sales.add(sale);

    for (final it in input.items) {
      if (it.productId == null) continue;
      final i = _products.indexWhere((p) => p.id == it.productId);
      if (i >= 0) _products[i] = _products[i].copyWith(stockQty: _products[i].stockQty - it.quantity);
    }
    return sale;
  }

  @override
  Future<void> cancelSale(String id, String reason) async {
    _requireRole(_owner, 'Only the owner can cancel invoices.');
    if (reason.trim().isEmpty) throw const ValidationException('A reason is required to cancel an invoice');
    final i = _sales.indexWhere((s) => s.id == id);
    if (i < 0 || _sales[i].isCancelled) throw const ValidationException('Invoice not found or already cancelled');
    final s = _sales[i];
    for (final it in s.items) {
      final p = _products.indexWhere((p) => p.id == it.productId);
      if (p >= 0) _products[p] = _products[p].copyWith(stockQty: _products[p].stockQty + it.quantity);
    }
    _sales[i] = Sale.fromJson(s.toJson()
      ..['status'] = SaleStatus.cancelled.name
      ..['cancel_reason'] = reason.trim()
      ..['cancelled_at'] = encodeDate(_clock()));
    await _save();
  }

  // ---- settings & rules --------------------------------------------------

  @override
  Future<AppSettings> getSettings() async {
    _requireUser();
    return _settings;
  }

  @override
  Future<AppSettings> updateSettings(AppSettings settings) async {
    _requireRole(_owner, 'Only the owner can change store settings.');
    if (settings.gstRate < 0 || settings.gstRate > 28) {
      throw const ValidationException('GST rate must be between 0% and 28%');
    }
    if (!RegExp(r'^[A-Z0-9]{1,6}$').hasMatch(settings.invoicePrefix)) {
      throw const ValidationException('Invoice prefix must be 1–6 capital letters or digits');
    }
    if (settings.storeName.trim().isEmpty) throw const ValidationException('Store name is required');
    _settings = settings;
    await _save();
    return settings;
  }

  @override
  Future<List<CommissionRule>> getCommissionRules() async {
    _requireUser();
    return [..._rules]..sort((a, b) => a.minAchievementPct.compareTo(b.minAchievementPct));
  }

  @override
  Future<void> saveCommissionRules(List<CommissionRule> rules) async {
    _requireRole(_owner, 'Only the owner can change bonus rules.');
    validateRules(rules);
    _rules = rules.map((r) => r.id.isEmpty ? r.copyWith(id: _uuid.v4()) : r).toList();
    await _save();
  }

  static void validateRules(List<CommissionRule> rules) {
    if (rules.where((r) => r.isActive).isEmpty) throw const ValidationException('Keep at least one active rule');
    final seen = <double>{};
    for (final r in rules) {
      if (r.name.trim().isEmpty) throw const ValidationException('Every rule needs a name');
      if (r.minAchievementPct < 0) throw const ValidationException('Target % cannot be negative');
      if (r.commissionPct < 0 || r.commissionPct > 100) {
        throw const ValidationException('Commission must be between 0% and 100%');
      }
      if (r.flatBonusPaise < 0) throw const ValidationException('Flat bonus cannot be negative');
      if (r.isActive && !seen.add(r.minAchievementPct)) {
        throw const ValidationException('Two active rules cannot start at the same target %');
      }
    }
  }

  // ---- bonuses -----------------------------------------------------------

  @override
  Future<List<Bonus>> getBonuses({String? salespersonId}) async {
    final u = _requireUser();
    Iterable<Bonus> list;
    if (u.role == UserRole.owner) {
      list = salespersonId == null ? _bonuses : _bonuses.where((b) => b.salespersonId == salespersonId);
    } else if (u.role == UserRole.salesperson) {
      list = _bonuses.where((b) => b.salespersonId == u.id);
    } else {
      list = const []; // managers cannot see bonuses (same as RLS)
    }
    return list.toList()..sort((a, b) => b.periodStart.compareTo(a.periodStart));
  }

  @override
  Future<void> finalizeBonuses(DateTime month) async {
    final me = _requireRole(_owner, 'Only the owner can finalise bonuses.');
    final period = DateTime(month.year, month.month);
    if (!period.isBefore(Dates.startOfMonth(_clock()))) {
      throw const ValidationException('Only completed months can be finalised');
    }
    _finalize(period, me.id);
    await _save();
  }

  void _finalize(DateTime month, String approvedBy) {
    final period = DateTime(month.year, month.month);
    final now = _clock();
    for (final sp in _users.where((u) => u.role == UserRole.salesperson)) {
      final existing = _bonuses.indexWhere((b) => b.salespersonId == sp.id && b.periodStart == period);
      if (existing >= 0 && _bonuses[existing].status == BonusStatus.paid) continue;
      final base = BonusCalculator.monthlyBase(_sales, sp.id, period);
      final r = BonusCalculator.compute(basePaise: base, targetPaise: sp.monthlyTargetPaise, rules: _rules);
      final bonus = Bonus(
        id: existing >= 0 ? _bonuses[existing].id : _uuid.v4(),
        salespersonId: sp.id,
        periodStart: period,
        salesPaise: base,
        targetPaise: sp.monthlyTargetPaise,
        achievementPct: r.achievementPct,
        ruleName: r.rule?.name,
        commissionPct: r.rule?.commissionPct ?? 0,
        commissionPaise: r.commissionPaise,
        flatBonusPaise: r.flatBonusPaise,
        totalPaise: r.totalPaise,
        status: BonusStatus.approved,
        approvedAt: now,
      );
      if (existing >= 0) {
        _bonuses[existing] = bonus;
      } else {
        _bonuses.add(bonus);
      }
    }
  }

  Bonus _withStatus(Bonus b, BonusStatus status, DateTime? paidAt) =>
      Bonus.fromJson(b.toJson()
        ..['status'] = status.name
        ..['paid_at'] = encodeDate(paidAt));

  @override
  Future<void> markBonusPaid(String bonusId) async {
    _requireRole(_owner, 'Only the owner can mark bonuses as paid.');
    final i = _bonuses.indexWhere((b) => b.id == bonusId);
    if (i < 0) throw const ValidationException('Bonus not found');
    _bonuses[i] = _withStatus(_bonuses[i], BonusStatus.paid, _clock());
    await _save();
  }

  // ---- demo --------------------------------------------------------------

  @override
  Future<void> resetDemoData() async {
    final keepSession = _sessionUserId;
    await _seed();
    _sessionUserId = keepSession;
    _currentUser = keepSession == null ? null : _userById(keepSession);
    if (_currentUser == null) _sessionUserId = null;
    await _save();
  }
}
