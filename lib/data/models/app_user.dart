import '../../core/utils/money.dart';
import 'enums.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.phone,
    this.monthlyTargetPaise = 0,
    this.isActive = true,
    this.joinedOn,
  });

  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final UserRole role;
  final int monthlyTargetPaise;
  final bool isActive;
  final DateTime? joinedOn;

  String get firstName => fullName.split(' ').first;

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        fullName: j['full_name'] as String? ?? '',
        email: j['email'] as String? ?? '',
        phone: j['phone'] as String?,
        role: UserRole.parse(j['role'] as String?),
        monthlyTargetPaise: Money.toPaise(j['monthly_target'] as num?),
        isActive: j['is_active'] as bool? ?? true,
        joinedOn: parseDateOnly(j['joined_on']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'role': role.name,
        'monthly_target': Money.toRupees(monthlyTargetPaise),
        'is_active': isActive,
        'joined_on': encodeDateOnly(joinedOn),
      };

  AppUser copyWith({String? fullName, String? phone, int? monthlyTargetPaise, bool? isActive, UserRole? role}) =>
      AppUser(
        id: id,
        fullName: fullName ?? this.fullName,
        email: email,
        phone: phone ?? this.phone,
        role: role ?? this.role,
        monthlyTargetPaise: monthlyTargetPaise ?? this.monthlyTargetPaise,
        isActive: isActive ?? this.isActive,
        joinedOn: joinedOn,
      );

  @override
  bool operator ==(Object other) =>
      other is AppUser &&
      other.id == id &&
      other.role == role &&
      other.isActive == isActive &&
      other.monthlyTargetPaise == monthlyTargetPaise &&
      other.fullName == fullName;

  @override
  int get hashCode => Object.hash(id, role, isActive, monthlyTargetPaise, fullName);
}
