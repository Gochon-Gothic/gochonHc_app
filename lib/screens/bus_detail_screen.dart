import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bus_service.dart';
import '../theme_provider.dart';
import '../theme_colors.dart';
import 'bus_route_detail_screen.dart';

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
  List<BusArrival> arrivals = [];
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
      final arrivalsData = await BusService.getBusArrivals(widget.station.stationId);
      final detailData = await BusService.getStationDetail(widget.station.stationId);

      if (mounted) {
        setState(() {
          routes = routesData;
          arrivals = arrivalsData;
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

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final bgColor = isDark ? AppColors.darkBackground : const Color.fromARGB(255, 240, 240, 240);

    return Scaffold(
      backgroundColor: bgColor,
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
                        style: const TextStyle(
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
              : Column(
                  children: [
                    // 상단 역 정보 패널
                    _buildTopStationPanel(),
                    const SizedBox(height: 15),
                    Expanded(
                      child: _buildBusList(),
                    ),
                    // 하단 역 정보 패널
                    _buildBottomStationPanel(),
                  ],
                ),
    );
  }
  Widget _buildTopStationPanel() {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final direction = widget.station.getDirectionFromCoordinate(BusService.getCachedStations());
    final panelColor = isDark ? AppColors.darkCard : const Color.fromARGB(255, 204, 204, 204);
    final textColor = isDark ? AppColors.darkText : Colors.black87;
    final subTextColor = isDark ? AppColors.darkText.withOpacity(0.7) : Colors.black54;
    
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: 20,
        right: 20,
        bottom: 10,
      ),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: const BorderRadius.only(
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
                    child: Icon(
                      Icons.arrow_back_ios,
                      color: textColor,
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
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      if (direction.isNotEmpty) ...[
                        Text(
                          '$direction 방면',
                          style: TextStyle(
                            fontSize: 18,
                            color: subTextColor,
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
    );
  }

  Widget _buildBusList() {
    if (routes.isEmpty) {
      return const Center(
        child: Text(
          '경유하는 버스가 없습니다',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 16,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      itemCount: routes.length,
      itemBuilder: (context, index) {
        final route = routes[index];
        return _buildBusItem(route);
      },
    );
  }

  Widget _buildBusItem(BusRoute route) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BusRouteDetailScreen(
              route: route,
              currentStation: widget.station,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(isDark ? 0.3 : 0.1),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${route.routeName}번',
                  style: TextStyle(
                    color: _getRouteTypeColor(route.routeTypeName),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '→ ${route.routeDestName}',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const Spacer(),
                // 알림 버튼
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${route.routeName}번 버스 알림 설정 (구현 예정)'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Icon(
                    Icons.notifications_outlined,
                    color: isDark ? Colors.grey[400] : Colors.grey,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            // 도착 정보 (임시 데이터)
            _buildArrivalInfo(route),
          ],
        ),
      ),
    );
  }

  Widget _buildArrivalInfo(BusRoute route) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final textColor = isDark ? AppColors.darkText : Colors.black87;
    
    // 해당 노선의 도착 정보 찾기
    final arrival = arrivals.firstWhere(
      (arrival) => arrival.routeId == route.routeId,
      orElse: () => BusArrival(
        routeId: '',
        routeName: '',
        routeTypeName: '',
        predictTime1: 0,
        predictTime2: 0,
        locationNo1: 0,
        locationNo2: 0,
        plateNo1: '',
        plateNo2: '',
        stateCd1: 0,
        stateCd2: 0,
        crowded1: 0,
        crowded2: 0,
        lowPlate1: 0,
        lowPlate2: 0,
        flag: '',
      ),
    );

    if (arrival.routeId.isEmpty) {
      return Text(
        '도착정보 없음',
        style: TextStyle(
          fontSize: 14,
          color: isDark ? Colors.grey[400] : Colors.grey,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 첫 번째 버스
        Row(
          children: [
            Text(
              arrival.arrivalTime1,
              style: TextStyle(
                fontSize: 14,
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (arrival.predictTime1 > 0) ...[
              const SizedBox(width: 8),
              Text(
                arrival.crowdedText1,
                style: TextStyle(
                  fontSize: 12,
                  color: _getCrowdedColor(arrival.crowded1),
                ),
              ),
              if (arrival.isLowPlate1) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.accessible,
                  size: 12,
                  color: Colors.blue,
                ),
              ],
            ],
          ],
        ),
        // 두 번째 버스
        if (arrival.predictTime2 > 0) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                arrival.arrivalTime2,
                style: TextStyle(
                  fontSize: 14,
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                arrival.crowdedText2,
                style: TextStyle(
                  fontSize: 12,
                  color: _getCrowdedColor(arrival.crowded2),
                ),
              ),
              if (arrival.isLowPlate2) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.accessible,
                  size: 12,
                  color: Colors.blue,
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Color _getCrowdedColor(int crowded) {
    switch (crowded) {
      case 1: return Colors.green; // 여유
      case 2: return Colors.orange; // 보통
      case 3: return Colors.red; // 혼잡
      default: return Colors.grey; // 정보없음
    }
  }

  Widget _buildBottomStationPanel() {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final panelColor = isDark ? AppColors.darkCard : Colors.grey[300];
    final textColor = isDark ? AppColors.darkText : Colors.black87;
    final subTextColor = isDark ? AppColors.darkText.withOpacity(0.7) : Colors.black54;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 30,left: 15,right: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.station.baseStationName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.station.getDirectionFromCoordinate(BusService.getCachedStations()).isNotEmpty ? widget.station.getDirectionFromCoordinate(BusService.getCachedStations()) : "김포시"} 방면',
                  style: TextStyle(
                    fontSize: 14,
                    color: subTextColor,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _loadStationInfo,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.refresh,
                color: isDark ? Colors.grey[400] : Colors.grey,
                size: 20,
              ),
            ),
          ),
        ],
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
        return Colors.teal; // 기본 색상
    }
  }
}