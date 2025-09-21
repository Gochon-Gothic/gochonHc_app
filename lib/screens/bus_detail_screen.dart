import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bus_service.dart';
import '../theme_provider.dart';
import '../theme_colors.dart';
import '../utils/preference_manager.dart';
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
  bool isFavorite = false;
  bool favoriteChanged = false;

  @override
  void initState() {
    super.initState();
    _loadStationInfo();
    _checkFavoriteStatus();
  }

  Future<void> _checkFavoriteStatus() async {
    final favoriteStatus = await PreferenceManager.instance.isFavoriteStation(widget.station.stationId);
    if (mounted) {
      setState(() {
        isFavorite = favoriteStatus;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (isFavorite) {
      await PreferenceManager.instance.removeFavoriteStation(widget.station.stationId);
      if (mounted) {
        setState(() {
          isFavorite = false;
          favoriteChanged = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.station.baseStationName}을(를) 즐겨찾기에서 제거했습니다'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      final stationData = {
        'stationId': widget.station.stationId,
        'stationName': widget.station.baseStationName,
        'stationNum': widget.station.stationNum,
        'district': widget.station.district,
      };
      await PreferenceManager.instance.addFavoriteStation(stationData);
      if (mounted) {
        setState(() {
          isFavorite = true;
          favoriteChanged = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.station.baseStationName}을(를) 즐겨찾기에 추가했습니다'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
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

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(favoriteChanged);
        return false;
      },
      child: Scaffold(
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
                    _buildTopStationPanel(),
                    const SizedBox(height: 15),
                    Expanded(
                      child: _buildBusList(),
                    ),
                    _buildBottomStationPanel(),
                  ],
                ),
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
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(favoriteChanged),
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
                        const SizedBox(height: 2),
                      ],
                  ],
                ),
              ),
              GestureDetector(
                onTap: _toggleFavorite,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isFavorite ? Icons.star : Icons.star_border,
                    color: isFavorite ? const Color.fromRGBO(255, 197, 30, 1) : textColor.withValues(alpha: 0.6),
                    size: 28,
                  ),
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
        margin: const EdgeInsets.only(bottom: 13),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
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
            _buildArrivalInfo(route),
          ],
        ),
      ),
    );
  }

  Widget _buildArrivalInfo(BusRoute route) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final textColor = isDark ? AppColors.darkText : Colors.black87;
    
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
      case 1: return Colors.green;
      case 2: return Colors.orange;
      case 3: return Colors.red;
      default: return Colors.grey;
    }
  }

  Widget _buildBottomStationPanel() {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final panelColor = isDark ? AppColors.darkCard : Colors.grey[300];
    final textColor = isDark ? AppColors.darkText : Colors.black87;
    final subTextColor = isDark ? AppColors.darkText.withOpacity(0.7) : Colors.black54;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 0,left: 0,right: 0),
      padding: const EdgeInsets.fromLTRB(25, 12, 25, 25),
      decoration: BoxDecoration(
        color: panelColor,
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
        return Colors.teal;
    }
  }
}