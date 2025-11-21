import 'package:gsheets/gsheets.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notice.dart';

class GSheetService {
  static String? _noticeCredentials;

  static Future<String> _loadNoticeCredentials() async {
    if (_noticeCredentials != null) return _noticeCredentials!;
    try {
      final String jsonString = await rootBundle.loadString('assets/data/gochonapp-478905-9c5cec1fa71e.json');
      _noticeCredentials = jsonString;
      return _noticeCredentials!;
    } catch (e) {
      throw Exception('공지사항 credentials 파일을 불러올 수 없습니다: $e');
    }
  }

  static GSheets? _noticeGSheets;
  static Worksheet? _noticeWorksheet;
  static const String _noticeSpreadsheetId = '1PuH6M2yL-3A29b3cT9kl3CP7cGVbwGBms5Dhzg3E-AM';
  static const String _noticeWorksheetTitle = '공지사항';

  static Future<void> initializeNoticeService() async {
    try {
      final credentials = await _loadNoticeCredentials();
      _noticeGSheets = GSheets(credentials);
      final spreadsheet = await _noticeGSheets!.spreadsheet(_noticeSpreadsheetId);
      _noticeWorksheet = spreadsheet.worksheetByTitle(_noticeWorksheetTitle);
    } catch (e) {
      throw Exception('공지사항 Google Sheets 초기화 실패: $e');
    }
  }

  static Future<List<Notice>> getNotices({int limit = 3}) async {
    try {
      if (_noticeWorksheet == null) await initializeNoticeService();
      final rows = await _noticeWorksheet!.values.allRows();
      if (rows.length < 3) return [];

      final notices = <Notice>[];
      for (int i = 2; i < rows.length; i++) {
        final row = rows[i];
        if (row.length < 3) continue;
        
        final dateValue = row.length > 1 ? row[1] : null;
        final titleValue = row.length > 2 ? row[2] : null;
        final contentValue = row.length > 3 ? row[3] : null;
        
        final dateStr = (dateValue?.toString() ?? '').trim();
        final title = (titleValue?.toString() ?? '').trim();
        final content = (contentValue?.toString() ?? '').trim();
        
        if (title.isEmpty) continue;
        
        notices.add(Notice(date: dateStr, title: title, content: content));
      }

      notices.sort((a, b) {
        final aDate = a.parsedDate;
        final bDate = b.parsedDate;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

      return notices.take(limit).toList();
    } catch (e) {
      throw Exception('공지사항 가져오기 실패: $e');
    }
  }

  static Worksheet? _classCountWorksheet;
  static const String _classCountWorksheetTitle = '학년별반수';

  static Future<void> initializeClassCountService() async {
    try {
      final credentials = await _loadNoticeCredentials();
      if (_noticeGSheets == null) {
        _noticeGSheets = GSheets(credentials);
      }
      final spreadsheet = await _noticeGSheets!.spreadsheet(_noticeSpreadsheetId);
      _classCountWorksheet = spreadsheet.worksheetByTitle(_classCountWorksheetTitle);
      if (_classCountWorksheet == null) {
        throw Exception('"$_classCountWorksheetTitle" 시트를 찾을 수 없습니다.');
      }
    } catch (e) {
      throw Exception('학년별 반수 Google Sheets 초기화 실패: $e');
    }
  }

  static Future<Map<int, int>> getClassCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const cacheKey = 'class_counts_cache';
      const lastUpdateKey = 'class_counts_lastUpdate';
      const cacheExpiry = 6 * 30 * 24 * 60 * 60 * 1000; // 6개월 (밀리초)

      final cachedData = prefs.getString(cacheKey);
      final lastUpdate = prefs.getInt(lastUpdateKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      if (cachedData != null && (now - lastUpdate) < cacheExpiry) {
        try {
          final parts = cachedData.split(',');
          if (parts.length == 3) {
            return {
              1: int.tryParse(parts[0]) ?? 11,
              2: int.tryParse(parts[1]) ?? 11,
              3: int.tryParse(parts[2]) ?? 11,
            };
          }
        } catch (_) {
        }
      }

      if (_classCountWorksheet == null) await initializeClassCountService();
      if (_classCountWorksheet == null) {
        throw Exception('학년별반수 시트를 초기화할 수 없습니다.');
      }
      
      final grade1Count = await _classCountWorksheet!.values.value(column: 3, row: 3);
      final grade2Count = await _classCountWorksheet!.values.value(column: 3, row: 4);
      final grade3Count = await _classCountWorksheet!.values.value(column: 3, row: 5);

      final counts = {
        1: int.tryParse(grade1Count) ?? 11,
        2: int.tryParse(grade2Count) ?? 11,
        3: int.tryParse(grade3Count) ?? 11,
      };

      // 캐시 저장
      await prefs.setString(cacheKey, '${counts[1]},${counts[2]},${counts[3]}');
      await prefs.setInt(lastUpdateKey, now);

      return counts;
    } catch (e) {
      // 오류 발생 시 기본값 반환
      return {1: 11, 2: 11, 3: 11};
    }
  }
}
