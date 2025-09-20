import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bus_service.dart';
import '../theme_provider.dart';
import '../theme_colors.dart';

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
    
    return Container(
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
    );
  }

  Widget _buildArrivalInfo(BusRoute route) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final textColor = isDark ? AppColors.darkText : Colors.black87;
    final arrivalTimes = _getMockArrivalTimes(route.routeName);
    if (arrivalTimes.isEmpty) {
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
      children: arrivalTimes.map((arrival) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          arrival,
          style: TextStyle(
            fontSize: 14,
            color: textColor,
          ),
        ),
      )).toList(),
    );
  }

  List<String> _getMockArrivalTimes(String routeName) {
    // 임시 도착 시간 데이터
    switch (routeName) {
      case '388':
        return ['7분 39초 4번째전 여유', '도착정보 없음'];
      case '60':
        return ['21분 17번째전 여유', '도착정보 없음'];
      case '60-3':
        return ['25분 14번째전 여유', '54분 34번째전 여유'];
      case '96':
        return ['6분 42초 4번째전 여유', '37분 26번째전 여유'];
      case '1002':
        return ['도착정보 없음'];
      default:
        return ['3분 24초 남음'];
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