import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/validators.dart';
import '../../data/models/models.dart';
import '../../domain/billing_calculator.dart';
import '../../domain/exceptions.dart';

class SplitPart {
  const SplitPart({required this.method, this.amountPaise = 0, this.reference = ''});
  final PaymentMethod method;
  final int amountPaise;
  final String reference;

  SplitPart copyWith({PaymentMethod? method, int? amountPaise, String? reference}) => SplitPart(
        method: method ?? this.method,
        amountPaise: amountPaise ?? this.amountPaise,
        reference: reference ?? this.reference,
      );
}

/// In-progress bill. Kept in a provider so it survives the review screen
/// and accidental navigation.
class BillDraft {
  const BillDraft({
    this.customer,
    this.customerName = '',
    this.customerPhone = '',
    this.salespersonId,
    this.items = const [],
    this.mode = PaymentMode.upi,
    this.reference = '',
    this.cashReceivedPaise,
    this.splits = const [SplitPart(method: PaymentMethod.cash), SplitPart(method: PaymentMethod.upi)],
    this.notes = '',
  });

  /// Existing customer, when one was selected or matched by phone.
  final Customer? customer;
  final String customerName;
  final String customerPhone;
  final String? salespersonId;
  final List<SaleItemInput> items;
  final PaymentMode mode;

  /// UPI transaction id / card last 4 digits (single-mode payments).
  final String reference;

  /// Cash handed over by the customer, to show change due.
  final int? cashReceivedPaise;
  final List<SplitPart> splits;
  final String notes;

  bool get isEmpty => customer == null && customerName.isEmpty && customerPhone.isEmpty && items.isEmpty;

  BillDraft copyWith({
    Customer? customer,
    bool clearCustomer = false,
    String? customerName,
    String? customerPhone,
    String? salespersonId,
    List<SaleItemInput>? items,
    PaymentMode? mode,
    String? reference,
    int? cashReceivedPaise,
    bool clearCashReceived = false,
    List<SplitPart>? splits,
    String? notes,
  }) =>
      BillDraft(
        customer: clearCustomer ? null : (customer ?? this.customer),
        customerName: customerName ?? this.customerName,
        customerPhone: customerPhone ?? this.customerPhone,
        salespersonId: salespersonId ?? this.salespersonId,
        items: items ?? this.items,
        mode: mode ?? this.mode,
        reference: reference ?? this.reference,
        cashReceivedPaise: clearCashReceived ? null : (cashReceivedPaise ?? this.cashReceivedPaise),
        splits: splits ?? this.splits,
        notes: notes ?? this.notes,
      );

  BillTotals totals(double gstRate) => BillingCalculator.preview(items, gstRate);

  int splitSum() => splits.fold(0, (s, p) => s + p.amountPaise);

  List<Payment> payments(int totalPaise) {
    if (mode == PaymentMode.split) {
      return splits
          .where((p) => p.amountPaise > 0)
          .map((p) => Payment(method: p.method, amountPaise: p.amountPaise, reference: p.reference))
          .toList();
    }
    final method = PaymentMethod.values.byName(mode.name);
    return [Payment(method: method, amountPaise: totalPaise, reference: reference)];
  }

  /// Problems that block saving, in display order. Empty = ready.
  List<String> problems(double gstRate) {
    final out = <String>[];
    if (customer == null) {
      if (customerName.trim().isEmpty) out.add('Enter the customer name');
      if (!Validators.isMobile(customerPhone)) out.add('Enter a valid 10-digit mobile number');
    }
    if (salespersonId == null) out.add('Select the salesperson for this sale');
    if (items.isEmpty) out.add('Add at least one saree');
    try {
      final t = BillingCalculator.compute(items, gstRate);
      if (items.isNotEmpty) {
        try {
          BillingCalculator.validatePayments(payments(t.totalPaise), t.totalPaise);
        } on ValidationException catch (e) {
          out.add(e.message);
        }
      }
    } on ValidationException catch (e) {
      out.add(e.message);
    }
    return out;
  }

