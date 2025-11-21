import 'package:gsheets/gsheets.dart';
import 'package:flutter/services.dart';
import '../models/notice.dart';

class GSheetService {
  static const String _spreadsheetId = '1Q45kRO9R_SUZoLvB78MZrbTUWnWTU-3MLL5Pfh8RZz4';
  static const String _worksheetTitle = '사용자정보';
  static GSheets? _gsheets;
  static Worksheet? _worksheet;
  static String? _credentials;

  static Future<String> _loadCredentials() async {
    if (_credentials != null) return _credentials!;
    try {
      final String jsonString = await rootBundle.loadString('assets/data/gochon-sheet-credentials.json');
      _credentials = jsonString;
      return _credentials!;
    } catch (_) {
      try {
        final String jsonString = await rootBundle.loadString('assets/data/gochonapp-478905-8119c2fd681f.json');
        _credentials = jsonString;
        return _credentials!;
      } catch (e) {
        throw Exception('Credentials 파일을 불러올 수 없습니다: $e');
      }
    }
  }

  static Future<void> initialize() async {
    try {
      final credentials = await _loadCredentials();
      _gsheets = GSheets(credentials);
      final spreadsheet = await _gsheets!.spreadsheet(_spreadsheetId);
      try {
        _worksheet = spreadsheet.worksheetByTitle(_worksheetTitle);
      } catch (_) {
        _worksheet = await spreadsheet.addWorksheet(_worksheetTitle);
      }
      await _ensureHeaders();
    } catch (e) {
      throw Exception('Google Sheets 초기화 실패: $e');
    }
  }

  static Future<void> _ensureHeaders() async {
    if (_worksheet == null) return;
    try {
      final firstRow = await _worksheet!.values.row(1);
      if (firstRow.isEmpty) {
        const headers = ['이메일', '이름', '학년', '반', '번호', '가입일시', '약관동의'];
        await _worksheet!.values.insertRow(1, headers);
      }
    } catch (_) {}
  }

  static Future<bool> saveUserInfo({
    required String email,
    required String name,
    required String grade,
    required String className,
    required String studentNumber,
    required bool agreedToTerms,
  }) async {
    try {
      if (_worksheet == null) await initialize();
      final now = DateTime.now();
      final formattedDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      final newRow = [
        email,
        name,
        grade,
        className,
        studentNumber,
        formattedDate,
        agreedToTerms ? '동의' : '미동의',
      ];
      await _worksheet!.values.appendRow(newRow);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, String>?> getUserInfo(String email) async {
    try {
      if (_worksheet == null) await initialize();
      final rows = await _worksheet!.values.allRows();
      if (rows.length < 2) return null;
      final headers = rows[0];
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isNotEmpty && row[0] == email) {
          final userInfo = <String, String>{};
          for (int j = 0; j < headers.length && j < row.length; j++) {
            userInfo[headers[j]] = row[j];
          }
          return userInfo;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static String? _noticeCredentials;

  static Future<String> _loadNoticeCredentials() async {
    if (_noticeCredentials != null) return _noticeCredentials!;
    try {
      final String jsonString = await rootBundle.loadString('assets/data/gochonapp-478905-8119c2fd681f.json');
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
}
