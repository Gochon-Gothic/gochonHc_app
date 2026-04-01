import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';
import 'gsheet_service.dart';

/// 선택과목 설정 화면 진입 전, 해당 학급에 선택과목 정보가 있는지 확인
///
/// [로직 흐름]
/// 1. hasElectiveData(grade, classNum): 2·3학년이면 GSheet에서 elective 과목 목록 조회
/// 2. 이번 주·다음 주 시간표 API 2회 병렬 호출
/// 3. 응답에서 hisTimetable[1~3].row 추출 → ITRT_CNTNT(과목명), ALL_TI_YMD, PERIO 파싱
/// 4. 과목명을 GSheet elective와 매칭해 slotsBySet에 수집
/// 5. 2·3학년: requiredCount 이상 슬롯이 있어야 true
class ElectiveAvailabilityService {
  static String get _apiKey => dotenv.env['NEIS_API_KEY_TIMETABLE'] ?? '';
  static const _eduOfficeCode = 'J10';
  static const _schoolCode = '7531375';

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

  static DateTime _getWeekStart() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 9));
    final weekday = now.weekday;
    return weekday >= 6
        ? now.add(Duration(days: 8 - weekday))
        : now.subtract(Duration(days: weekday - 1));
  }

  static String _normalizeSubject(String? value) {
    if (value == null || value.isEmpty) return '';
    return value
        .replaceAll(RegExp(r'[\s·\-\[\]()]'), '')
        .replaceAll('Ⅰ', '1')
        .replaceAll('Ⅱ', '2');
  }

  static bool _safeContains(String? source, String? target) {
    final normalizedSource = _normalizeSubject(source);
    final normalizedTarget = _normalizeSubject(target);
    if (normalizedSource.isEmpty || normalizedTarget.isEmpty) {
      return false;
    }
    return normalizedSource.contains(normalizedTarget);
  }

  /// 선택과목 정보가 존재하는지 확인. true면 설정 화면으로 이동 가능, false면 모달만 표시
  static Future<bool> hasElectiveData(int grade, int classNum) async {
    try {
      Map<int, Map<String, String>>? gsheetElectiveSubjects;
      final Map<int, int> setRequiredCounts = {};

      if (grade == 2 || grade == 3) {
        final gradeData = grade == 2
            ? await GSheetService.getGrade2Subjects(forceRefresh: true)
            : await GSheetService.getGrade3Subjects(forceRefresh: true);
        final electiveSets = gradeData['elective'] as Map<int, Map<String, dynamic>>?;
        if (electiveSets == null || electiveSets.isEmpty) return false;

        gsheetElectiveSubjects = {};
        electiveSets.forEach((setNum, setData) {
          Map<String, String>? subjects;
          final rawSubjects = setData['subjects'];
          if (rawSubjects is Map) {
            subjects = {};
            rawSubjects.forEach((key, value) {
              if (key != null && value != null) {
                subjects![key.toString()] = value.toString();
              }
            });
          }
          int? requiredCount;
          final rcVal = setData['requiredCount'];
          if (rcVal is int) {
            requiredCount = rcVal;
          } else if (rcVal is String) {
            requiredCount = int.tryParse(rcVal);
          }
          if (subjects != null && subjects.isNotEmpty) {
            gsheetElectiveSubjects![setNum] = subjects;
          }
          if (requiredCount != null && requiredCount > 0) {
            setRequiredCounts[setNum] = requiredCount;
          }
        });
      }

      final thisWeekStart = _getWeekStart();
      final nextWeekStart = thisWeekStart.add(const Duration(days: 7));
      final formatter = DateFormat('yyyyMMdd');
      final thisFrom = formatter.format(thisWeekStart);
      final nextFrom = formatter.format(nextWeekStart);

      final responses = await Future.wait([
        ApiService.instance.getTimetable(
          apiKey: _apiKey,
          eduOfficeCode: _eduOfficeCode,
          schoolCode: _schoolCode,
          grade: grade.toString(),
          classNum: classNum.toString(),
          fromDate: thisFrom,
          toDate: formatter.format(thisWeekStart.add(const Duration(days: 4))),
        ),
        ApiService.instance.getTimetable(
          apiKey: _apiKey,
          eduOfficeCode: _eduOfficeCode,
          schoolCode: _schoolCode,
          grade: grade.toString(),
          classNum: classNum.toString(),
          fromDate: nextFrom,
          toDate: formatter.format(nextWeekStart.add(const Duration(days: 4))),
        ),
      ]);

      if (gsheetElectiveSubjects == null || gsheetElectiveSubjects.isEmpty) {
        return false;
      }
      final electiveSubjectsBySet = gsheetElectiveSubjects;

      final slotsBySet = <int, Set<String>>{};
      final targetSetNumbers = (electiveSubjectsBySet.keys.toList()..sort());

      for (final setNum in targetSetNumbers) {
        slotsBySet[setNum] = {};
      }

      int? getSetNumber(String subject) {
        for (var setEntry in electiveSubjectsBySet.entries) {
          for (var subEntry in setEntry.value.entries) {
            if (_safeContains(subject, subEntry.key)) return setEntry.key;
          }
        }
        return null;
      }

      for (int weekIdx = 0; weekIdx < responses.length; weekIdx++) {
        final rows = _extractTimetableRows(responses[weekIdx].data);
        if (rows == null) continue;

        for (var item in rows) {
          final subject = (item['ITRT_CNTNT'] as String? ?? '').trim();
          final dateStr = item['ALL_TI_YMD'] as String? ?? '';
          final periodStr = item['PERIO'] as String? ?? '';

          int? subjectSetNum = getSetNumber(subject);
          if (subjectSetNum == null || dateStr.isEmpty || periodStr.isEmpty) continue;

          final clean = electiveSubjectsBySet[subjectSetNum]?.keys.firstWhere(
            (name) => _safeContains(subject, name),
            orElse: () => '',
          ) ?? '';
          if (clean.isEmpty) continue;

          slotsBySet[subjectSetNum]?.add(clean);
        }
      }

      final sortedSlotsBySet = <int, List<String>>{};
      for (final setNum in targetSetNumbers) {
        sortedSlotsBySet[setNum] = slotsBySet[setNum]?.toList() ?? [];
      }

      for (final setNum in targetSetNumbers) {
        final requiredCount = setRequiredCounts[setNum];
        final availableCount = sortedSlotsBySet[setNum]?.length ?? 0;
        if (requiredCount == null || requiredCount <= 0) return false;
        if (availableCount < requiredCount) return false;
      }

      return true;
    } catch (_) {
      return false;
    }
  }
}
