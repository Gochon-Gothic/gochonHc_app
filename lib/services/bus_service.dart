import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class BusService {
  static const String _baseUrl = 'https://apis.data.go.kr/6410000/busstationservice';
  static const String _arrivalBaseUrl = 'https://apis.data.go.kr/6410000/busarrivalservice';
  static const String _serviceKey = '5603d0071b09c37c4dc6aeb25a4d08e409b4ddc2f2791e15bc113cddf228e540';
  
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
      final String jsonString = await rootBundle.loadString('assets/data/gimpo_bus.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      final List<dynamic> stationsData = jsonData['stations'];
      
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
    // 정확한 API 엔드포인트 사용
    final apiEndpoints = [
      'getBusStationViaRouteListv2',
    ];
    
    for (String endpoint in apiEndpoints) {
      try {
        final url = '$_baseUrl/v2/$endpoint?serviceKey=$_serviceKey&stationId=$stationId&format=json';
        
        print('API 호출 시도: $url');
        print('정류소 ID: $stationId');
        
        final response = await http.get(Uri.parse(url));
        
        print('응답 상태 코드: ${response.statusCode}');
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          
          // 응답 구조 확인
          print('응답 구조: ${data.keys}');
          
          if (data['response'] != null && data['response']['msgHeader'] != null) {
            if (data['response']['msgHeader']['resultCode'] == 0) {
              final msgBody = data['response']['msgBody'];
              if (msgBody != null && msgBody['busRouteList'] != null) {
                final busRouteList = msgBody['busRouteList'];
                
                // busRouteList가 배열인지 객체인지 확인
                if (busRouteList is List) {
                  print('성공! 조회된 버스 노선 수: ${busRouteList.length}');
                  return busRouteList.map((route) => BusRoute.fromJson(Map<String, dynamic>.from(route))).toList();
                } else if (busRouteList is Map) {
                  print('성공! 단일 버스 노선 조회');
                  return [BusRoute.fromJson(Map<String, dynamic>.from(busRouteList))];
                }
              } else {
                print('버스 노선 데이터가 없습니다.');
                return [];
              }
            } else {
              print('API 오류: ${data['response']['msgHeader']['resultMessage']}');
            }
          } else {
            print('예상치 못한 응답 구조: ${response.body}');
          }
        } else {
          print('HTTP 오류: ${response.statusCode}');
          print('응답 본문: ${response.body}');
        }
      } catch (e) {
        print('API 엔드포인트 $endpoint 실패: $e');
      }
    }
    
    print('모든 API 엔드포인트 시도 실패');
    return [];
  }

  static Future<List<BusArrival>> getBusArrivals(String stationId) async {
    try {
      final url = '$_arrivalBaseUrl/v2/getBusArrivalListv2?serviceKey=$_serviceKey&stationId=$stationId&format=json';
      
      print('버스 도착 정보 API 호출: $url');
      print('정류소 ID: $stationId');
      
      final response = await http.get(Uri.parse(url));
      
      print('도착 정보 응답 상태 코드: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        print('도착 정보 응답 구조: ${data.keys}');
        print('응답 본문: ${response.body}');
        
        // 응답 구조 확인 및 파싱
        if (data['response'] != null) {
          final responseData = data['response'];
          if (responseData['msgHeader'] != null && responseData['msgHeader']['resultCode'] == 0) {
            final msgBody = responseData['msgBody'];
            if (msgBody != null && msgBody['busArrivalList'] != null) {
              final arrivalList = msgBody['busArrivalList'];
              
              if (arrivalList is List) {
                print('성공! 조회된 도착 정보 수: ${arrivalList.length}');
                return arrivalList.map((arrival) => BusArrival.fromJson(Map<String, dynamic>.from(arrival))).toList();
              } else if (arrivalList is Map) {
                print('성공! 단일 도착 정보 조회');
                return [BusArrival.fromJson(Map<String, dynamic>.from(arrivalList))];
              }
            } else {
              print('도착 정보 데이터가 없습니다.');
              return [];
            }
          } else {
            print('도착 정보 API 오류: ${responseData['msgHeader']?['resultMessage'] ?? '알 수 없는 오류'}');
            return [];
          }
        } else if (data['msgHeader'] != null && data['msgHeader']['resultCode'] == 0) {
          // 직접 msgHeader가 있는 경우
          final msgBody = data['msgBody'];
          if (msgBody != null && msgBody['busArrivalList'] != null) {
            final arrivalList = msgBody['busArrivalList'];
            
            if (arrivalList is List) {
              print('성공! 조회된 도착 정보 수: ${arrivalList.length}');
              return arrivalList.map((arrival) => BusArrival.fromJson(Map<String, dynamic>.from(arrival))).toList();
            } else if (arrivalList is Map) {
              print('성공! 단일 도착 정보 조회');
              return [BusArrival.fromJson(Map<String, dynamic>.from(arrivalList))];
            }
          } else {
            print('도착 정보 데이터가 없습니다.');
            return [];
          }
        } else {
          print('예상치 못한 응답 구조: ${response.body}');
          return [];
        }
      } else {
        print('도착 정보 HTTP 오류: ${response.statusCode}');
        print('응답 본문: ${response.body}');
        return [];
      }
    } catch (e) {
      print('버스 도착 정보 조회 에러: $e');
      return [];
    }
    return []; // 명시적 반환
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
    final stationId = json['stationId']?.toString() ?? '';
    final stationName = json['stationName']?.toString() ?? '';
    final stationNum = json['stationNum']?.toString() ?? '';
    final x = double.tryParse(json['longitude']?.toString() ?? '0') ?? 0.0;
    final y = double.tryParse(json['latitude']?.toString() ?? '0') ?? 0.0;
    final regionName = json['regionName']?.toString() ?? '김포시';
    final stationType = json['stationType']?.toString() ?? '';
    final stationTypeName = json['stationTypeName']?.toString() ?? '';

    return BusStation(
      stationId: stationId,
      stationName: stationName,
      stationNum: stationNum,
      x: x,
      y: y,
      centerYn: null,
      regionName: regionName,
      district: null,
      type: stationTypeName.isNotEmpty ? stationTypeName : stationType,
      nextStations: null,
    );
  }
}

