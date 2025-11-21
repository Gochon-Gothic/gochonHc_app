import 'package:gsheets/gsheets.dart';
import '../models/notice.dart';

class GSheetService {
  static const String _spreadsheetId = '1Q45kRO9R_SUZoLvB78MZrbTUWnWTU-3MLL5Pfh8RZz4';
  static const String _worksheetTitle = '사용자정보';
  static GSheets? _gsheets;
  static Worksheet? _worksheet;

  static const String _credentials = r'''
{
  "type": "service_account",
  "project_id": "gochon-sheet",
  "private_key_id": "2ecb643eb34777c8074d16fbb29ef7084f5c4744",
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQCz5AIngWvG5xGq\nesaFUc4xJpng6dPSywIUCOVevDmhH240+f3MVHYi+PudWpJTVfAO3W3YnuP168AP\nyHVDbEmLauhLWx8SpxO2SddGCdwFxeITNMXPpRQfdA5eZ0OzRdTUefXOZWXqE2XG\ncV8nLt4muhfy4NbIS5yt7qFe3My7NH+kruHeRSWYTqlmxFLngS/sZtze0kINlNjm\nNbm5Dqfpou00/yYgdsTfLqXliNwOOy4ChrkDWQbNszOavlCzok71X+z312fI8kn9\nV2fKSAU9+MErfb1qJtK8qSE4Z62PlhVjSYAv0akHuZJudR1Q3uOyRSGKrNblTYgk\nBrLlG4MbAgMBAAECggEAA/bSH7uK+97oFVqpRazWbCzbY6JwR/F86G+3WXQXM2uO\n5F0rigIrReM4udbFT+k35gv17Lnro7KzQ8wsd8GxVgCTTkqbj6/dqYmzbb6v4Fl9\nyhb10pKWGlW8/B8u1b3qZ76pFQhIMg7rxW8gJEWBh1byFvV8P8oZKzGnN4Dw6tS+\n3t6f3l0lDlMjQwZLfsKul1NNfBEFlztTzKPzMZBnXpSJdceat+OFijL3p40znQWF\n40Ykj1kK+EbT8hmVQx5zB7P4L4vHRgHX2YDAoxWTBmKDOVyKOs5KuA0vDFiyNe/m\nmWrzfQOAzyoZlHUeMLz5OMHXupqswS90r13Q6U5vAQKBgQDekfJ8UCttAo9ibLjq\nlQNXwJuJKLS7k82fEziyTXMTKSLZ4HoyFYC+AQb7l4Goyln4hG5+aoya7uwvy7qU\nYRuTEtnmbWRgLlet3eBH8dgwbCG746olukHOPx3WyVOOmJ9uFa+fUrTyqqHpzxYn\nIOM3Lga5Euu98MlP4J9xKpa2mwKBgQDO6P3sWKLhxJ202YHU+Sf85e/XR6CnFQmo\nXqS2LeLQ89oCrrK9dydoF3ZJ46lmayL0DGTn6AiZKCnsI6/c0FyXISHScO4duoaR\nvrdNrbcJDEaxfnb1Jgj6tzTgTXHB98JWYVtSbFciKWJChyPIlgVS8PbQni8KumiX\nDvOiLBTtgQKBgQCh43yCCXoct1D94WD7V9nvmSxIrrAPBCn6++swXf9Gv5QW8B1R\nkqxrB6pBk+j+kfixN/p6vxt4kjJ/bWtQA/YfmwWdgpIRF4Q09f7tta5vQiejV6xp\n9rlowCX/Fb9OKBtG4kU02N6+53gP7c4KNfSvLS48rdOE+8Ah9ptin/yx4wKBgAEs\nqWRSDHqjlxGTunzu/R8eXwIl0e+g2vEtuFmgYQ02lSI2w6T3rC2XFIDO3gNK0GP6\nPghi9MmJxNMmULU8KYpiEcMUCQX6LRFet8OlHMjcXPpc8Wfq01o49//d8KtdMKk0\n3EPXgZccDQa7paRZ1aXm4D/G5hV1gWp6Fz/waB4BAoGBAKZMgGzgE7Q87yOIS6qj\nKg+s/EKAsiAxbFMQX6Lg4ovzp4khBf7uNAJm2d3JEl/mnoEBo6P0AX4F5iSxckYy\nALTs+cFDJdwhEA7HWXxCPvdm9iE3wOJfBtlLbm/q0181GkwvNih3J47oy/BFfQpF\n9hbXOW39pjyN7pTIcZx5vZmf\n-----END PRIVATE KEY-----\n",
  "client_email": "gochon@gochon-sheet.iam.gserviceaccount.com",
  "client_id": "110262347580004949342",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/gochon%40gochon-sheet.iam.gserviceaccount.com",
  "universe_domain": "googleapis.com"
}
''';

