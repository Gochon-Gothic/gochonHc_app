import 'package:intl/intl.dart';

class DateUtils {
  // 현재 주의 월요일 구하기
  static DateTime getCurrentWeekStart() {
    final now = DateTime.now();
    final weekday = now.weekday;
    if (weekday == 1) {
      return now;
    } else {
      return now.subtract(Duration(days: weekday - 1));
    }
  }

  // 현재 주의 금요일 구하기
  static DateTime getCurrentWeekEnd() {
    final weekStart = getCurrentWeekStart();
    return weekStart.add(const Duration(days: 4));
  }

  // 날짜를 yyyyMMdd 형식으로 변환
  static String formatDate(DateTime date) {
    return DateFormat('yyyyMMdd').format(date);
  }

  // 날짜를 yyyy-MM-dd 형식으로 변환
  static String formatDateWithDash(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  // 주차별 날짜 범위 생성
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

  // 월별 날짜 범위 생성
  static List<Map<String, String>> generateMonthRanges(int year) {
    final ranges = <Map<String, String>>[];

    for (int month = 1; month <= 12; month++) {
      final monthStart = DateTime(year, month, 1);
      final monthEnd = DateTime(year, month + 1, 0);

      ranges.add({'from': formatDate(monthStart), 'to': formatDate(monthEnd)});
    }

    return ranges;
  }

  // 오늘 날짜가 주말인지 확인
  static bool isWeekend(DateTime date) {
    final weekday = date.weekday;
    return weekday == 6 || weekday == 7;
  }

  // 날짜가 오늘인지 확인
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}
