import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notice.dart';

class GSheetService {
  // Google Apps Script 웹 앱 URL
  static const String _serviceUrl =
      'https://script.google.com/macros/s/AKfycbxMZBeV9vgKkqB-49Xz4Z0MGmCU95d6q3UB1e-gAdLlJvNdGVI_aCdExz_c5GO7itw/exec';

  static Future<List<Notice>> getNotices({int limit = 3}) async {
    final prefs = await SharedPreferences.getInstance();
    const cacheKey = 'notices_cache';
    const lastUpdateKey = 'notices_last_update';
    const cacheExpiry = 15 * 60 * 1000; // 15분 (밀리초)

    final cachedData = prefs.getString(cacheKey);
    final lastUpdate = prefs.getInt(lastUpdateKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

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
}
