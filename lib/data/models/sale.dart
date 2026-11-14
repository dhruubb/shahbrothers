import '../../core/utils/money.dart';
import 'enums.dart';

class SaleItem {
  const SaleItem({
    required this.productName,
    required this.productCode,
    required this.quantity,
    required this.unitPricePaise,
    required this.discountType,
    required this.discountValue,
    required this.discountPaise,
    required this.lineTotalPaise,
    this.id = '',
    this.productId,
  });

  final String id;
  final String? productId;
  final String productName;
  final String productCode;
  final int quantity;
  final int unitPricePaise;
  final DiscountType discountType;

  /// Percentage (e.g. 7.5) or rupee amount, as entered.
  final double discountValue;
  final int discountPaise;
  final int lineTotalPaise;

  int get grossPaise => quantity * unitPricePaise;

  String get discountLabel {
    if (discountPaise == 0) return '';
    if (discountType == DiscountType.percent) {
      final v = discountValue == discountValue.roundToDouble()
          ? discountValue.toStringAsFixed(0)
          : discountValue.toString();
      return '$v% off';
    }
    return '${Money.format(discountPaise)} off';
  }

  factory SaleItem.fromJson(Map<String, dynamic> j) => SaleItem(
        id: j['id'] as String? ?? '',
        productId: j['product_id'] as String?,
        productName: j['product_name'] as String? ?? '',
        productCode: j['product_code'] as String? ?? '',
        quantity: (j['quantity'] as num?)?.toInt() ?? 1,
        unitPricePaise: Money.toPaise(j['unit_price'] as num?),
        discountType: DiscountType.parse(j['discount_type'] as String?),
        discountValue: toDouble(j['discount_value']),
        discountPaise: Money.toPaise(j['discount_amount'] as num?),
        lineTotalPaise: Money.toPaise(j['line_total'] as num?),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'product_id': productId,
        'product_name': productName,
        'product_code': productCode,
        'quantity': quantity,
        'unit_price': Money.toRupees(unitPricePaise),
        'discount_type': discountType.name,
        'discount_value': discountValue,
        'discount_amount': Money.toRupees(discountPaise),
        'line_total': Money.toRupees(lineTotalPaise),
      };
}

class Payment {
  const Payment({required this.method, required this.amountPaise, this.reference, this.id = ''});

  final String id;
  final PaymentMethod method;
  final int amountPaise;
  final String? reference;

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        id: j['id'] as String? ?? '',
        method: PaymentMethod.parse(j['method'] as String?),
        amountPaise: Money.toPaise(j['amount'] as num?),
        reference: j['reference'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'method': method.name,
        'amount': Money.toRupees(amountPaise),
        'reference': reference,
      };
}

class Sale {
  const Sale({
    required this.id,
    required this.invoiceNumber,
    required this.customerId,
    required this.salespersonId,
    required this.managerId,
    required this.subtotalPaise,
    required this.discountPaise,
    required this.taxablePaise,
    required this.gstRate,
    required this.cgstPaise,
    required this.sgstPaise,
    required this.gstPaise,
    required this.roundOffPaise,
    required this.totalPaise,
    required this.paymentMode,
    required this.status,
    required this.createdAt,
    this.items = const [],
    this.payments = const [],
    this.customerName = '',
    this.customerPhone = '',
    this.salespersonName = '',
    this.managerName = '',
    this.notes,
    this.cancelReason,
    this.cancelledAt,
  });

  final String id;
  final String invoiceNumber;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String salespersonId;
  final String salespersonName;
  final String managerId;
  final String managerName;
  final int subtotalPaise;
  final int discountPaise;
  final int taxablePaise;
  final double gstRate;
  final int cgstPaise;
  final int sgstPaise;
  final int gstPaise;
  final int roundOffPaise;
  final int totalPaise;
  final PaymentMode paymentMode;
  final SaleStatus status;
  final String? notes;
  final DateTime createdAt;
  final List<SaleItem> items;
  final List<Payment> payments;
  final String? cancelReason;
  final DateTime? cancelledAt;

  bool get isCancelled => status == SaleStatus.cancelled;
  int get itemCount => items.fold(0, (s, i) => s + i.quantity);

