import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notice.dart';

class GSheetService {
  // Google Apps Script 웹 앱 URL
  static const String _serviceUrl =
      'https://script.google.com/macros/s/AKfycbwBJPHOmeOXjVzjqW2icvxGR4kqwFn45oNVK-f91G2V7yGmtEAc_JWwNPpjCi8QlUvD/exec';

  static Future<List<Notice>> getNotices({
    int limit = 3,
    bool forceRefresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    const cacheKey = 'notices_cache';
    const lastUpdateKey = 'notices_last_update';
    const cacheExpiry = 15 * 60 * 1000; // 15분 (밀리초)
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
    bool forceRefresh = true,
  }) async {
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
        final Map<String, String> commonSubjects = {};
        List<dynamic> commonData = [];
        if (decodedData is Map) {
          commonData = decodedData['common'] as List<dynamic>? ?? [];
        } else if (decodedData is List) {
          commonData = decodedData;
        }
        for (var row in commonData) {
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
        final Map<int, Map<String, dynamic>> electiveSets = {};
        if (decodedData is Map && decodedData.containsKey('elective')) {
          final Map<String, dynamic> electiveData = decodedData['elective'] as Map<String, dynamic>? ?? {};
          electiveData.forEach((setNumStr, setData) {
            final setNum = int.tryParse(setNumStr);
            if (setNum == null) return;
            String setName = '세트$setNum';
            final Map<String, String> subjectMap = {};
            List<dynamic> subjects = [];
            if (setData is Map) {
              setName = setData['setName']?.toString().trim() ?? setName;
              subjects = setData['subjects'] as List<dynamic>? ?? [];
            } else if (setData is List) {
              subjects = setData;
            }
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
                String firstSubject = firstRow['subject']?.toString().trim() ?? '';
                String firstAbbr = firstRow['abbreviation']?.toString().trim() ?? '';
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
            electiveSets[setNum] = {'setName': setName, 'subjects': subjectMap};
          });
        }
        return {'common': commonSubjects, 'elective': electiveSets};
      } else {
        throw Exception('API 서버로부터 2학년 과목 정보를 가져오는데 실패했습니다: ${response.statusCode}');
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
    bool forceRefresh = true,
  }) async {
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
        print('=== 3학년 시트 원본 데이터 ===');
        print('Response body: ${response.body}');
        print('Decoded data type: ${decodedData.runtimeType}');
        print('Decoded data: $decodedData');
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
        print('=== 3학년 공통과목 ===');
        print('Common subjects count: ${commonSubjects.length}');
        commonSubjects.forEach((key, value) {
          print('  $key -> $value');
        });
        final Map<int, Map<String, dynamic>> electiveSets = {};
        if (decodedData is Map && decodedData.containsKey('elective')) {
          final electiveValue = decodedData['elective'];
          print('=== 3학년 선택과목 원본 데이터 ===');
          print('Elective data type: ${electiveValue.runtimeType}');
          print('Elective data: $electiveValue');
          if (electiveValue is Map) {
            electiveValue.forEach((setNumStr, setData) {
              final setNum = int.tryParse(setNumStr);
              if (setNum == null) return;
              if (setData is Map) {
                String setName = setData['setName']?.toString().trim() ?? '세트$setNum';
                final subjectsValue = setData['subjects'];
                if (subjectsValue is Map) {
                  final Map<String, String> subjectMap = {};
                  subjectsValue.forEach((key, value) {
                    if (key is String && value is String) {
                      subjectMap[key] = value;
                    }
                  });
                  electiveSets[setNum] = {'setName': setName, 'subjects': subjectMap};
                } else if (subjectsValue is List) {
                  final Map<String, String> subjectMap = {};
                  List<dynamic> subjects = subjectsValue;
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
                      String firstSubject = firstRow['subject']?.toString().trim() ?? '';
                      String firstAbbr = firstRow['abbreviation']?.toString().trim() ?? '';
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
                  electiveSets[setNum] = {'setName': setName, 'subjects': subjectMap};
                }
              }
            });
          }
        }
        print('=== 3학년 선택과목 세트 ===');
        print('Elective sets count: ${electiveSets.length}');
        electiveSets.forEach((setNum, setData) {
          print('세트 $setNum: ${setData['setName']}');
          final subjects = setData['subjects'] as Map<String, String>?;
          if (subjects != null) {
            subjects.forEach((key, value) {
              print('  $key -> $value');
            });
          }
        });
        final result = {'common': commonSubjects, 'elective': electiveSets};
        print('=== 3학년 최종 반환 데이터 ===');
        print('Result: $result');
        return result;
      } else {
        throw Exception('API 서버로부터 3학년 과목 정보를 가져오는데 실패했습니다: ${response.statusCode}');
      }
    } catch (e) {
      print('=== 3학년 데이터 로드 에러 ===');
      print('Error: $e');
      return {
        'common': <String, String>{},
        'elective': <int, Map<String, dynamic>>{},
      };
    }
  }

  // 1학년 과목 정보 가져오기 (과목명 -> 줄임말 매핑)
  static Future<Map<String, String>> getGrade1Subjects({
    bool forceRefresh = true,
  }) async {
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
        final Map<String, String> subjects = {};
        if (decodedData is Map) {
          decodedData.forEach((key, value) {
            if (key is String && value is String) {
              subjects[key] = value;
            }
          });
        } else if (decodedData is List) {
          for (var item in decodedData) {
            if (item is List && item.length >= 2 && item[0] is String && item[1] is String) {
              subjects[item[0]] = item[1];
            }
          }
        }
        return subjects;
      } else {
        throw Exception('API 서버로부터 1학년 과목 정보를 가져오는데 실패했습니다: ${response.statusCode}');
      }
    } catch (e) {
      return {};
    }
  }
}
