import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class BusService {
  static const String _baseUrl = 'https://apis.data.go.kr/6410000/busstationservice';
  static const String _serviceKey = 'xNfTevHwBe6YPksD2WbyNYeA7i35nK8xfiqOxBenRauQdNk0YQ3JPdxeTXAGWUwaizao2fNCbOsAvYsG+XRHYw==';
  
  static List<BusStation>? _cachedStations;

  static Future<List<BusStation>> searchStations(String keyword) async {
    if (keyword.trim().isEmpty) return [];

    if (_cachedStations == null) {
      await _loadStationsFromJson();
    }

    final results = _searchInStations(keyword);
    await Future.delayed(const Duration(milliseconds: 300));
    return results;
  }

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

  static List<BusStation> _searchInStations(String keyword) {
    if (_cachedStations == null) return [];
    
    final lowerKeyword = keyword.toLowerCase();
    final matchedStations = _cachedStations!.where((station) {
      final stationName = station.stationName.toLowerCase();
      final stationNum = station.stationNum.toLowerCase();
      final stationId = station.stationId.toLowerCase();
      final district = station.district?.toLowerCase() ?? '';
      
      bool nameMatch = stationName.contains(lowerKeyword) || 
                      stationName.replaceAll('•', '').contains(lowerKeyword) ||
                      stationName.replaceAll('역', '').contains(lowerKeyword) ||
                      stationName.replaceAll('고등학교', '고교').contains(lowerKeyword) ||
                      stationName.replaceAll('중학교', '중').contains(lowerKeyword) ||
                      stationName.replaceAll('초등학교', '초').contains(lowerKeyword) ||
                      stationName.replaceAll('행정복지센터', '주민센터').contains(lowerKeyword);
      
      bool codeMatch = stationNum.contains(lowerKeyword) || 
                      stationId.contains(lowerKeyword);
      
      bool districtMatch = district.contains(lowerKeyword);
      
      return nameMatch || codeMatch || districtMatch;
    }).toList();

    matchedStations.sort((a, b) {
      final aName = a.stationName.toLowerCase();
      final bName = b.stationName.toLowerCase();
      final aCode = a.stationNum.toLowerCase();
      final bCode = b.stationNum.toLowerCase();
      
      if (aCode == lowerKeyword) return -1;
      if (bCode == lowerKeyword) return 1;
      
      if (aName == lowerKeyword) return -1;
      if (bName == lowerKeyword) return 1;
      
      if (aName.startsWith(lowerKeyword)) return -1;
      if (bName.startsWith(lowerKeyword)) return 1;
      
      if (a.type == '지하철역' && b.type != '지하철역') return -1;
      if (b.type == '지하철역' && a.type != '지하철역') return 1;
      
      return aName.compareTo(bName);
    });

    return matchedStations;
  }

  static List<BusStation> getCachedStations() {
    return _cachedStations ?? [];
  }



  static Future<List<BusRoute>> getStationRoutes(String stationId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      BusRoute(
        routeId: '200000001',
        routeName: '388',
        routeTypeName: '간선버스',
        regionName: '김포시',
      ),
      BusRoute(
        routeId: '200000002',
        routeName: '60',
        routeTypeName: '간선버스',
        regionName: '김포시',
      ),
      BusRoute(
        routeId: '200000003',
        routeName: '60-3',
        routeTypeName: '지선버스',
        regionName: '김포시',
      ),
      BusRoute(
        routeId: '200000004',
        routeName: '96',
        routeTypeName: '지선버스',
        regionName: '김포시',
      ),
      BusRoute(
        routeId: '200000005',
        routeName: '1002',
        routeTypeName: '광역버스',
        regionName: '경기도',
      ),
    ];
  }

  static Future<BusStationDetail?> getStationDetail(String stationId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    
    if (_cachedStations == null) {
      await _loadStationsFromJson();
    }
    
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

  static Future<List<NextStation>> getNextStations(String stationId) async {
    try {
      final routes = await getStationRoutes(stationId);
      List<NextStation> nextStations = [];
      
      for (BusRoute route in routes) {
        final nextStation = await _getNextStationForRoute(stationId, route.routeId);
        if (nextStation != null) {
          nextStations.add(nextStation);
        }
      }
      
      return nextStations;
    } catch (e) {
      print('다음역 조회 에러: $e');
      return [];
    }
  }

  static Future<NextStation?> _getNextStationForRoute(String stationId, String routeId) async {
    try {
      final url = '$_baseUrl/getBusStationViaRouteList?serviceKey=$_serviceKey&routeId=$routeId&format=json';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['response']['body']['items'] != null) {
          final items = data['response']['body']['items']['item'] as List;
          
          int currentIndex = -1;
          for (int i = 0; i < items.length; i++) {
            if (items[i]['stationId']?.toString() == stationId) {
              currentIndex = i;
              break;
            }
          }
          
          if (currentIndex >= 0 && currentIndex < items.length - 1) {
            final nextItem = items[currentIndex + 1];
            return NextStation(
              stationName: nextItem['stationName']?.toString() ?? '',
              routeName: '',
              direction: '',
            );
          }
        }
      }
    } catch (e) {
      print('노선별 다음역 조회 에러: $e');
    }
    
    return null;
  }

  static String estimateDirection(BusStation station1, BusStation station2) {
    final double latDiff = station2.y - station1.y;
    final double lngDiff = station2.x - station1.x;
    
    if (latDiff.abs() > lngDiff.abs()) {
      return latDiff > 0 ? '북쪽 방향' : '남쪽 방향';
    } else {
      return lngDiff > 0 ? '동쪽 방향' : '서쪽 방향';
    }
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
  final List<NextStationInfo>? nextStations;

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
    this.nextStations,
  });

  String get direction {
    final name = stationName;
    
    if (name.contains('(서울)')) return '서울 방향';
    if (name.contains('(강화)')) return '강화 방향';
    if (name.contains('(김포)')) return '김포 방향';
    if (name.contains('(시청)')) return '시청 방향';
    if (name.contains('(완행)')) return '완행';
    
    final RegExp directionPattern = RegExp(r'\(([^)]+방향)\)');
    final match = directionPattern.firstMatch(name);
    if (match != null) {
      return match.group(1) ?? '';
    }
    
    return '';
  }

  String get baseStationName {
    String name = stationName;
    name = name.replaceAll(RegExp(r'\([^)]*\)'), '').trim();
    return name;
  }

  String get displayName {
    final base = baseStationName;
    final dir = direction;
    
    if (dir.isNotEmpty) {
      return '$base ($dir)';
    }
    return base;
  }

  String getDirectionFromCoordinate(List<BusStation> allStations) {
    if (direction.isNotEmpty) return direction;
    
    if (nextStations != null && nextStations!.isNotEmpty) {
      final directions = nextStations!.map((next) => 
        '${next.direction}: ${next.nextStationName}'
      ).join(' | ');
      return directions;
    }
    
    final sameNameStations = allStations.where((station) => 
      station.baseStationName == baseStationName && 
      station.stationId != stationId
    ).toList();
    
    if (sameNameStations.isEmpty) return '';
    
    final nearest = sameNameStations.reduce((curr, next) => 
      _getDistance(this, curr) < _getDistance(this, next) ? curr : next
    );
    
    return _estimateDirectionFromCoordinates(this, nearest);
  }

  static double _getDistance(BusStation station1, BusStation station2) {
    final dx = station1.x - station2.x;
    final dy = station1.y - station2.y;
    return dx * dx + dy * dy;
  }

  static String _estimateDirectionFromCoordinates(BusStation from, BusStation to) {
    final double latDiff = to.y - from.y;
    final double lngDiff = to.x - from.x;
    
    if (latDiff.abs() > lngDiff.abs()) {
      if (latDiff > 0) {
        return '북쪽 방향 (사우/월곶)';
      } else {
        return '남쪽 방향 (김포공항/마송)';
      }
    } else {
      if (lngDiff > 0) {
        return '동쪽 방향 (고촌/장기)';
      } else {
        return '서쪽 방향 (대곶/유현)';
      }
    }
  }

  factory BusStation.fromJson(Map<String, dynamic> json) {
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
    
    List<NextStationInfo>? nextStations;
    if (json['nextStations'] != null) {
      final nextStationsJson = json['nextStations'] as List;
      nextStations = nextStationsJson.map((item) => NextStationInfo.fromJson(item)).toList();
    }

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
      nextStations: nextStations,
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

class NextStation {
  final String stationName;
  final String routeName;
  final String direction;

  NextStation({
    required this.stationName,
    required this.routeName,
    required this.direction,
  });
}

class NextStationInfo {
  final String direction;
  final String nextStationName;
  final String nextStationId;

  NextStationInfo({
    required this.direction,
    required this.nextStationName,
    required this.nextStationId,
  });

  factory NextStationInfo.fromJson(Map<String, dynamic> json) {
    return NextStationInfo(
      direction: json['direction']?.toString() ?? '',
      nextStationName: json['nextStationName']?.toString() ?? '',
      nextStationId: json['nextStationId']?.toString() ?? '',
    );
  }
}
