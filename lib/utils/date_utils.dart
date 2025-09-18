import 'package:intl/intl.dart';

class DateUtils {
  static DateTime getCurrentWeekStart() {
    final now = DateTime.now();
    final weekday = now.weekday;
    if (weekday == 1) {
      return now;
    } else {
      return now.subtract(Duration(days: weekday - 1));
    }
  }

  static DateTime getCurrentWeekEnd() {
    final weekStart = getCurrentWeekStart();
    return weekStart.add(const Duration(days: 4));
  }

  static String formatDate(DateTime date) {
    return DateFormat('yyyyMMdd').format(date);
  }

  static String formatDateWithDash(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  static List<Map<String, String>> generateWeekRanges(int weeks) {
    final ranges = <Map<String, String>>[];
    final startDate = getCurrentWeekStart();

    for (int i = 0; i < weeks; i++) {
      final weekStart = startDate.add(Duration(days: i * 7));
      final weekEnd = weekStart.add(const Duration(days: 4));

      ranges.add({'from': formatDate(weekStart), 'to': formatDate(weekEnd)});
    }

    return ranges;
  }

  static List<Map<String, String>> generateMonthRanges(int year) {
    final ranges = <Map<String, String>>[];

    for (int month = 1; month <= 12; month++) {
      final monthStart = DateTime(year, month, 1);
      final monthEnd = DateTime(year, month + 1, 0);

      ranges.add({'from': formatDate(monthStart), 'to': formatDate(monthEnd)});
    }

    return ranges;
  }

  static bool isWeekend(DateTime date) {
    final weekday = date.weekday;
    return weekday == 6 || weekday == 7;
  }

  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}
