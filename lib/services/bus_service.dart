import 'dart:convert';
import 'package:flutter/services.dart';

class BusService {
  
  static List<BusStation>? _cachedStations;

  static Future<List<BusStation>> searchStations(String keyword) async {
    if (keyword.trim().isEmpty) return [];

    // JSON 파일에서 정류장 데이터 로드 (캐싱)
    if (_cachedStations == null) {
      await _loadStationsFromJson();
    }

    // 검색 수행
    final results = _searchInStations(keyword);
    await Future.delayed(const Duration(milliseconds: 300)); // 로딩 시뮬레이션
    return results;
  }

  // JSON 파일에서 정류장 데이터 로드
  static Future<void> _loadStationsFromJson() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/data/kimpo_bus_stations.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      final List<dynamic> stationsData = jsonData['kimpo_bus_stations'];
      
      _cachedStations = stationsData.map((station) => BusStation.fromJson(station)).toList();
      print('JSON에서 ${_cachedStations!.length}개의 정류장 데이터를 로드했습니다.');
    } catch (e) {
      print('JSON 파일 로드 에러: $e');
      _cachedStations = [];
    }
  }

  // 정류장 검색
  static List<BusStation> _searchInStations(String keyword) {
    if (_cachedStations == null) return [];
    
    final lowerKeyword = keyword.toLowerCase();
    final matchedStations = _cachedStations!.where((station) {
      final stationName = station.stationName.toLowerCase();
      return stationName.contains(lowerKeyword) || 
             stationName.replaceAll('•', '').contains(lowerKeyword) ||
             stationName.replaceAll('역', '').contains(lowerKeyword) ||
             stationName.replaceAll('고등학교', '고교').contains(lowerKeyword) ||
             stationName.replaceAll('중학교', '중').contains(lowerKeyword) ||
             stationName.replaceAll('초등학교', '초').contains(lowerKeyword);
    }).toList();

    // 정확히 일치하는 항목을 먼저 정렬
    matchedStations.sort((a, b) {
      final aName = a.stationName.toLowerCase();
      final bName = b.stationName.toLowerCase();
      
      if (aName == lowerKeyword) return -1;
      if (bName == lowerKeyword) return 1;
      if (aName.startsWith(lowerKeyword)) return -1;
      if (bName.startsWith(lowerKeyword)) return 1;
      
      return aName.compareTo(bName);
    });

    return matchedStations;
  }



  static Future<List<BusRoute>> getStationRoutes(String stationId) async {
    // 임시 테스트 데이터
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      BusRoute(
        routeId: '200000001',
        routeName: '1000',
        routeTypeName: '간선버스',
        regionName: '김포시',
      ),
      BusRoute(
        routeId: '200000002',
        routeName: '8000',
        routeTypeName: '광역버스',
        regionName: '경기도',
      ),
      BusRoute(
        routeId: '200000003',
        routeName: '88',
        routeTypeName: '지선버스',
        regionName: '김포시',
      ),
    ];

    /*
    try {
      final url = '$_baseUrl/route?serviceKey=$_serviceKey&stationId=$stationId&format=json';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['response']['body']['items'] != null) {
          final items = data['response']['body']['items']['item'] as List;
          return items.map((item) => BusRoute.fromJson(item)).toList();
        }
      }
      return [];
    } catch (e) {
      print('노선 조회 에러: $e');
      return [];
    }
    */
  }

  static Future<BusStationDetail?> getStationDetail(String stationId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    
    // JSON 파일에서 정류장 데이터 로드 (캐싱)
    if (_cachedStations == null) {
      await _loadStationsFromJson();
    }
    
    // 해당 정류장 찾기
    final station = _cachedStations?.firstWhere(
      (station) => station.stationId == stationId,
      orElse: () => BusStation(stationId: '', stationName: '', stationNum: '', x: 0, y: 0),
    );
    
    if (station != null && station.stationName.isNotEmpty) {
      return BusStationDetail(
        stationId: station.stationId,
        stationName: station.stationName,
        stationNum: station.stationNum,
        x: station.x,
        y: station.y,
        regionName: station.regionName ?? '김포시',
        districtCd: station.district,
      );
    }
    
    return null;
  }
}