  SaleInput toInput(double gstRate) {
    final t = BillingCalculator.compute(items, gstRate);
    return SaleInput(
      customerId: customer?.id,
      customerName: customer?.name ?? customerName.trim(),
      customerPhone: customer?.phone ?? Validators.normalizePhone(customerPhone),
      salespersonId: salespersonId ?? '',
      items: items,
      payments: payments(t.totalPaise),
      notes: notes.trim().isEmpty ? null : notes.trim(),
    );
  }
}

class BillDraftController extends Notifier<BillDraft> {
  @override
  BillDraft build() => const BillDraft();

  void reset() => state = const BillDraft();

  void selectCustomer(Customer c) =>
      state = state.copyWith(customer: c, customerName: c.name, customerPhone: c.phone);

  /// Typing in the phone/name fields detaches any selected customer; an
  /// exact phone match against [known] re-attaches it automatically.
  void editCustomer({String? name, String? phone, List<Customer> known = const []}) {
    final newPhone = phone ?? state.customerPhone;
    final newName = name ?? state.customerName;
    final match = Validators.isMobile(newPhone)
        ? known.where((c) => c.phone == Validators.normalizePhone(newPhone)).firstOrNull
        : null;
    if (match != null) {
      state = state.copyWith(customer: match, customerPhone: newPhone, customerName: match.name);
    } else {
      state = state.copyWith(clearCustomer: true, customerName: newName, customerPhone: newPhone);
    }
  }

  void clearCustomer() => state = state.copyWith(clearCustomer: true, customerName: '', customerPhone: '');

  void setSalesperson(String id) => state = state.copyWith(salespersonId: id);

  void addItem(SaleItemInput item) {
    // Same catalogue product with same price/discount: bump quantity.
    final i = state.items.indexWhere((e) =>
        e.productId != null &&
        e.productId == item.productId &&
        e.unitPricePaise == item.unitPricePaise &&
        e.discountType == item.discountType &&
        e.discountValue == item.discountValue &&
        // a flat ₹ discount applies to the whole line, so don't merge those
        (item.discountValue == 0 || item.discountType == DiscountType.percent));
    if (i >= 0) {
      final list = [...state.items];
      list[i] = list[i].copyWith(quantity: list[i].quantity + item.quantity);
      state = state.copyWith(items: list);
    } else {
      state = state.copyWith(items: [...state.items, item]);
    }
  }

  void updateItem(int index, SaleItemInput item) {
    final list = [...state.items];
    list[index] = item;
    state = state.copyWith(items: list);
  }

  void removeItem(int index) {
    final list = [...state.items]..removeAt(index);
    state = state.copyWith(items: list);
  }

  void setQuantity(int index, int qty) {
    if (qty < 1) return;
    updateItem(index, state.items[index].copyWith(quantity: qty));
  }

  void setMode(PaymentMode mode) => state = state.copyWith(mode: mode, reference: '', clearCashReceived: true);
  void setReference(String v) => state = state.copyWith(reference: v);
  void setCashReceived(int? paise) =>
      state = paise == null ? state.copyWith(clearCashReceived: true) : state.copyWith(cashReceivedPaise: paise);
  void setNotes(String v) => state = state.copyWith(notes: v);

  void setSplit(int index, SplitPart part) {
    final list = [...state.splits];
    list[index] = part;
    state = state.copyWith(splits: list);
  }

  void addSplit() {
    final used = state.splits.map((s) => s.method).toSet();
    final next = PaymentMethod.values.firstWhere((m) => !used.contains(m), orElse: () => PaymentMethod.card);
    state = state.copyWith(splits: [...state.splits, SplitPart(method: next)]);
  }

  void removeSplit(int index) {
    if (state.splits.length <= 2) return;
    final list = [...state.splits]..removeAt(index);
    state = state.copyWith(splits: list);
  }

  /// Puts the unpaid remainder into split row [index].
  void fillRemainder(int index, int totalPaise) {
    final others = state.splits.asMap().entries.where((e) => e.key != index).fold<int>(0, (s, e) => s + e.value.amountPaise);
    final remaining = totalPaise - others;
    if (remaining > 0) setSplit(index, state.splits[index].copyWith(amountPaise: remaining));
  }
}

final billDraftProvider = NotifierProvider<BillDraftController, BillDraft>(BillDraftController.new);