class BusRoute {
  final String routeId;
  final String routeName;
  final String routeTypeName;
  final String regionName;
  final String routeDestName;
  final int routeDestId;
  final int routeTypeCd;
  final int staOrder;

  BusRoute({
    required this.routeId,
    required this.routeName,
    required this.routeTypeName,
    required this.regionName,
    required this.routeDestName,
    required this.routeDestId,
    required this.routeTypeCd,
    required this.staOrder,
  });

  factory BusRoute.fromJson(Map<String, dynamic> json) {
    return BusRoute(
      routeId: json['routeId']?.toString() ?? '',
      routeName: json['routeName']?.toString() ?? '',
      routeTypeName: json['routeTypeName']?.toString() ?? '',
      regionName: json['regionName']?.toString() ?? '',
      routeDestName: json['routeDestName']?.toString() ?? '',
      routeDestId: json['routeDestId'] ?? 0,
      routeTypeCd: json['routeTypeCd'] ?? 0,
      staOrder: json['staOrder'] ?? 0,
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

class BusArrival {
  final String routeId;
  final String routeName;
  final String routeTypeName;
  final int predictTime1;
  final int predictTime2;
  final int locationNo1;
  final int locationNo2;
  final String plateNo1;
  final String plateNo2;
  final int stateCd1;
  final int stateCd2;
  final int crowded1;
  final int crowded2;
  final int lowPlate1;
  final int lowPlate2;
  final String flag;

  BusArrival({
    required this.routeId,
    required this.routeName,
    required this.routeTypeName,
    required this.predictTime1,
    required this.predictTime2,
    required this.locationNo1,
    required this.locationNo2,
    required this.plateNo1,
    required this.plateNo2,
    required this.stateCd1,
    required this.stateCd2,
    required this.crowded1,
    required this.crowded2,
    required this.lowPlate1,
    required this.lowPlate2,
    required this.flag,
  });

  factory BusArrival.fromJson(Map<String, dynamic> json) {
    return BusArrival(
      routeId: json['routeId']?.toString() ?? '',
      routeName: json['routeName']?.toString() ?? '',
      routeTypeName: json['routeTypeName']?.toString() ?? '',
      predictTime1: int.tryParse(json['predictTime1']?.toString() ?? '0') ?? 0,
      predictTime2: int.tryParse(json['predictTime2']?.toString() ?? '0') ?? 0,
      locationNo1: int.tryParse(json['locationNo1']?.toString() ?? '0') ?? 0,
      locationNo2: int.tryParse(json['locationNo2']?.toString() ?? '0') ?? 0,
      plateNo1: json['plateNo1']?.toString() ?? '',
      plateNo2: json['plateNo2']?.toString() ?? '',
      stateCd1: int.tryParse(json['stateCd1']?.toString() ?? '0') ?? 0,
      stateCd2: int.tryParse(json['stateCd2']?.toString() ?? '0') ?? 0,
      crowded1: int.tryParse(json['crowded1']?.toString() ?? '0') ?? 0,
      crowded2: int.tryParse(json['crowded2']?.toString() ?? '0') ?? 0,
      lowPlate1: int.tryParse(json['lowPlate1']?.toString() ?? '0') ?? 0,
      lowPlate2: int.tryParse(json['lowPlate2']?.toString() ?? '0') ?? 0,
      flag: json['flag']?.toString() ?? '',
    );
  }

  String get arrivalTime1 {
    if (predictTime1 <= 0) return '도착정보 없음';
    if (predictTime1 < 60) return '${predictTime1}분 후';
    final hours = predictTime1 ~/ 60;
    final minutes = predictTime1 % 60;
    if (hours > 0) {
      return '${hours}시간 ${minutes}분 후';
    } else {
      return '${minutes}분 후';
    }
  }

  String get arrivalTime2 {
    if (predictTime2 <= 0) return '도착정보 없음';
    if (predictTime2 < 60) return '${predictTime2}분 후';
    final hours = predictTime2 ~/ 60;
    final minutes = predictTime2 % 60;
    if (hours > 0) {
      return '${hours}시간 ${minutes}분 후';
    } else {
      return '${minutes}분 후';
    }
  }

  String get crowdedText1 {
    switch (crowded1) {
      case 1: return '여유';
      case 2: return '보통';
      case 3: return '혼잡';
      default: return '정보없음';
    }
  }

  String get crowdedText2 {
    switch (crowded2) {
      case 1: return '여유';
      case 2: return '보통';
      case 3: return '혼잡';
      default: return '정보없음';
    }
  }

  bool get isLowPlate1 => lowPlate1 == 1;
  bool get isLowPlate2 => lowPlate2 == 1;
}