  static Future<void> initialize() async {
    try {
      _gsheets = GSheets(_credentials);
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

  static const String _noticeCredentials = r'''
{
  "type": "service_account",
  "project_id": "gochonapp-478905",
  "private_key_id": "8119c2fd681f85ad1667c93735a78bf0fdac89ef",
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCmYoyP4u9OX0JY\n2ijEUmtU5VU6mI13yCjVxgWcIJkAFcclfLPZFyPQ3e8j1I5qnWoQsi4i/c3r9/FU\nOzM9Jytr7eXtQo/YupADPBef1sn4DfFR6P+YMTud7APx/GBbBtwFaatVjFABhe75\nyUidCVXlidIjOca0iHue+y/S1jx6yTf8XoYMPwBEIbGoXk613mCp8ueZSFihAOmv\noplveu2F6dBiqSsYmhpj2dmxVqwZ/eURrKf3G8HAPun9GcWcWg4HxHHhQxo6ZwYq\nRrqw/vNrNL0ZRaU5Pd4LyIOFA8XGOnpTeFFH9YDlXioHnQJS2SMv0oY4f3ogXPmx\nbCaByJ+xAgMBAAECggEAN3UZjMwDH4g4wQzWEbm29LEL22AFpyscEUTTkdp7pL+d\nhS0vdOh1k6SllLfAUGDvfWkmX5thC4m08nJY/cUUgADnZlGNSJvGbI2XAjvBTeC3\n0qlqp/ug9143YmzQYQbERzmVVgpSkG9n2/HvNghqjPuHAx660Gm9apwmsIuf1Py6\n/eef28wdX2HYRebMgJZi1qKEyj6dwQzhylqxVhWQ6W82bEe2/oalgDH0AJ+hshE5\nUpMT/2A/cIRjs7VqeFRe+244MuaXnfM15q/foxdloChBh/wDW7n7ot6RT3BdH3a5\nEwCk0sUbinrdi5jfAmKRvDMbyPlJy3KhytSZtaF40QKBgQDUOmx3vfgDWLA09ujB\nfWXgGML46dpFmmcyoCp7uDT0gefkOvGAzNiP8xdUFdKfGuVZ63j86cDHU8LSotau\nbh+Yfc7ToIruTwUO7hzP79sjO59ZkWBR7XNLsa+xQKdTlivDjaSTTpmEbGkCVKut\noNTl60ru3M2V91LaPLWu3vlD7wKBgQDIs537s7inL5zmZ98vqNmXznzRnK+QDY3q\nWo/XA9Z2SPagaA5B02a88QYqElsBZdFj3jFXTK87SzQVkfCbWw6i60OIlQUdkYgU\nRuzC057/9arWzPnFllu2iBrtwsVmJGL+ecVmRb9jF8xq/Js7h9rYQqUH3TSx5gvL\nwwSDPEw2XwKBgFfyFfzQ9jO8zthD8VQtOMhSuokXr2HkiBtMkA5Q2XDxXD0Rx/5N\n5PhSDjrECFHyfVRz5eE4pLB1H2jWHgyOif1RNSIxhyEWEcyME9h/VtoU3QXq3nVU\n5tBZQ6s6VZynwF77FVYN3kQoAKP8nmAHI/JbPOQbD/6zTNwvCEL9F2J1AoGBAIVj\nw3s3PmF3ZptHq/E8EqovZYvWzGQ8bfa1C+aGuXHSGoAPyHH9c8ndkxBBNNTf++OZ\nGEgCQnBxEgPIBBbs1PR40mCjUkwNnliDrvXpukI537p1bwfgX8IYAXXGPnYdduHU\nwtqvPn04ovb0PqO5Lj0PRinM3iniUDKzwXsLh0eXAoGAS7kOrHTOrMuKamGX3loy\nU40m1RY5hPep+H56j3Y/Xil+EpqwotoBkfaVaZbc55WccltE9PB1KkqZtje1pNMa\nOBGdfo4IWvJe6XdQisMuEtMh7YwCsGB4cTSzQQnQHIrVwNvndq/JXEVwOqjr77Af\nA3a7lL14Je1/R2lzRduVR0Y=\n-----END PRIVATE KEY-----\n",
  "client_email": "gothic@gochonapp-478905.iam.gserviceaccount.com",
  "client_id": "108297263725665812259",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/gothic%40gochonapp-478905.iam.gserviceaccount.com",
  "universe_domain": "googleapis.com"
}
''';

  static GSheets? _noticeGSheets;
  static Worksheet? _noticeWorksheet;
  static const String _noticeSpreadsheetId = '1PuH6M2yL-3A29b3cT9kl3CP7cGVbwGBms5Dhzg3E-AM';
  static const String _noticeWorksheetTitle = '공지사항';

  static Future<void> initializeNoticeService() async {
    try {
      _noticeGSheets = GSheets(_noticeCredentials);
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
