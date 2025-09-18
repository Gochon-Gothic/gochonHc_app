import 'package:gsheets/gsheets.dart';

class GSheetService {
  static const String _spreadsheetId =
      '1Q45kRO9R_SUZoLvB78MZrbTUWnWTU-3MLL5Pfh8RZz4';
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
      } catch (e) {
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
        final headers = ['이메일', '이름', '학년', '반', '번호', '가입일시', '약관동의'];
        await _worksheet!.values.insertRow(1, headers);
      }
    } catch (e) {
    }
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
      if (_worksheet == null) {
        await initialize();
      }

      final now = DateTime.now();
      final formattedDate =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

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
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, String>?> getUserInfo(String email) async {
    try {
      if (_worksheet == null) {
        await initialize();
      }

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
    } catch (e) {
      return null;
    }
  }

}
