import 'package:intl/intl.dart';

/// Date helpers. Business dates are in the device's local time (the store
/// runs in India); the database stores timestamptz and the SQL functions use
/// Asia/Kolkata, so the two agree for devices set to IST.
class Dates {
  const Dates._();

  static DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month);
  static DateTime addMonths(DateTime d, int months) => DateTime(d.year, d.month + months, 1);
  static DateTime startOfWeek(DateTime d) => startOfDay(d).subtract(Duration(days: d.weekday - 1));
  static bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  /// Indian financial year code, e.g. 2026-11-13 -> "26-27", 2027-02-01 -> "26-27"
  static String financialYearCode(DateTime d) {
    final start = d.month >= 4 ? d.year : d.year - 1;
    String yy(int y) => (y % 100).toString().padLeft(2, '0');
    return '${yy(start)}-${yy(start + 1)}';
  }

  static String day(DateTime d) => DateFormat('d MMM yyyy').format(d);
  static String dayShort(DateTime d) => DateFormat('d MMM').format(d);
  static String time(DateTime d) => DateFormat('h:mm a').format(d);
  static String dayTime(DateTime d) => DateFormat('d MMM yyyy, h:mm a').format(d);
  static String month(DateTime d) => DateFormat('MMMM yyyy').format(d);
  static String monthShort(DateTime d) => DateFormat('MMM').format(d);
  static String monthYearShort(DateTime d) => DateFormat("MMM ''yy").format(d);
  static String weekday(DateTime d) => DateFormat('EEE').format(d);
  static String isoDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  /// "Today, 4:05 PM" / "Yesterday, 11:20 AM" / "3 Nov, 6:15 PM"
  static String relative(DateTime d, {DateTime? now}) {
    final n = now ?? DateTime.now();
    if (sameDay(d, n)) return 'Today, ${time(d)}';
    if (sameDay(d, n.subtract(const Duration(days: 1)))) return 'Yesterday, ${time(d)}';
    if (d.year == n.year) return '${dayShort(d)}, ${time(d)}';
    return dayTime(d);
  }

  static String greeting([DateTime? now]) {
    final h = (now ?? DateTime.now()).hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }
}
