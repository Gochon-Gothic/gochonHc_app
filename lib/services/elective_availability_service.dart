import 'package:intl/intl.dart';
import 'api_service.dart';
import 'gsheet_service.dart';

/// 설정 화면에서 선택과목 설정 진입 전, 정보 존재 여부를 미리 확인하기 위한 서비스
class ElectiveAvailabilityService {
  static const _apiKey = '2cf24c119b434f93b2f916280097454a';
  static const _eduOfficeCode = 'J10';
  static const _schoolCode = '7531375';
  static const _set1 = ['지구과학Ⅰ', '물리학Ⅰ', '화학Ⅰ', '생명과학Ⅰ', '경제', '한국지리', '세계사', '윤리와 사상', '정치와 법'];
  static const _set2 = ['음악 연주', '미술 창작'];
  static const _set3 = ['일본어Ⅰ', '프로그래밍', '중국어Ⅰ'];
  static const _set4 = ['기하', '고전 읽기', '영어권 문화'];

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

  /// 선택과목 정보가 존재하는지 확인. true면 설정 화면으로 이동 가능, false면 모달만 표시
  static Future<bool> hasElectiveData(int grade, int classNum) async {
    try {
      Map<int, Map<String, String>>? gsheetElectiveSubjects;
      final Map<int, int> setRequiredCounts = {};

      if (grade == 2 || grade == 3) {
        final gradeData = grade == 2
            ? await GSheetService.getGrade2Subjects()
            : await GSheetService.getGrade3Subjects();
        final electiveSets = gradeData['elective'] as Map<int, Map<String, dynamic>>?;
        if (electiveSets != null) {
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
      }

      final thisWeekStart = _getWeekStart();
      final nextWeekStart = thisWeekStart.add(const Duration(days: 7));
      final formatter = DateFormat('yyyyMMdd');

      final responses = await Future.wait([
        ApiService.instance.getTimetable(
          apiKey: _apiKey,
          eduOfficeCode: _eduOfficeCode,
          schoolCode: _schoolCode,
          grade: grade.toString(),
          classNum: classNum.toString(),
          fromDate: formatter.format(thisWeekStart),
          toDate: formatter.format(thisWeekStart.add(const Duration(days: 4))),
        ),
        ApiService.instance.getTimetable(
          apiKey: _apiKey,
          eduOfficeCode: _eduOfficeCode,
          schoolCode: _schoolCode,
          grade: grade.toString(),
          classNum: classNum.toString(),
          fromDate: formatter.format(nextWeekStart),
          toDate: formatter.format(nextWeekStart.add(const Duration(days: 4))),
        ),
      ]);

      final slotsBySet = <int, Set<String>>{};
      final targetSetNumbers =
          ((grade == 2 || grade == 3) &&
                  gsheetElectiveSubjects != null &&
                  gsheetElectiveSubjects.isNotEmpty)
              ? (gsheetElectiveSubjects.keys.toList()..sort())
              : [1, 2, 3, 4];

      for (final setNum in targetSetNumbers) {
        slotsBySet[setNum] = {};
      }

      int? getSetNumber(String subject, Map<int, Map<String, String>>? gsheet) {
        if ((grade == 2 || grade == 3) && gsheet != null) {
          for (var setEntry in gsheet.entries) {
            for (var subEntry in setEntry.value.entries) {
              if (subject.contains(subEntry.key)) return setEntry.key;
            }
          }
        }
        final allSets = [_set1, _set2, _set3, _set4];
        for (int i = 0; i < allSets.length; i++) {
          if (allSets[i].any((s) => s.isNotEmpty && subject.contains(s))) {
            return i + 1;
          }
        }
        return null;
      }

      for (int weekIdx = 0; weekIdx < responses.length; weekIdx++) {
        final data = responses[weekIdx].data;
        final rows = _extractTimetableRows(data);
        if (rows == null) continue;

        for (var item in rows) {
          final subject = (item['ITRT_CNTNT'] as String? ?? '').trim();
          final dateStr = item['ALL_TI_YMD'] as String? ?? '';
          final periodStr = item['PERIO'] as String? ?? '';

          int? subjectSetNum = getSetNumber(subject, gsheetElectiveSubjects);
          if (subjectSetNum == null || dateStr.isEmpty || periodStr.isEmpty) continue;
          if (!targetSetNumbers.contains(subjectSetNum)) continue;

          String clean;
          if ((grade == 2 || grade == 3) && gsheetElectiveSubjects != null) {
            clean = gsheetElectiveSubjects[subjectSetNum]?.keys.firstWhere(
                  (name) => subject.contains(name),
                  orElse: () => subject,
                ) ?? subject;
          } else {
            final set = [null, _set1, _set2, _set3, _set4][subjectSetNum];
            clean = set?.firstWhere(
                  (s) => s.isNotEmpty && subject.contains(s),
                  orElse: () => subject,
                ) ?? subject;
          }
          if (clean.isEmpty) continue;

          slotsBySet[subjectSetNum]?.add(clean);
        }
      }

      final sortedSlotsBySet = <int, List<String>>{};
      for (final setNum in targetSetNumbers) {
        sortedSlotsBySet[setNum] = slotsBySet[setNum]?.toList() ?? [];
      }

      if ((grade == 2 || grade == 3) &&
          gsheetElectiveSubjects != null &&
          gsheetElectiveSubjects.isNotEmpty) {
        for (final setNum in targetSetNumbers) {
          final requiredCount = setRequiredCounts[setNum];
          final availableCount = sortedSlotsBySet[setNum]?.length ?? 0;
          if (requiredCount == null || requiredCount <= 0) return false;
          if (availableCount < requiredCount) return false;
        }
      }

      if ((grade == 2 || grade == 3) &&
          (sortedSlotsBySet.isEmpty ||
              sortedSlotsBySet.values.every((slots) => slots.isEmpty))) {
        return false;
      }

      return true;
    } catch (_) {
      return false;
    }
  }
}
