import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notice.dart';

class GSheetService {
  // Google Apps Script 웹 앱 URL
  static const String _serviceUrl =
      'https://script.google.com/macros/s/AKfycbxMZBeV9vgKkqB-49Xz4Z0MGmCU95d6q3UB1e-gAdLlJvNdGVI_aCdExz_c5GO7itw/exec';

  static Future<List<Notice>> getNotices({int limit = 3, bool forceRefresh = false}) async {
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
  static Future<Map<String, dynamic>> getGrade2Subjects({bool forceRefresh = true}) async {
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
        
        // 공통과목: B열(과목명) -> C열(줄임말)
        final Map<String, String> commonSubjects = {};
        List<dynamic> commonData = [];
        
        if (decodedData is Map) {
          commonData = decodedData['common'] as List<dynamic>? ?? [];
        } else if (decodedData is List) {
          // Apps Script가 직접 리스트를 반환하는 경우 (공통과목만)
          commonData = decodedData;
        }
        
        for (var row in commonData) {
          String subjectName = '';
          String abbreviation = '';
          
          if (row is Map) {
            subjectName = row['B']?.toString().trim() ?? '';
            abbreviation = row['C']?.toString().trim() ?? '';
          } else if (row is List) {
            // 배열 형식: [null, '과목명', '줄임말'] 또는 ['과목명', '줄임말']
            if (row.length >= 3) {
              subjectName = row[1]?.toString().trim() ?? '';
              abbreviation = row[2]?.toString().trim() ?? '';
            } else if (row.length >= 2) {
              subjectName = row[0]?.toString().trim() ?? '';
              abbreviation = row[1]?.toString().trim() ?? '';
            }
          }
          
          // 공백행이 나오면 중단
          if (subjectName.isEmpty && abbreviation.isEmpty) {
            break;
          }
          
          if (subjectName.isNotEmpty && abbreviation.isNotEmpty) {
            commonSubjects[subjectName] = abbreviation;
          }
        }
        
        // 선택과목: 세트별로 과목명 -> 줄임말 매핑, 세트 이름 포함
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
            
            // 3행부터 시작 (인덱스 0이 1행이므로 인덱스 2부터가 3행)
            // 하지만 Apps Script가 이미 3행부터 반환한다면 그대로 사용
            int startIndex = 0;
            if (subjects.isNotEmpty) {
              // 첫 번째 행이 세트 이름인지 확인 (줄임말 열의 2행)
              // 만약 첫 번째 행에 과목명이 없고 줄임말만 있다면 그것은 세트 이름
              var firstRow = subjects[0];
              if (firstRow is List && firstRow.length >= 2) {
                String firstSubject = firstRow[0]?.toString().trim() ?? '';
                String firstAbbr = firstRow[1]?.toString().trim() ?? '';
                // 첫 번째 행에 과목명이 없고 줄임말만 있으면 세트 이름으로 간주
                if (firstSubject.isEmpty && firstAbbr.isNotEmpty) {
                  setName = firstAbbr;
                  startIndex = 1; // 3행부터 시작 (인덱스 1부터)
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
            
            // 3행부터 데이터 처리 (startIndex부터 시작)
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
              
              // 공백행이 나오면 중단 (과목명과 줄임말이 모두 비어있으면)
              if (subjectName.isEmpty && abbreviation.isEmpty) {
                break;
              }
              
              // 과목명과 줄임말이 모두 있어야만 추가
              if (subjectName.isNotEmpty && abbreviation.isNotEmpty) {
                subjectMap[subjectName] = abbreviation;
              }
            }
            
            electiveSets[setNum] = {
              'setName': setName,
              'subjects': subjectMap,
            };
          });
        }
        
        return {
          'common': commonSubjects,
          'elective': electiveSets,
        };
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
  static Future<Map<String, dynamic>> getGrade3Subjects({bool forceRefresh = true}) async {
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
        
        // 공통과목: B열(과목명) -> C열(줄임말)
        final Map<String, String> commonSubjects = {};
        List<dynamic> commonData = [];
        
        if (decodedData is Map) {
          commonData = decodedData['common'] as List<dynamic>? ?? [];
        } else if (decodedData is List) {
          // Apps Script가 직접 리스트를 반환하는 경우 (공통과목만)
          commonData = decodedData;
        }
        
        for (var row in commonData) {
          String subjectName = '';
          String abbreviation = '';
          
          if (row is Map) {
            subjectName = row['B']?.toString().trim() ?? '';
            abbreviation = row['C']?.toString().trim() ?? '';
          } else if (row is List) {
            // 배열 형식: [null, '과목명', '줄임말'] 또는 ['과목명', '줄임말']
            if (row.length >= 3) {
              subjectName = row[1]?.toString().trim() ?? '';
              abbreviation = row[2]?.toString().trim() ?? '';
            } else if (row.length >= 2) {
              subjectName = row[0]?.toString().trim() ?? '';
              abbreviation = row[1]?.toString().trim() ?? '';
            }
          }
          
          // 공백행이 나오면 중단
          if (subjectName.isEmpty && abbreviation.isEmpty) {
            break;
          }
          
          if (subjectName.isNotEmpty && abbreviation.isNotEmpty) {
            commonSubjects[subjectName] = abbreviation;
          }
        }
        
        // 선택과목: 세트별로 과목명 -> 줄임말 매핑, 세트 이름 포함
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
            
            // 3행부터 시작 (인덱스 0이 1행이므로 인덱스 2부터가 3행)
            // 하지만 Apps Script가 이미 3행부터 반환한다면 그대로 사용
            int startIndex = 0;
            if (subjects.isNotEmpty) {
              // 첫 번째 행이 세트 이름인지 확인 (줄임말 열의 2행)
              // 만약 첫 번째 행에 과목명이 없고 줄임말만 있다면 그것은 세트 이름
              var firstRow = subjects[0];
              if (firstRow is List && firstRow.length >= 2) {
                String firstSubject = firstRow[0]?.toString().trim() ?? '';
                String firstAbbr = firstRow[1]?.toString().trim() ?? '';
                // 첫 번째 행에 과목명이 없고 줄임말만 있으면 세트 이름으로 간주
                if (firstSubject.isEmpty && firstAbbr.isNotEmpty) {
                  setName = firstAbbr;
                  startIndex = 1; // 3행부터 시작 (인덱스 1부터)
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
            
            // 3행부터 데이터 처리 (startIndex부터 시작)
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
              
              // 공백행이 나오면 중단 (과목명과 줄임말이 모두 비어있으면)
              if (subjectName.isEmpty && abbreviation.isEmpty) {
                break;
              }
              
              // 과목명과 줄임말이 모두 있어야만 추가
              if (subjectName.isNotEmpty && abbreviation.isNotEmpty) {
                subjectMap[subjectName] = abbreviation;
              }
            }
            
            electiveSets[setNum] = {
              'setName': setName,
              'subjects': subjectMap,
            };
          });
        }
        
        return {
          'common': commonSubjects,
          'elective': electiveSets,
        };
      } else {
        throw Exception(
          'API 서버로부터 3학년 과목 정보를 가져오는데 실패했습니다: ${response.statusCode}',
        );
      }
    } catch (e) {
      return {
        'common': <String, String>{},
        'elective': <int, Map<String, dynamic>>{},
      };
    }
  }

  // 1학년 과목 정보 가져오기 (과목명 -> 줄임말 매핑)
  static Future<Map<String, String>> getGrade1Subjects({bool forceRefresh = true}) async {
    // 임시로 캐시 완전 비활성화 (디버깅용)
    // final prefs = await SharedPreferences.getInstance();
    // const cacheKey = 'grade1_subjects_cache';
    // const lastUpdateKey = 'grade1_subjects_last_update';
    // const cacheExpiry = 24 * 60 * 60 * 1000; // 24시간 (밀리초)
    // final now = DateTime.now().millisecondsSinceEpoch;

    // 캐시 비활성화 - 항상 API에서 새로 가져오기

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
        final List<dynamic> data = json.decode(response.body);
        
        // B열(과목명)과 C열(줄임말) 매핑 생성
        final Map<String, String> subjectMap = {};
        for (var row in data) {
          // 구글 Apps Script가 반환하는 형식에 따라 다르게 처리
          String subjectName = '';
          String abbreviation = '';
          
          if (row is Map) {
            // 객체 형식: {'B': '공통국어', 'C': '국어'}
            subjectName = row['B']?.toString().trim() ?? '';
            abbreviation = row['C']?.toString().trim() ?? '';
          } else if (row is List) {
            // 배열 형식: ['공통국어', '국어'] 또는 [null, '공통국어', '국어']
            if (row.length >= 2) {
              subjectName = row[1]?.toString().trim() ?? '';
              abbreviation = row[2]?.toString().trim() ?? '';
            } else if (row.length >= 1) {
              subjectName = row[0]?.toString().trim() ?? '';
              abbreviation = row.length > 1 ? (row[1]?.toString().trim() ?? '') : '';
            }
          } else {
            continue;
          }
          
          // 공백행이 나오면 중단
          if (subjectName.isEmpty && abbreviation.isEmpty) {
            break;
          }
          
          // B열과 C열이 모두 있으면 매핑 추가
          if (subjectName.isNotEmpty && abbreviation.isNotEmpty) {
            subjectMap[subjectName] = abbreviation;
          }
        }

        // 캐시 저장 비활성화 (디버깅용)
        // await prefs.setString(cacheKey, json.encode(subjectMap));
        // await prefs.setInt(lastUpdateKey, now);

        return subjectMap;
      } else {
        throw Exception(
          'API 서버로부터 1학년 과목 정보를 가져오는데 실패했습니다: ${response.statusCode}',
        );
      }
    } catch (e) {
      // 오류 발생 시 빈 맵 반환
      return {};
    }
  }
}
