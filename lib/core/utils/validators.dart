class Validators {
  const Validators._();

  static final _mobile = RegExp(r'^[6-9]\d{9}$');
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Strips spaces, dashes and a leading +91 / 0.
  static String normalizePhone(String input) {
    var p = input.replaceAll(RegExp(r'[\s\-()]'), '');
    if (p.startsWith('+91')) p = p.substring(3);
    if (p.length == 12 && p.startsWith('91')) p = p.substring(2);
    if (p.length == 11 && p.startsWith('0')) p = p.substring(1);
    return p;
  }

  static bool isMobile(String input) => _mobile.hasMatch(normalizePhone(input));

  static String? mobile(String? v) {
    if (v == null || v.trim().isEmpty) return 'Mobile number is required';
    if (!isMobile(v)) return 'Enter a valid 10-digit mobile number';
    return null;
  }

  static String? required(String? v, [String field = 'This field']) =>
      (v == null || v.trim().isEmpty) ? '$field is required' : null;

  static String? email(String? v, {bool optional = true}) {
    if (v == null || v.trim().isEmpty) return optional ? null : 'Email is required';
    return _email.hasMatch(v.trim()) ? null : 'Enter a valid email';
  }

  /// Formats 9820012345 as "98200 12345".
  static String prettyPhone(String phone) {
    final p = normalizePhone(phone);
    if (p.length != 10) return phone;
    return '${p.substring(0, 5)} ${p.substring(5)}';
  }
}
