import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';

import '../utils/preference_manager.dart';
import 'api_service.dart';
import 'gsheet_service.dart';

class MovementClassService {
  static const _eduOfficeCode = 'J10';
  static const _schoolCode = '7531375';
  static const _cacheDurationMs = 14 * 24 * 60 * 60 * 1000;

  static String get _apiKey => dotenv.env['NEIS_API_KEY_TIMETABLE'] ?? '';

  static DateTime getCurrentWindowStart() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 9));
    final weekday = now.weekday;
    final monday =
        weekday >= 6
            ? now.add(Duration(days: 8 - weekday))
            : now.subtract(Duration(days: weekday - 1));
    return DateTime(monday.year, monday.month, monday.day);
  }

  static List<dynamic>? _extractTimetableRows(dynamic decoded) {
    if (decoded is! Map || decoded['hisTimetable'] is! List) return null;
    final list = decoded['hisTimetable'] as List<dynamic>;

    List<dynamic>? rowsAt(int idx) {
      if (idx < 0 || idx >= list.length) return null;
      final item = list[idx];
      if (item is Map && item['row'] is List) {
        return item['row'] as List<dynamic>;
      }
      return null;
    }

    return rowsAt(3) ?? rowsAt(2) ?? rowsAt(1);
  }

  static String _slotKey(String date, String period) => '$date-$period';

  static Map<String, Map<String, String>> _decodeSlotSubjects(dynamic raw) {
    if (raw is! Map) return {};

    final result = <String, Map<String, String>>{};
    for (final entry in raw.entries) {
      final slotKey = entry.key.toString();
      final classSubjects = <String, String>{};
      if (entry.value is Map) {
        for (final classEntry in (entry.value as Map).entries) {
          final classNum = classEntry.key.toString();
          final subject = classEntry.value?.toString() ?? '';
          if (subject.isNotEmpty) {
            classSubjects[classNum] = subject;
          }
        }
      }
      result[slotKey] = classSubjects;
    }
    return result;
  }

  static Future<Map<String, Map<String, String>>> getGradeMovementSlots({
    required int grade,
    bool forceRefresh = false,
  }) async {
    final formatter = DateFormat('yyyyMMdd');
    final windowStart = getCurrentWindowStart();
    final windowStartKey = formatter.format(windowStart);

    if (!forceRefresh) {
      final cached = await PreferenceManager.instance.getMovementClassCache(
        grade,
      );
      if (cached != null) {
        final cachedStart = cached['windowStart']?.toString();
        final createdAt =
            int.tryParse(cached['createdAt']?.toString() ?? '') ?? 0;
        final now =
            DateTime.now()
                .toUtc()
                .add(const Duration(hours: 9))
                .millisecondsSinceEpoch;

        if (cachedStart == windowStartKey && (now - createdAt) < _cacheDurationMs) {
          return _decodeSlotSubjects(cached['slotSubjects']);
        }
      }
    }

    final classCounts = await GSheetService.getClassCounts();
    final maxClass = classCounts[grade] ?? 10;
    final nextWeekStart = windowStart.add(const Duration(days: 7));
    final dateRanges = [
      {
        'from': formatter.format(windowStart),
        'to': formatter.format(windowStart.add(const Duration(days: 4))),
      },
      {
        'from': formatter.format(nextWeekStart),
        'to': formatter.format(nextWeekStart.add(const Duration(days: 4))),
      },
    ];

    final responsesByClass = await Future.wait(
      List.generate(maxClass, (index) {
        final classNum = (index + 1).toString();
        return ApiService.instance.getBatchTimetables(
          apiKey: _apiKey,
          eduOfficeCode: _eduOfficeCode,
          schoolCode: _schoolCode,
          grade: grade.toString(),
          classNum: classNum,
          dateRanges: dateRanges,
        );
      }),
    );

    final slotSubjects = <String, Map<String, String>>{};
    for (int classIndex = 0; classIndex < responsesByClass.length; classIndex++) {
      final classNum = (classIndex + 1).toString();
      final classResponses = responsesByClass[classIndex];

      for (final response in classResponses) {
        final rows = _extractTimetableRows(response.data);
        if (rows == null) continue;

        for (final item in rows) {
          final date = item['ALL_TI_YMD']?.toString() ?? '';
          final period = item['PERIO']?.toString() ?? '';
          final subject = item['ITRT_CNTNT']?.toString().trim() ?? '';
          if (date.isEmpty || period.isEmpty || subject.isEmpty) continue;

          final slotKey = _slotKey(date, period);
          slotSubjects.putIfAbsent(slotKey, () => {});
          slotSubjects[slotKey]![classNum] = subject;
        }
      }
    }

    await PreferenceManager.instance.setMovementClassCache(grade, {
      'windowStart': windowStartKey,
      'createdAt':
          DateTime.now()
              .toUtc()
              .add(const Duration(hours: 9))
              .millisecondsSinceEpoch,
      'slotSubjects': slotSubjects,
    });

    return _decodeSlotSubjects(jsonDecode(jsonEncode(slotSubjects)));
  }
}
