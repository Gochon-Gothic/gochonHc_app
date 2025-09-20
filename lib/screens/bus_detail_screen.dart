import 'package:flutter/material.dart';
import '../services/bus_service.dart';

class BusDetailScreen extends StatefulWidget {
  final BusStation station;

  const BusDetailScreen({
    super.key,
    required this.station,
  });

  @override
  State<BusDetailScreen> createState() => _BusDetailScreenState();
}

class _BusDetailScreenState extends State<BusDetailScreen> {
  List<BusRoute> routes = [];
  BusStationDetail? stationDetail;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadStationInfo();
  }

  Future<void> _loadStationInfo() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final routesData = await BusService.getStationRoutes(widget.station.stationId);
      final detailData = await BusService.getStationDetail(widget.station.stationId);

      if (mounted) {
        setState(() {
          routes = routesData;
          stationDetail = detailData;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '정류장 정보를 불러오는데 실패했습니다.';
          isLoading = false;
        });
      }
    }
  }

  void _navigateToRouteDetail(BusRoute route) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${route.routeName}번 버스 상세 정보 (구현 예정)'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 204, 204, 204),
      extendBodyBehindAppBar: true,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        error!,
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadStationInfo,
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    // 지도 배경 (현재는 플레이스홀더)
                    _buildMapBackground(),
                    
                    // 상단 역 정보 패널
                    _buildTopStationPanel(),
                    
                    // 하단 버스 도착 정보 패널
                    _buildBottomSchedulePanel(),
                  ],
                ),
    );
  }

  Widget _buildMapBackground() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.grey[900]!,
            Colors.black,
            Colors.grey[800]!,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.map_outlined,
              size: 80,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              '지도 API 연동 예정',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopStationPanel() {
    final direction = widget.station.getDirectionFromCoordinate(BusService.getCachedStations());
    
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top ,
          left: 20,
          right: 20,
          bottom: 10,
        ),
        decoration: const BoxDecoration(
          color: Color.fromARGB(255, 204, 204, 204),
          borderRadius: BorderRadius.only(
            bottomRight: Radius.circular(33),
            bottomLeft: Radius.circular(33),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 뒤로가기 버튼과 역 정보
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.black87,
                      size: 25,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.station.baseStationName,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      if (direction.isNotEmpty) ...[
                        Text(
                          '$direction 방면',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Color.fromARGB(255, 0, 0, 0),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSchedulePanel() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 204, 204, 204),
          borderRadius: BorderRadius.circular(35),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              " ${widget.station.baseStationName}",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            
            // 버스 도착 정보
            if (routes.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    '경유하는 버스가 없습니다',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ),
              )
            else
              ...routes.map((route) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _navigateToRouteDetail(route),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          child: Row(
                            children: [
                              // 버스 번호
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                                decoration: BoxDecoration(
                                  color: _getRouteTypeColor(route.routeTypeName),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${route.routeName}번',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),                  
                              // 도착 시간 (임시 데이터)
                              Text(
                                '3분 24초 남음',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Color _getRouteTypeColor(String routeType) {
    switch (routeType) {
      case '간선버스':
        return Colors.blue;
      case '지선버스':
        return Colors.green;
      case '순환버스':
        return Colors.orange;
      case '광역버스':
        return Colors.red;
      case '마을버스':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
