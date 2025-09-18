import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart';
import '../theme_colors.dart';
import '../services/bus_service.dart';

class BusStationScreen extends StatefulWidget {
  final BusStation station;

  const BusStationScreen({
    super.key,
    required this.station,
  });

  @override
  State<BusStationScreen> createState() => _BusStationScreenState();
}

class _BusStationScreenState extends State<BusStationScreen> {
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
    final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          widget.station.stationName,
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
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
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Colors.black.withValues(alpha: 0.5)
                                : const Color.fromRGBO(21, 21, 21, 0.5),
                            offset: const Offset(0, 0),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                color: textColor,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.station.stationName,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '정류장 번호: ${widget.station.stationNum}',
                            style: TextStyle(
                              fontSize: 16,
                              color: textColor.withValues(alpha: 0.7),
                            ),
                          ),
                          if (stationDetail?.regionName != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              '지역: ${stationDetail!.regionName}',
                              style: TextStyle(
                                fontSize: 16,
                                color: textColor.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '경유 노선 (${routes.length}개)',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (routes.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            '경유하는 버스 노선이 없습니다.',
                            style: TextStyle(
                              color: textColor.withValues(alpha: 0.6),
                              fontSize: 16,
                            ),
                          ),
                        ),
                      )
                    else
                      ...routes.map((route) => Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getRouteTypeColor(route.routeTypeName),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    route.routeName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        route.routeTypeName,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: textColor,
                                        ),
                                      ),
                                      if (route.regionName.isNotEmpty)
                                        Text(
                                          route.regionName,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: textColor.withValues(alpha: 0.6),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.map,
                            size: 48,
                            color: textColor.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '지도 기능은 곧 추가될 예정입니다.',
                            style: TextStyle(
                              fontSize: 16,
                              color: textColor.withValues(alpha: 0.6),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
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
        return Colors.grey;
    }
  }
}
