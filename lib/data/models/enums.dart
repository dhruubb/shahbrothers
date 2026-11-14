enum UserRole {
  owner('Owner'),
  manager('Manager'),
  salesperson('Salesperson');

  const UserRole(this.label);
  final String label;

  static UserRole parse(String? v) =>
      UserRole.values.firstWhere((e) => e.name == v, orElse: () => UserRole.salesperson);
}

enum PaymentMethod {
  cash('Cash'),
  upi('UPI'),
  card('Card');

  const PaymentMethod(this.label);
  final String label;

  static PaymentMethod parse(String? v) =>
      PaymentMethod.values.firstWhere((e) => e.name == v, orElse: () => PaymentMethod.cash);
}

enum PaymentMode {
  cash('Cash'),
  upi('UPI'),
  card('Card'),
  split('Split');

  const PaymentMode(this.label);
  final String label;

  static PaymentMode parse(String? v) =>
      PaymentMode.values.firstWhere((e) => e.name == v, orElse: () => PaymentMode.cash);
}

enum DiscountType {
  percent('%'),
  amount('₹');

  const DiscountType(this.symbol);
  final String symbol;

  static DiscountType parse(String? v) =>
      DiscountType.values.firstWhere((e) => e.name == v, orElse: () => DiscountType.amount);
}

enum SaleStatus {
  completed,
  cancelled;

  static SaleStatus parse(String? v) =>
      SaleStatus.values.firstWhere((e) => e.name == v, orElse: () => SaleStatus.completed);
}

enum BonusStatus {
  approved('Approved'),
  paid('Paid');

  const BonusStatus(this.label);
  final String label;

  static BonusStatus parse(String? v) =>
      BonusStatus.values.firstWhere((e) => e.name == v, orElse: () => BonusStatus.approved);
}

/// Preferred marketing channel. WhatsApp/Telegram sending is not built yet;
/// the fields exist so integrations can be added without a migration.
enum ContactChannel {
  whatsapp('WhatsApp'),
  sms('SMS'),
  telegram('Telegram'),
  email('Email'),
  call('Phone call'),
  none('No preference');

  const ContactChannel(this.label);
  final String label;

  static ContactChannel parse(String? v) =>
      ContactChannel.values.firstWhere((e) => e.name == v, orElse: () => ContactChannel.none);
}

DateTime? parseDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v.toLocal();
  final s = v.toString();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s)?.toLocal();
}

String? encodeDate(DateTime? d) => d?.toUtc().toIso8601String();

/// Date-only values (birthday, period start) are stored as yyyy-MM-dd.
DateTime? parseDateOnly(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  if (s.length < 10) return null;
  final parts = s.substring(0, 10).split('-');
  if (parts.length != 3) return null;
  return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}

String? encodeDateOnly(DateTime? d) => d == null
    ? null
    : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

double toDouble(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);