  /// Reads both the Supabase shape (nested customer/salesperson/manager
  /// objects, sale_items) and the local store shape (same keys).
  factory Sale.fromJson(Map<String, dynamic> j) {
    final customer = j['customer'] as Map<String, dynamic>?;
    final sp = j['salesperson'] as Map<String, dynamic>?;
    final mgr = j['manager'] as Map<String, dynamic>?;
    final rawItems = ((j['sale_items'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList()
      ..sort((a, b) => ((a['position'] as num?) ?? 0).compareTo((b['position'] as num?) ?? 0));
    final items = rawItems.map(SaleItem.fromJson).toList();
    return Sale(
      id: j['id'] as String,
      invoiceNumber: j['invoice_number'] as String? ?? '',
      customerId: j['customer_id'] as String? ?? '',
      customerName: customer?['name'] as String? ?? '',
      customerPhone: customer?['phone'] as String? ?? '',
      salespersonId: j['salesperson_id'] as String? ?? '',
      salespersonName: sp?['full_name'] as String? ?? '',
      managerId: j['manager_id'] as String? ?? '',
      managerName: mgr?['full_name'] as String? ?? '',
      subtotalPaise: Money.toPaise(j['subtotal'] as num?),
      discountPaise: Money.toPaise(j['discount_total'] as num?),
      taxablePaise: Money.toPaise(j['taxable_amount'] as num?),
      gstRate: toDouble(j['gst_rate']),
      cgstPaise: Money.toPaise(j['cgst_amount'] as num?),
      sgstPaise: Money.toPaise(j['sgst_amount'] as num?),
      gstPaise: Money.toPaise(j['gst_amount'] as num?),
      roundOffPaise: Money.toPaise(j['round_off'] as num?),
      totalPaise: Money.toPaise(j['total'] as num?),
      paymentMode: PaymentMode.parse(j['payment_mode'] as String?),
      status: SaleStatus.parse(j['status'] as String?),
      notes: j['notes'] as String?,
      createdAt: parseDate(j['created_at']) ?? DateTime.now(),
      items: items,
      payments: ((j['payments'] as List?) ?? const [])
          .map((e) => Payment.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      cancelReason: j['cancel_reason'] as String?,
      cancelledAt: parseDate(j['cancelled_at']),
    );
  }

  /// Local-store representation (names are joined at read time).
  Map<String, dynamic> toJson() => {
        'id': id,
        'invoice_number': invoiceNumber,
        'customer_id': customerId,
        'salesperson_id': salespersonId,
        'manager_id': managerId,
        'subtotal': Money.toRupees(subtotalPaise),
        'discount_total': Money.toRupees(discountPaise),
        'taxable_amount': Money.toRupees(taxablePaise),
        'gst_rate': gstRate,
        'cgst_amount': Money.toRupees(cgstPaise),
        'sgst_amount': Money.toRupees(sgstPaise),
        'gst_amount': Money.toRupees(gstPaise),
        'round_off': Money.toRupees(roundOffPaise),
        'total': Money.toRupees(totalPaise),
        'payment_mode': paymentMode.name,
        'status': status.name,
        'notes': notes,
        'created_at': encodeDate(createdAt),
        'cancel_reason': cancelReason,
        'cancelled_at': encodeDate(cancelledAt),
        'sale_items': [for (var i = 0; i < items.length; i++) {...items[i].toJson(), 'position': i}],
        'payments': payments.map((e) => e.toJson()).toList(),
      };
}

/// What the billing screen submits. The repository/database recomputes the
/// totals from these lines, so the client cannot store inconsistent bills.
class SaleInput {
  const SaleInput({
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.salespersonId,
    required this.items,
    required this.payments,
    this.notes,
  });

  /// Existing customer id, or null to find/create by phone.
  final String? customerId;
  final String customerName;
  final String customerPhone;
  final String salespersonId;
  final List<SaleItemInput> items;
  final List<Payment> payments;
  final String? notes;

  Map<String, dynamic> toPayload() => {
        'customer': customerId != null && customerId!.isNotEmpty
            ? {'id': customerId}
            : {'name': customerName.trim(), 'phone': customerPhone},
        'salesperson_id': salespersonId,
        'notes': notes,
        'items': items.map((e) => e.toJson()).toList(),
        'payments': payments
            .map((p) => {
                  'method': p.method.name,
                  'amount': Money.toRupees(p.amountPaise),
                  if (p.reference != null && p.reference!.trim().isNotEmpty) 'reference': p.reference!.trim(),
                })
            .toList(),
      };
}

class SaleItemInput {
  const SaleItemInput({
    required this.productName,
    required this.productCode,
    required this.quantity,
    required this.unitPricePaise,
    this.productId,
    this.discountType = DiscountType.amount,
    this.discountValue = 0,
  });

  final String? productId;
  final String productName;
  final String productCode;
  final int quantity;
  final int unitPricePaise;
  final DiscountType discountType;

  /// Percent (e.g. 10) or rupees (e.g. 500).
  final double discountValue;

  SaleItemInput copyWith({
    int? quantity,
    int? unitPricePaise,
    DiscountType? discountType,
    double? discountValue,
    String? productName,
    String? productCode,
  }) =>
      SaleItemInput(
        productId: productId,
        productName: productName ?? this.productName,
        productCode: productCode ?? this.productCode,
        quantity: quantity ?? this.quantity,
        unitPricePaise: unitPricePaise ?? this.unitPricePaise,
        discountType: discountType ?? this.discountType,
        discountValue: discountValue ?? this.discountValue,
      );

  factory SaleItemInput.fromJson(Map<String, dynamic> j) => SaleItemInput(
        productId: j['product_id'] as String?,
        productName: j['product_name'] as String? ?? '',
        productCode: j['product_code'] as String? ?? '',
        quantity: (j['quantity'] as num).toInt(),
        unitPricePaise: Money.toPaise(j['unit_price'] as num),
        discountType: DiscountType.parse(j['discount_type'] as String?),
        discountValue: toDouble(j['discount_value']),
      );

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'product_name': productName,
        'product_code': productCode,
        'quantity': quantity,
        'unit_price': Money.toRupees(unitPricePaise),
        'discount_type': discountType.name,
        'discount_value': discountValue,
      };
}