class BusStation {
  final String stationId;
  final String stationName;
  final String stationNum;
  final double x;
  final double y;
  final String? centerYn;
  final String? regionName;
  final String? district;
  final String? type;

  BusStation({
    required this.stationId,
    required this.stationName,
    required this.stationNum,
    required this.x,
    required this.y,
    this.centerYn,
    this.regionName,
    this.district,
    this.type,
  });

  factory BusStation.fromJson(Map<String, dynamic> json) {
    // 다양한 필드명에 대응
    final stationId = json['stationId']?.toString() ?? 
                     json['STATION_ID']?.toString() ?? 
                     json['station_id']?.toString() ?? 
                     json['id']?.toString() ?? '';
    
    final stationName = json['stationName']?.toString() ?? 
                       json['STATION_NAME']?.toString() ?? 
                       json['station_name']?.toString() ?? 
                       json['name']?.toString() ?? '';
    
    final stationNum = json['stationNum']?.toString() ?? 
                      json['STATION_NUM']?.toString() ?? 
                      json['station_num']?.toString() ?? 
                      json['stationNo']?.toString() ?? 
                      json['STATION_NO']?.toString() ?? 
                      json['station_no']?.toString() ?? '';
    
    final x = double.tryParse(json['x']?.toString() ?? 
                             json['X']?.toString() ?? 
                             json['longitude']?.toString() ?? 
                             json['LONGITUDE']?.toString() ?? 
                             json['lng']?.toString() ?? '0') ?? 0.0;
    
    final y = double.tryParse(json['y']?.toString() ?? 
                             json['Y']?.toString() ?? 
                             json['latitude']?.toString() ?? 
                             json['LATITUDE']?.toString() ?? 
                             json['lat']?.toString() ?? '0') ?? 0.0;
    
    final centerYn = json['centerYn']?.toString() ?? 
                    json['CENTER_YN']?.toString() ?? 
                    json['center_yn']?.toString();
    
    final regionName = json['regionName']?.toString() ?? 
                      json['REGION_NAME']?.toString() ?? 
                      json['region_name']?.toString();
    
    final district = json['district']?.toString() ?? 
                    json['DISTRICT']?.toString() ?? 
                    json['districtCd']?.toString();
    
    final type = json['type']?.toString() ?? 
                json['TYPE']?.toString() ?? 
                json['station_type']?.toString();

    return BusStation(
      stationId: stationId,
      stationName: stationName,
      stationNum: stationNum,
      x: x,
      y: y,
      centerYn: centerYn,
      regionName: regionName,
      district: district,
      type: type,
    );
  }
}

class BusRoute {
  final String routeId;
  final String routeName;
  final String routeTypeName;
  final String regionName;

  BusRoute({
    required this.routeId,
    required this.routeName,
    required this.routeTypeName,
    required this.regionName,
  });

  factory BusRoute.fromJson(Map<String, dynamic> json) {
    return BusRoute(
      routeId: json['routeId']?.toString() ?? '',
      routeName: json['routeName']?.toString() ?? '',
      routeTypeName: json['routeTypeName']?.toString() ?? '',
      regionName: json['regionName']?.toString() ?? '',
    );
  }
}

class BusStationDetail {
  final String stationId;
  final String stationName;
  final String stationNum;
  final double x;
  final double y;
  final String? centerYn;
  final String? districtCd;
  final String? mobileNo;
  final String? regionName;

  BusStationDetail({
    required this.stationId,
    required this.stationName,
    required this.stationNum,
    required this.x,
    required this.y,
    this.centerYn,
    this.districtCd,
    this.mobileNo,
    this.regionName,
  });

  factory BusStationDetail.fromJson(Map<String, dynamic> json) {
    return BusStationDetail(
      stationId: json['stationId']?.toString() ?? '',
      stationName: json['stationName']?.toString() ?? '',
      stationNum: json['stationNum']?.toString() ?? '',
      x: double.tryParse(json['x']?.toString() ?? '0') ?? 0.0,
      y: double.tryParse(json['y']?.toString() ?? '0') ?? 0.0,
      centerYn: json['centerYn']?.toString(),
      districtCd: json['districtCd']?.toString(),
      mobileNo: json['mobileNo']?.toString(),
      regionName: json['regionName']?.toString(),
    );
  }
}
