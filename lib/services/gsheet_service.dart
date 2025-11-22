import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notice.dart';

class GSheetService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<List<Notice>> getNotices({int limit = 3}) async {
    try {
      debugPrint('[GSheetService] Fetching notices from Firestore...');
      
      final snapshot = await _firestore
          .collection('notices')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
          
      if (snapshot.docs.isEmpty) {
        debugPrint('[GSheetService] No notices found in Firestore.');
        return [];
      }

      final notices = snapshot.docs.map((doc) {
        final data = doc.data();
        return Notice(
          date: data['date'] as String? ?? '',
          title: data['title'] as String? ?? '',
          content: data['content'] as String? ?? '',
        );
      }).toList();
      
      debugPrint('[GSheetService] Successfully fetched ${notices.length} notices.');
      return notices;

    } catch (e) {
      debugPrint('[GSheetService] Error fetching notices from Firestore: $e');
      throw Exception('공지사항을 불러오는데 실패했습니다: $e');
    }
  }

  static Future<Map<int, int>> getClassCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const cacheKey = 'class_counts_cache';
      const lastUpdateKey = 'class_counts_lastUpdate';
      const cacheExpiry = 6 * 30 * 24 * 60 * 60 * 1000; // 6 months in milliseconds

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
          // Fallback to fetching new data if cached data is malformed
        }
      }

      debugPrint('[GSheetService] Fetching class counts from Firestore...');
      final doc = await _firestore.collection('configs').doc('class_counts').get();

      if (!doc.exists || doc.data() == null) {
        throw Exception("Firestore에서 'configs/class_counts' 문서를 찾을 수 없습니다.");
      }
      
      final data = doc.data()!;
      final counts = {
        1: int.tryParse(data['1']?.toString() ?? '') ?? 11,
        2: int.tryParse(data['2']?.toString() ?? '') ?? 11,
        3: int.tryParse(data['3']?.toString() ?? '') ?? 11,
      };

      // Save to cache
      await prefs.setString(cacheKey, '${counts[1]},${counts[2]},${counts[3]}');
      await prefs.setInt(lastUpdateKey, now);

      debugPrint('[GSheetService] Successfully fetched and cached class counts.');
      return counts;

    } catch (e) {
      debugPrint('[GSheetService] Error fetching class counts: $e');
      // On error, return default values
      return {1: 11, 2: 11, 3: 11};
    }
  }
}