/// Money helpers. All amounts inside the app are integer paise to avoid
/// floating-point drift; the database stores numeric(12,2) rupees.
class Money {
  const Money._();

  static const symbol = '₹';

  /// Rupees (num from JSON/DB) -> paise.
  static int toPaise(num? rupees) => rupees == null ? 0 : (rupees * 100).round();

  /// Paise -> rupees as a double for JSON/DB.
  static double toRupees(int paise) => paise / 100;

  /// Parses user input such as "1,250.50" into paise. Returns null if invalid.
  static int? parse(String input) {
    final cleaned = input.replaceAll(',', '').replaceAll(symbol, '').trim();
    if (cleaned.isEmpty) return null;
    final value = double.tryParse(cleaned);
    if (value == null || value.isNaN || value.isInfinite) return null;
    return toPaise(value);
  }

  /// Indian digit grouping: 12,34,567
  static String groupIndian(int whole) {
    final negative = whole < 0;
    var s = whole.abs().toString();
    if (s.length > 3) {
      final last3 = s.substring(s.length - 3);
      var rest = s.substring(0, s.length - 3);
      final parts = <String>[];
      while (rest.length > 2) {
        parts.insert(0, rest.substring(rest.length - 2));
        rest = rest.substring(0, rest.length - 2);
      }
      if (rest.isNotEmpty) parts.insert(0, rest);
      s = '${parts.join(',')},$last3';
    }
    return negative ? '-$s' : s;
  }

  /// ₹12,34,567 or ₹12,34,567.50. Paise are shown when [decimals] is true,
  /// or automatically when the amount is not a whole rupee and [decimals]
  /// is null.
  static String format(int paise, {bool? decimals, bool withSymbol = true}) {
    final negative = paise < 0;
    final abs = paise.abs();
    final whole = abs ~/ 100;
    final fraction = abs % 100;
    final showDecimals = decimals ?? fraction != 0;
    final body = showDecimals
        ? '${groupIndian(whole)}.${fraction.toString().padLeft(2, '0')}'
        : groupIndian(((abs + 50) ~/ 100));
    return '${negative ? '-' : ''}${withSymbol ? symbol : ''}$body';
  }

  /// Compact Indian notation: ₹950, ₹12.5K, ₹3.42L, ₹1.2Cr
  static String compact(int paise, {bool withSymbol = true}) {
    final rupees = paise / 100;
    final abs = rupees.abs();
    final sign = rupees < 0 ? '-' : '';
    final sym = withSymbol ? symbol : '';
    String trim(double v, int digits) {
      var s = v.toStringAsFixed(digits);
      if (s.contains('.')) {
        s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
      }
      return s;
    }

    if (abs >= 1e7) return '$sign$sym${trim(abs / 1e7, 2)}Cr';
    if (abs >= 1e5) return '$sign$sym${trim(abs / 1e5, 2)}L';
    if (abs >= 1e3) return '$sign$sym${trim(abs / 1e3, 1)}K';
    return '$sign$sym${abs.round()}';
  }

  /// Plain ASCII amount for thermal printers: "Rs. 12,345.00"
  static String ascii(int paise) => 'Rs. ${format(paise, decimals: true, withSymbol: false)}';
}
