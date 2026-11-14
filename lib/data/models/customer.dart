import '../../core/utils/money.dart';
import 'enums.dart';

class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.city,
    this.notes,
    this.dateOfBirth,
    this.anniversary,
    this.preferredLanguage = 'en',
    this.preferredChannel = ContactChannel.none,
    this.marketingConsent = false,
    this.marketingConsentAt,
    this.marketingConsentSource,
    this.whatsappOptIn = false,
    this.smsOptIn = false,
    this.emailOptIn = false,
    this.telegramOptIn = false,
    this.tags = const [],
    this.createdAt,
  });

  /// Empty id means "not saved yet".
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? city;
  final String? notes;
  final DateTime? dateOfBirth;
  final DateTime? anniversary;
  final String preferredLanguage;
  final ContactChannel preferredChannel;
  final bool marketingConsent;
  final DateTime? marketingConsentAt;
  final String? marketingConsentSource;
  final bool whatsappOptIn;
  final bool smsOptIn;
  final bool emailOptIn;
  final bool telegramOptIn;
  final List<String> tags;
  final DateTime? createdAt;

  bool get isNew => id.isEmpty;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  List<String> get optedInChannels => [
        if (whatsappOptIn) 'WhatsApp',
        if (smsOptIn) 'SMS',
        if (emailOptIn) 'Email',
        if (telegramOptIn) 'Telegram',
      ];

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        email: j['email'] as String?,
        city: j['city'] as String?,
        notes: j['notes'] as String?,
        dateOfBirth: parseDateOnly(j['date_of_birth']),
        anniversary: parseDateOnly(j['anniversary']),
        preferredLanguage: j['preferred_language'] as String? ?? 'en',
        preferredChannel: ContactChannel.parse(j['preferred_channel'] as String?),
        marketingConsent: j['marketing_consent'] as bool? ?? false,
        marketingConsentAt: parseDate(j['marketing_consent_at']),
        marketingConsentSource: j['marketing_consent_source'] as String?,
        whatsappOptIn: j['whatsapp_opt_in'] as bool? ?? false,
        smsOptIn: j['sms_opt_in'] as bool? ?? false,
        emailOptIn: j['email_opt_in'] as bool? ?? false,
        telegramOptIn: j['telegram_opt_in'] as bool? ?? false,
        tags: (j['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        createdAt: parseDate(j['created_at']),
      );

  /// Columns written to the database (no id / created_at / created_by).
  Map<String, dynamic> toWriteJson() => {
        'name': name.trim(),
        'phone': phone,
        'email': (email?.trim().isEmpty ?? true) ? null : email!.trim(),
        'city': (city?.trim().isEmpty ?? true) ? null : city!.trim(),
        'notes': (notes?.trim().isEmpty ?? true) ? null : notes!.trim(),
        'date_of_birth': encodeDateOnly(dateOfBirth),
        'anniversary': encodeDateOnly(anniversary),
        'preferred_language': preferredLanguage,
        'preferred_channel': preferredChannel.name,
        'marketing_consent': marketingConsent,
        'marketing_consent_at': marketingConsent ? encodeDate(marketingConsentAt ?? DateTime.now()) : null,
        'marketing_consent_source': marketingConsent ? (marketingConsentSource ?? 'in_store_verbal') : null,
        // Opt-ins are only valid with explicit consent (enforced in SQL too).
        'whatsapp_opt_in': marketingConsent && whatsappOptIn,
        'sms_opt_in': marketingConsent && smsOptIn,
        'email_opt_in': marketingConsent && emailOptIn,
        'telegram_opt_in': marketingConsent && telegramOptIn,
        'tags': tags,
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        ...toWriteJson(),
        'created_at': encodeDate(createdAt),
      };

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? city,
    String? notes,
    DateTime? dateOfBirth,
    DateTime? anniversary,
    String? preferredLanguage,
    ContactChannel? preferredChannel,
    bool? marketingConsent,
    DateTime? marketingConsentAt,
    String? marketingConsentSource,
    bool? whatsappOptIn,
    bool? smsOptIn,
    bool? emailOptIn,
    bool? telegramOptIn,
    List<String>? tags,
    DateTime? createdAt,
  }) =>
      Customer(
        id: id ?? this.id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        city: city ?? this.city,
        notes: notes ?? this.notes,
        dateOfBirth: dateOfBirth ?? this.dateOfBirth,
        anniversary: anniversary ?? this.anniversary,
        preferredLanguage: preferredLanguage ?? this.preferredLanguage,
        preferredChannel: preferredChannel ?? this.preferredChannel,
        marketingConsent: marketingConsent ?? this.marketingConsent,
        marketingConsentAt: marketingConsentAt ?? this.marketingConsentAt,
        marketingConsentSource: marketingConsentSource ?? this.marketingConsentSource,
        whatsappOptIn: whatsappOptIn ?? this.whatsappOptIn,
        smsOptIn: smsOptIn ?? this.smsOptIn,
        emailOptIn: emailOptIn ?? this.emailOptIn,
        telegramOptIn: telegramOptIn ?? this.telegramOptIn,
        tags: tags ?? this.tags,
        createdAt: createdAt ?? this.createdAt,
      );
}

class CustomerStats {
  const CustomerStats({
    required this.customerId,
    this.purchaseCount = 0,
    this.totalSpentPaise = 0,
    this.lastPurchaseAt,
  });

  final String customerId;
  final int purchaseCount;
  final int totalSpentPaise;
  final DateTime? lastPurchaseAt;

  int get averagePaise => purchaseCount == 0 ? 0 : (totalSpentPaise / purchaseCount).round();

  factory CustomerStats.fromJson(Map<String, dynamic> j) => CustomerStats(
        customerId: j['customer_id'] as String,
        purchaseCount: (j['purchase_count'] as num?)?.toInt() ?? 0,
        totalSpentPaise: Money.toPaise(j['total_spent'] as num?),
        lastPurchaseAt: parseDate(j['last_purchase_at']),
      );
}
