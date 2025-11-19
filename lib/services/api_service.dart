import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../utils/preference_manager.dart';

class ApiService {
  static ApiService? _instance;
  static Dio? _dio;

  static ApiService get instance {
    _instance ??= ApiService._internal();
    return _instance!;
  }

  ApiService._internal() {
    _initializeDio();
  }

  void _initializeDio() {
    _dio = Dio(
      BaseOptions(
        baseUrl: 'https://open.neis.go.kr/hub/',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 10),
      ),
    );

    _dio!.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final cacheKey = _generateCacheKey(
            options.path,
            options.queryParameters,
          );
          final cachedData =
              await PreferenceManager.instance.getTimetableCache();

          if (cachedData != null && cachedData.containsKey(cacheKey)) {
            handler.resolve(
              Response(
                data: cachedData[cacheKey],
                statusCode: 200,
                requestOptions: options,
              ),
            );
            return;
          }

          handler.next(options);
        },
        onResponse: (response, handler) async {
          if (response.statusCode == 200) {
            final cacheKey = _generateCacheKey(
              response.requestOptions.path,
              response.requestOptions.queryParameters,
            );

            final cacheData =
                await PreferenceManager.instance.getTimetableCache() ?? {};
            cacheData[cacheKey] = response.data;
            await PreferenceManager.instance.setTimetableCache(cacheData);
          }

          handler.next(response);
        },
        onError: (error, handler) async {
          if (error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout) {
            final cacheKey = _generateCacheKey(
              error.requestOptions.path,
              error.requestOptions.queryParameters,
            );

            final cachedData =
                await PreferenceManager.instance.getTimetableCache();
            if (cachedData != null && cachedData.containsKey(cacheKey)) {
              handler.resolve(
                Response(
                  data: cachedData[cacheKey],
                  statusCode: 200,
                  requestOptions: error.requestOptions,
                ),
              );
              return;
            }
          }

          handler.next(error);
        },
      ),
    );
  }

  String _generateCacheKey(String path, Map<String, dynamic>? queryParams) {
    final params =
        queryParams?.entries.map((e) => '${e.key}=${e.value}').join('&') ?? '';
    return '$path?$params';
  }

  Future<Response> getTimetable({
    required String apiKey,
    required String eduOfficeCode,
    required String schoolCode,
    required String grade,
    required String classNum,
    required String fromDate,
    required String toDate,
  }) async {
    try {
      final response = await _dio!.get(
        'hisTimetable',
        queryParameters: {
          'KEY': apiKey,
          'Type': 'json',
          'ATPT_OFCDC_SC_CODE': eduOfficeCode,
          'SD_SCHUL_CODE': schoolCode,
          'GRADE': grade,
          'CLASS_NM': classNum,
          'TI_FROM_YMD': fromDate,
          'TI_TO_YMD': toDate,
        },
      );

      return response;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Timetable API Error: ${e.message}');
      }
      rethrow;
    }
  }

  Future<Response> getMeal({
    required String apiKey,
    required String eduOfficeCode,
    required String schoolCode,
    required String fromDate,
    required String toDate,
  }) async {
    try {
      final response = await _dio!.get(
        'mealServiceDietInfo',
        queryParameters: {
          'KEY': apiKey,
          'Type': 'json',
          'ATPT_OFCDC_SC_CODE': eduOfficeCode,
          'SD_SCHUL_CODE': schoolCode,
          'MLSV_FROM_YMD': fromDate,
          'MLSV_TO_YMD': toDate,
        },
      );

      return response;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Meal API Error: ${e.message}');
      }
      rethrow;
    }
  }

  Future<Response> getSchoolSchedule({
    required String apiKey,
    required String eduOfficeCode,
    required String schoolCode,
    required String fromDate,
    required String toDate,
  }) async {
    try {
      final response = await _dio!.get(
        'SchoolSchedule',
        queryParameters: {
          'KEY': apiKey,
          'Type': 'json',
          'pIndex': 1,
          'pSize': 365,
          'ATPT_OFCDC_SC_CODE': eduOfficeCode,
          'SD_SCHUL_CODE': schoolCode,
          'AA_FROM_YMD': fromDate,
          'AA_TO_YMD': toDate,
        },
      );

      return response;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('School Schedule API Error: ${e.message}');
      }
      rethrow;
    }
  }

  Future<List<Response>> getBatchTimetables({
    required String apiKey,
    required String eduOfficeCode,
    required String schoolCode,
    required String grade,
    required String classNum,
    required List<Map<String, String>> dateRanges,
  }) async {
    try {
      final futures = dateRanges.map(
        (dateRange) => getTimetable(
          apiKey: apiKey,
          eduOfficeCode: eduOfficeCode,
          schoolCode: schoolCode,
          grade: grade,
          classNum: classNum,
          fromDate: dateRange['from']!,
          toDate: dateRange['to']!,
        ),
      );

      final responses = await Future.wait(futures);
      return responses;
    } catch (e) {
      if (kDebugMode) {
        print('Batch Timetable API Error: $e');
      }
      rethrow;
    }
  }
}
