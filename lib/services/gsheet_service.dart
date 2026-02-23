import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notice.dart';

/// Google Apps Script 웹앱 API (공지, 학급수, 선택과목 시트)
///
/// [로직 흐름]
/// 1. getNotices: 12시간 캐시 → _serviceUrl GET → Notice 리스트 반환
/// 2. getClassCounts: 6개월 캐시 → action=getClassCounts
/// 3. getGrade2Subjects/getGrade3Subjects: sheetDate와 오늘 비교 → 3/2이거나 시트가 더 최신이면 API 호출
///    - common, elective 구조로 반환
/// 4. getGrade1Subjects: 1학년 공통과목만 (선택과목 없음)
/// 5. _parseSheetDate: "yyyy/M/d" 파싱, _todayKstDate: KST 오늘
class GSheetService {
  // Google Apps Script 웹 앱 URL
  static const String _serviceUrl =
      'https://script.google.com/macros/s/AKfycbwGsvKSB6Iw1MjSxBlIl8zPcpw7uYQZTc9IopeJVVBoN90f0Wt6AdbTCFEn2Qc6MYjT/exec';

  // yyyy/M/d 형식의 문자열을 DateTime(날짜만)으로 파싱
  static DateTime? _parseSheetDate(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    try {
      final parts = text.split('/');
      if (parts.length != 3) return null;
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  // KST(UTC+9) 기준 오늘 날짜(연·월·일만)
  static DateTime _todayKstDate() {
    final nowKst = DateTime.now().toUtc().add(const Duration(hours: 9));
    return DateTime(nowKst.year, nowKst.month, nowKst.day);
  }

  static Future<List<Notice>> getNotices({
    int limit = 3,
    bool forceRefresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    const cacheKey = 'notices_cache';
    const lastUpdateKey = 'notices_last_update';
    const cacheExpiry = 12 * 60 * 60 * 1000; // 12시간 (밀리초)
    final now = DateTime.now().millisecondsSinceEpoch;

    // forceRefresh가 true이면 캐시를 무시하고 API에서 새로 가져옵니다
    if (!forceRefresh) {
      final cachedData = prefs.getString(cacheKey);
      final lastUpdate = prefs.getInt(lastUpdateKey) ?? 0;

      if (cachedData != null && (now - lastUpdate) < cacheExpiry) {
        try {
          final List<dynamic> decodedData = json.decode(cachedData);
          final cachedNotices =
              decodedData
                  .map((item) => Notice.fromJson(item as Map<String, dynamic>))
                  .toList();
          return cachedNotices.take(limit).toList();
        } catch (_) {
          // 캐시 데이터가 손상된 경우, 새로 가져오기 위해 진행
        }
      }
    }

    try {
      var response = await http.get(Uri.parse(_serviceUrl));

      if (response.statusCode == 302) {
        final redirectUrl = response.headers['location'];
        if (redirectUrl != null) {
          response = await http.get(Uri.parse(redirectUrl));
        }
      }

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        final notices =
            data
                .map((item) => Notice.fromJson(item as Map<String, dynamic>))
                .toList();

        await prefs.setString(
          cacheKey,
          json.encode(notices.map((n) => n.toJson()).toList()),
        );
        await prefs.setInt(lastUpdateKey, now);

        return notices.take(limit).toList();
      } else {
        throw Exception('API 서버로부터 데이터를 가져오는데 실패했습니다: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('공지사항을 불러오는데 실패했습니다: $e');
    }
  }

  static Future<Map<int, int>> getClassCounts() async {
    final prefs = await SharedPreferences.getInstance();
    const cacheKey = 'class_counts_cache';
    const lastUpdateKey = 'class_counts_last_update';
    const cacheExpiry = 6 * 30 * 24 * 60 * 60 * 1000; // 6개월 (밀리초)

    final cachedData = prefs.getString(cacheKey);
    final lastUpdate = prefs.getInt(lastUpdateKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (cachedData != null && (now - lastUpdate) < cacheExpiry) {
      try {
        final Map<String, dynamic> decoded = json.decode(cachedData);
        return decoded.map(
          (key, value) => MapEntry(int.parse(key), value as int),
        );
      } catch (_) {
        // 캐시 데이터가 손상된 경우, 새로 가져오기 위해 진행
      }
    }

    try {
      final url = Uri.parse('$_serviceUrl?action=getClassCounts');
      var response = await http.get(url);

      if (response.statusCode == 302) {
        final redirectUrl = response.headers['location'];
        if (redirectUrl != null) {
          response = await http.get(Uri.parse(redirectUrl));
        }
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final counts = data.map(
          (key, value) => MapEntry(int.parse(key), value as int),
        );

        await prefs.setString(cacheKey, json.encode(data));
        await prefs.setInt(lastUpdateKey, now);

        return counts;
      } else {
        throw Exception(
          'API 서버로부터 학급 수 정보를 가져오는데 실패했습니다: ${response.statusCode}',
        );
      }
    } catch (e) {
      // 오류 발생 시 기본값 반환
      return {1: 11, 2: 11, 3: 11};
    }
  }

  // 2학년 과목 정보 가져오기 (공통과목 + 선택과목)
  static Future<Map<String, dynamic>> getGrade2Subjects({
    bool forceRefresh = false,
  }) async {
    const cacheKey = 'grade2_subjects_cache';
    const appliedDateKey = 'grade2_subjects_applied_date';
    final prefs = await SharedPreferences.getInstance();

    // 캐시된 데이터 우선 로드
    Map<String, dynamic>? cachedResult;
    final cachedJson = prefs.getString(cacheKey);
    if (cachedJson != null && cachedJson.isNotEmpty) {
      try {
        final decoded = json.decode(cachedJson) as Map<String, dynamic>;
        // common: Map<String, String>
        final common = Map<String, String>.from(decoded['common'] ?? {});
        // elective: Map<String, dynamic> with int keys
        final Map<String, dynamic> electiveDynamic = Map<String, dynamic>.from(
          decoded['elective'] ?? {},
        );
        final Map<int, Map<String, dynamic>> elective = {};
        electiveDynamic.forEach((key, value) {
          final setNum = int.tryParse(key);
          if (setNum != null && value is Map<String, dynamic>) {
            elective[setNum] = value;
          }
        });
        cachedResult = {'common': common, 'elective': elective};
      } catch (_) {
        cachedResult = null;
      }
    }

    final today = _todayKstDate();
    final isMarch2 = today.month == 3 && today.day == 2;
    if (!forceRefresh && !isMarch2 && cachedResult != null) {
      return cachedResult;
    }

    try {
      final url = Uri.parse('$_serviceUrl?action=getGrade2Subjects');
      var response = await http.get(url);
      if (response.statusCode == 302) {
        final redirectUrl = response.headers['location'];
        if (redirectUrl != null) {
          response = await http.get(Uri.parse(redirectUrl));
        }
      }
      if (response.statusCode == 200) {
        final dynamic decodedData = json.decode(response.body);

        // 시트의 D열 3행 텍스트(예: 2026/3/2)가 있다고 가정하고 읽기 (없으면 null)
        String? sheetDateText;
        if (decodedData is Map && decodedData['sheetDate'] is String) {
          sheetDateText = decodedData['sheetDate'] as String;
        }
        final DateTime? sheetDate = _parseSheetDate(sheetDateText);
        final DateTime today = _todayKstDate();
        final String? appliedText = prefs.getString(appliedDateKey);

        // 공통과목 파싱
        final Map<String, String> commonSubjects = {};
        if (decodedData is Map) {
          final commonValue = decodedData['common'];
          if (commonValue is Map) {
            commonValue.forEach((key, value) {
              if (key is String && value is String) {
                commonSubjects[key] = value;
              }
            });
          } else if (commonValue is List) {
            for (var row in commonValue) {
              String subjectName = '';
              String abbreviation = '';
              if (row is Map) {
                subjectName = row['B']?.toString().trim() ?? '';
                abbreviation = row['C']?.toString().trim() ?? '';
              } else if (row is List) {
                if (row.length >= 3) {
                  subjectName = row[1]?.toString().trim() ?? '';
                  abbreviation = row[2]?.toString().trim() ?? '';
                } else if (row.length >= 2) {
                  subjectName = row[0]?.toString().trim() ?? '';
                  abbreviation = row[1]?.toString().trim() ?? '';
                }
              }
              if (subjectName.isEmpty && abbreviation.isEmpty) break;
              if (subjectName.isNotEmpty && abbreviation.isNotEmpty) {
                commonSubjects[subjectName] = abbreviation;
              }
            }
          }
        } else if (decodedData is List) {
          for (var row in decodedData) {
            String subjectName = '';
            String abbreviation = '';
            if (row is Map) {
              subjectName = row['B']?.toString().trim() ?? '';
              abbreviation = row['C']?.toString().trim() ?? '';
            } else if (row is List) {
              if (row.length >= 3) {
                subjectName = row[1]?.toString().trim() ?? '';
                abbreviation = row[2]?.toString().trim() ?? '';
              } else if (row.length >= 2) {
                subjectName = row[0]?.toString().trim() ?? '';
                abbreviation = row[1]?.toString().trim() ?? '';
              }
            }
            if (subjectName.isEmpty && abbreviation.isEmpty) break;
            if (subjectName.isNotEmpty && abbreviation.isNotEmpty) {
              commonSubjects[subjectName] = abbreviation;
            }
          }
        }

        // 선택과목 세트 파싱 (requiredCount 지원)
        final Map<int, Map<String, dynamic>> electiveSets = {};
        if (decodedData is Map && decodedData.containsKey('elective')) {
          final electiveValue = decodedData['elective'];
          if (electiveValue is Map) {
            electiveValue.forEach((setNumStr, setData) {
              final setNum = int.tryParse(setNumStr);
              if (setNum == null) return;
              if (setData is Map) {
                String setName =
                    setData['setName']?.toString().trim() ?? '세트$setNum';
                int? requiredCount;
                final rcVal = setData['requiredCount'];
                if (rcVal is int) {
                  requiredCount = rcVal;
                } else if (rcVal is String) {
                  requiredCount = int.tryParse(rcVal);
                }

                final subjectsValue = setData['subjects'];
                if (subjectsValue is Map) {
                  final Map<String, String> subjectMap = {};
                  subjectsValue.forEach((key, value) {
                    if (key is String && value is String) {
                      subjectMap[key] = value;
                    }
                  });
                  electiveSets[setNum] = {
                    'setName': setName,
                    'subjects': subjectMap,
                    if (requiredCount != null) 'requiredCount': requiredCount,
                  };
                } else if (subjectsValue is List) {
                  final Map<String, String> subjectMap = {};
                  List<dynamic> subjects = subjectsValue;
                  int startIndex = 0;
                  if (subjects.isNotEmpty) {
                    var firstRow = subjects[0];
                    if (firstRow is List && firstRow.length >= 2) {
                      String firstSubject =
                          firstRow[0]?.toString().trim() ?? '';
                      String firstAbbr = firstRow[1]?.toString().trim() ?? '';
                      if (firstSubject.isEmpty && firstAbbr.isNotEmpty) {
                        setName = firstAbbr;
                        startIndex = 1;
                      }
                    } else if (firstRow is Map) {
                      String firstSubject =
                          firstRow['subject']?.toString().trim() ?? '';
                      String firstAbbr =
                          firstRow['abbreviation']?.toString().trim() ?? '';
                      if (firstSubject.isEmpty && firstAbbr.isNotEmpty) {
                        setName = firstAbbr;
                        startIndex = 1;
                      }
                    }
                  }
                  for (int i = startIndex; i < subjects.length; i++) {
                    var row = subjects[i];
                    String subjectName = '';
                    String abbreviation = '';
                    if (row is Map) {
                      subjectName = row['subject']?.toString().trim() ?? '';
                      abbreviation =
                          row['abbreviation']?.toString().trim() ?? '';
                    } else if (row is List) {
                      if (row.length >= 2) {
                        subjectName = row[0]?.toString().trim() ?? '';
                        abbreviation = row[1]?.toString().trim() ?? '';
                      }
                    }
                    if (subjectName.isEmpty && abbreviation.isEmpty) break;
                    if (subjectName.isNotEmpty && abbreviation.isNotEmpty) {
                      subjectMap[subjectName] = abbreviation;
                    }
                  }
                  electiveSets[setNum] = {
                    'setName': setName,
                    'subjects': subjectMap,
                    if (requiredCount != null) 'requiredCount': requiredCount,
                  };
                }
              } else if (setData is List) {
                final Map<String, String> subjectMap = {};
                List<dynamic> subjects = setData;
                String setName = '세트$setNum';
                int startIndex = 0;
                if (subjects.isNotEmpty) {
                  var firstRow = subjects[0];
                  if (firstRow is List && firstRow.length >= 2) {
                    String firstSubject = firstRow[0]?.toString().trim() ?? '';
                    String firstAbbr = firstRow[1]?.toString().trim() ?? '';
                    if (firstSubject.isEmpty && firstAbbr.isNotEmpty) {
                      setName = firstAbbr;
                      startIndex = 1;
                    }
                  } else if (firstRow is Map) {
                    String firstSubject =
                        firstRow['subject']?.toString().trim() ?? '';
                    String firstAbbr =
                        firstRow['abbreviation']?.toString().trim() ?? '';
                    if (firstSubject.isEmpty && firstAbbr.isNotEmpty) {
                      setName = firstAbbr;
                      startIndex = 1;
                    }
                  }
                }
                for (int i = startIndex; i < subjects.length; i++) {
                  var row = subjects[i];
                  String subjectName = '';
                  String abbreviation = '';
                  if (row is Map) {
                    subjectName = row['subject']?.toString().trim() ?? '';
                    abbreviation = row['abbreviation']?.toString().trim() ?? '';
                  } else if (row is List) {
                    if (row.length >= 2) {
                      subjectName = row[0]?.toString().trim() ?? '';
                      abbreviation = row[1]?.toString().trim() ?? '';
                    }
                  }
                  if (subjectName.isEmpty && abbreviation.isEmpty) break;
                  if (subjectName.isNotEmpty && abbreviation.isNotEmpty) {
                    subjectMap[subjectName] = abbreviation;
                  }
                }
                electiveSets[setNum] = {
                  'setName': setName,
                  'subjects': subjectMap,
                };
              }
            });
          }
        }

        final result = {'common': commonSubjects, 'elective': electiveSets};

        // 시트 날짜 기준 업데이트 여부 결정
        bool shouldApplyNow = true;
        if (sheetDate != null) {
          if (appliedText == sheetDateText) {
            // 이미 이 날짜 기준으로 데이터가 적용된 상태
            shouldApplyNow = false;
          } else if (sheetDate.isAfter(today) && cachedResult != null) {
            // 오늘보다 미래 날짜면, 기존 캐시를 유지하고 해당 날짜가 되면 갱신
            shouldApplyNow = false;
          }
        }

        if (shouldApplyNow) {
          await prefs.setString(
            cacheKey,
            json.encode({
              'common': commonSubjects,
              'elective': electiveSets.map(
                (key, value) => MapEntry(key.toString(), value),
              ),
            }),
          );
          if (sheetDateText != null) {
            await prefs.setString(appliedDateKey, sheetDateText);
          }
          return result;
        } else if (cachedResult != null) {
          // 캐시 유지
          return cachedResult;
        } else {
          // 캐시가 없으면 새 데이터 사용
          await prefs.setString(
            cacheKey,
            json.encode({
              'common': commonSubjects,
              'elective': electiveSets.map(
                (key, value) => MapEntry(key.toString(), value),
              ),
            }),
          );
          if (sheetDateText != null) {
            await prefs.setString(appliedDateKey, sheetDateText);
          }
          return result;
        }
      } else {
        throw Exception(
          'API 서버로부터 2학년 과목 정보를 가져오는데 실패했습니다: ${response.statusCode}',
        );
      }
    } catch (e) {
      return {
        'common': <String, String>{},
        'elective': <int, Map<String, dynamic>>{},
      };
    }
  }

  // 3학년 과목 정보 가져오기 (공통과목 + 선택과목)
  static Future<Map<String, dynamic>> getGrade3Subjects({
    bool forceRefresh = false,
  }) async {
    const cacheKey = 'grade3_subjects_cache';
    const appliedDateKey = 'grade3_subjects_applied_date';
    final prefs = await SharedPreferences.getInstance();

    // 캐시된 데이터 우선 로드
    Map<String, dynamic>? cachedResult;
    final cachedJson = prefs.getString(cacheKey);
    if (cachedJson != null && cachedJson.isNotEmpty) {
      try {
        final decoded = json.decode(cachedJson) as Map<String, dynamic>;
        final common = Map<String, String>.from(decoded['common'] ?? {});
        final Map<String, dynamic> electiveDynamic = Map<String, dynamic>.from(
          decoded['elective'] ?? {},
        );
        final Map<int, Map<String, dynamic>> elective = {};
        electiveDynamic.forEach((key, value) {
          final setNum = int.tryParse(key);
          if (setNum != null && value is Map<String, dynamic>) {
            elective[setNum] = value;
          }
        });
        cachedResult = {'common': common, 'elective': elective};
      } catch (_) {
        cachedResult = null;
      }
    }

    final today = _todayKstDate();
    final isMarch2 = today.month == 3 && today.day == 2;
    if (!forceRefresh && !isMarch2 && cachedResult != null) {
      return cachedResult;
    }

    try {
      final url = Uri.parse('$_serviceUrl?action=getGrade3Subjects');
      var response = await http.get(url);
      if (response.statusCode == 302) {
        final redirectUrl = response.headers['location'];
        if (redirectUrl != null) {
          response = await http.get(Uri.parse(redirectUrl));
        }
      }
      if (response.statusCode == 200) {
        final dynamic decodedData = json.decode(response.body);

        String? sheetDateText;
        if (decodedData is Map && decodedData['sheetDate'] is String) {
          sheetDateText = decodedData['sheetDate'] as String;
        }
        final DateTime? sheetDate = _parseSheetDate(sheetDateText);
        final DateTime today = _todayKstDate();
        final String? appliedText = prefs.getString(appliedDateKey);

        final Map<String, String> commonSubjects = {};
        if (decodedData is Map) {
          final commonValue = decodedData['common'];
          if (commonValue is Map) {
            commonValue.forEach((key, value) {
              if (key is String && value is String) {
                commonSubjects[key] = value;
              }
            });
          } else if (commonValue is List) {
            for (var row in commonValue) {
              String subjectName = '';
              String abbreviation = '';
              if (row is Map) {
                subjectName = row['B']?.toString().trim() ?? '';
                abbreviation = row['C']?.toString().trim() ?? '';
              } else if (row is List) {
                if (row.length >= 3) {
                  subjectName = row[1]?.toString().trim() ?? '';
                  abbreviation = row[2]?.toString().trim() ?? '';
                } else if (row.length >= 2) {
                  subjectName = row[0]?.toString().trim() ?? '';
                  abbreviation = row[1]?.toString().trim() ?? '';
                }
              }
              if (subjectName.isEmpty && abbreviation.isEmpty) break;
              if (subjectName.isNotEmpty && abbreviation.isNotEmpty) {
                commonSubjects[subjectName] = abbreviation;
              }
            }
          }
        } else if (decodedData is List) {
          for (var row in decodedData) {
            String subjectName = '';
            String abbreviation = '';
            if (row is Map) {
              subjectName = row['B']?.toString().trim() ?? '';
              abbreviation = row['C']?.toString().trim() ?? '';
            } else if (row is List) {
              if (row.length >= 3) {
                subjectName = row[1]?.toString().trim() ?? '';
                abbreviation = row[2]?.toString().trim() ?? '';
              } else if (row.length >= 2) {
                subjectName = row[0]?.toString().trim() ?? '';
                abbreviation = row[1]?.toString().trim() ?? '';
              }
            }
            if (subjectName.isEmpty && abbreviation.isEmpty) break;
            if (subjectName.isNotEmpty && abbreviation.isNotEmpty) {
              commonSubjects[subjectName] = abbreviation;
            }
          }
        }

        final Map<int, Map<String, dynamic>> electiveSets = {};
        if (decodedData is Map && decodedData.containsKey('elective')) {
          final electiveValue = decodedData['elective'];
          if (electiveValue is Map) {
            electiveValue.forEach((setNumStr, setData) {
              final setNum = int.tryParse(setNumStr);
              if (setNum == null) return;
              if (setData is Map) {
                String setName =
                    setData['setName']?.toString().trim() ?? '세트$setNum';
                int? requiredCount;
                final rcVal = setData['requiredCount'];
                if (rcVal is int) {
                  requiredCount = rcVal;
                } else if (rcVal is String) {
                  requiredCount = int.tryParse(rcVal);
                }
                final subjectsValue = setData['subjects'];
                if (subjectsValue is Map) {
                  final Map<String, String> subjectMap = {};
                  subjectsValue.forEach((key, value) {
                    if (key is String && value is String) {
                      subjectMap[key] = value;
                    }
                  });
                  electiveSets[setNum] = {
                    'setName': setName,
                    'subjects': subjectMap,
                    if (requiredCount != null) 'requiredCount': requiredCount,
                  };
                } else if (subjectsValue is List) {
                  final Map<String, String> subjectMap = {};
                  List<dynamic> subjects = subjectsValue;
                  int startIndex = 0;
                  if (subjects.isNotEmpty) {
                    var firstRow = subjects[0];
                    if (firstRow is List && firstRow.length >= 2) {
                      String firstSubject =
                          firstRow[0]?.toString().trim() ?? '';
                      String firstAbbr = firstRow[1]?.toString().trim() ?? '';
                      if (firstSubject.isEmpty && firstAbbr.isNotEmpty) {
                        setName = firstAbbr;
                        startIndex = 1;
                      }
                    } else if (firstRow is Map) {
                      String firstSubject =
                          firstRow['subject']?.toString().trim() ?? '';
                      String firstAbbr =
                          firstRow['abbreviation']?.toString().trim() ?? '';
                      if (firstSubject.isEmpty && firstAbbr.isNotEmpty) {
                        setName = firstAbbr;
                        startIndex = 1;
                      }
                    }
                  }
                  for (int i = startIndex; i < subjects.length; i++) {
                    var row = subjects[i];
                    String subjectName = '';
                    String abbreviation = '';
                    if (row is Map) {
                      subjectName = row['subject']?.toString().trim() ?? '';
                      abbreviation =
                          row['abbreviation']?.toString().trim() ?? '';
                    } else if (row is List) {
                      if (row.length >= 2) {
                        subjectName = row[0]?.toString().trim() ?? '';
                        abbreviation = row[1]?.toString().trim() ?? '';
                      }
                    }
                    if (subjectName.isEmpty && abbreviation.isEmpty) break;
                    if (subjectName.isNotEmpty && abbreviation.isNotEmpty) {
                      subjectMap[subjectName] = abbreviation;
                    }
                  }
                  electiveSets[setNum] = {
                    'setName': setName,
                    'subjects': subjectMap,
                    if (requiredCount != null) 'requiredCount': requiredCount,
                  };
                }
              }
            });
          }
        }

        final result = {'common': commonSubjects, 'elective': electiveSets};

        // 시트 날짜 기준 업데이트 여부 결정
        bool shouldApplyNow = true;
        if (sheetDate != null) {
          if (appliedText == sheetDateText) {
            shouldApplyNow = false;
          } else if (sheetDate.isAfter(today) && cachedResult != null) {
            shouldApplyNow = false;
          }
        }

        if (shouldApplyNow) {
          await prefs.setString(
            cacheKey,
            json.encode({
              'common': commonSubjects,
              'elective': electiveSets.map(
                (key, value) => MapEntry(key.toString(), value),
              ),
            }),
          );
          if (sheetDateText != null) {
            await prefs.setString(appliedDateKey, sheetDateText);
          }
          return result;
        } else if (cachedResult != null) {
          return cachedResult;
        } else {
          await prefs.setString(
            cacheKey,
            json.encode({
              'common': commonSubjects,
              'elective': electiveSets.map(
                (key, value) => MapEntry(key.toString(), value),
              ),
            }),
          );
          if (sheetDateText != null) {
            await prefs.setString(appliedDateKey, sheetDateText);
          }
          return result;
        }
      } else {
        throw Exception(
          'API 서버로부터 3학년 과목 정보를 가져오는데 실패했습니다: ${response.statusCode}',
        );
      }
    } catch (_) {
      return {
        'common': <String, String>{},
        'elective': <int, Map<String, dynamic>>{},
      };
    }
  }

  // 1학년 과목 정보 가져오기 (과목명 -> 줄임말 매핑)
  static Future<Map<String, String>> getGrade1Subjects({
    bool forceRefresh = false,
  }) async {
    const cacheKey = 'grade1_subjects_cache';
    const appliedDateKey = 'grade1_subjects_applied_date';
    final prefs = await SharedPreferences.getInstance();

    Map<String, String>? cachedSubjects;
    final cachedJson = prefs.getString(cacheKey);
    if (cachedJson != null && cachedJson.isNotEmpty) {
      try {
        cachedSubjects = Map<String, String>.from(
          json.decode(cachedJson) as Map,
        );
      } catch (_) {
        cachedSubjects = null;
      }
    }

    if (!forceRefresh && cachedSubjects != null) {
      return cachedSubjects;
    }

    try {
      final url = Uri.parse('$_serviceUrl?action=getGrade1Subjects');
      var response = await http.get(url);
      if (response.statusCode == 302) {
        final redirectUrl = response.headers['location'];
        if (redirectUrl != null) {
          response = await http.get(Uri.parse(redirectUrl));
        }
      }
      if (response.statusCode == 200) {
        final dynamic decodedData = json.decode(response.body);

        String? sheetDateText;
        if (decodedData is Map && decodedData['sheetDate'] is String) {
          sheetDateText = decodedData['sheetDate'] as String;
        }
        final DateTime? sheetDate = _parseSheetDate(sheetDateText);
        final DateTime today = _todayKstDate();
        final String? appliedText = prefs.getString(appliedDateKey);

        final Map<String, String> subjects = {};
        if (decodedData is Map) {
          decodedData.forEach((key, value) {
            if (key is String && value is String) {
              subjects[key] = value;
            }
          });
        } else if (decodedData is List) {
          for (var item in decodedData) {
            if (item is List &&
                item.length >= 2 &&
                item[0] is String &&
                item[1] is String) {
              subjects[item[0]] = item[1];
            }
          }
        }

        bool shouldApplyNow = true;
        if (sheetDate != null) {
          if (appliedText == sheetDateText) {
            shouldApplyNow = false;
          } else if (sheetDate.isAfter(today) && cachedSubjects != null) {
            shouldApplyNow = false;
          }
        }

        if (shouldApplyNow) {
          await prefs.setString(cacheKey, json.encode(subjects));
          if (sheetDateText != null) {
            await prefs.setString(appliedDateKey, sheetDateText);
          }
          return subjects;
        } else if (cachedSubjects != null) {
          return cachedSubjects;
        } else {
          await prefs.setString(cacheKey, json.encode(subjects));
          if (sheetDateText != null) {
            await prefs.setString(appliedDateKey, sheetDateText);
          }
          return subjects;
        }
      } else {
        throw Exception(
          'API 서버로부터 1학년 과목 정보를 가져오는데 실패했습니다: ${response.statusCode}',
        );
      }
    } catch (e) {
      return {};
    }
  }

}
