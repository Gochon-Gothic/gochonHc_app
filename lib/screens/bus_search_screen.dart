import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart';
import '../theme_colors.dart';
import '../services/bus_service.dart';
import '../utils/preference_manager.dart';
import 'bus_detail_screen.dart';

class BusSearchScreen extends StatefulWidget {
  const BusSearchScreen({super.key});

  @override
  State<BusSearchScreen> createState() => _BusSearchScreenState();
}

class _BusSearchScreenState extends State<BusSearchScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final TextEditingController _searchController = TextEditingController();
  List<BusStation> searchResults = [];
  bool isSearching = false;
  List<Map<String, dynamic>> favoriteStations = [];
  Map<String, bool> stationFavoriteStatus = {};
  
  @override
  void initState() {
    super.initState();
    _loadFavoriteStations();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadFavoriteStations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFavoriteStations() async {
    final favorites = await PreferenceManager.instance.getFavoriteStations();
    if (mounted) {
      setState(() {
        favoriteStations = favorites;
        stationFavoriteStatus = {
          for (var station in favorites) station['stationId']: true
        };
      });
    }
  }

  Map<String, dynamic> _busStationToMap(BusStation station) {
    return {
      'stationId': station.stationId,
      'stationName': station.baseStationName,
      'stationNum': station.stationNum,
      'district': station.district,
    };
  }

  Future<bool> _isStationFavorite(String stationId) async {
    return await PreferenceManager.instance.isFavoriteStation(stationId);
  }

  Future<void> _toggleFavoriteStation(Map<String, dynamic> station) async {
    final stationId = station['stationId'];
    final isCurrentlyFavorite = stationFavoriteStatus[stationId] ?? false;
    
    if (isCurrentlyFavorite) {
      await PreferenceManager.instance.removeFavoriteStation(stationId);
      if (mounted) {
        setState(() {
          stationFavoriteStatus[stationId] = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${station['stationName']}을(를) 즐겨찾기에서 제거했습니다'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      await PreferenceManager.instance.addFavoriteStation(station);
      if (mounted) {
        setState(() {
          stationFavoriteStatus[stationId] = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${station['stationName']}을(를) 즐겨찾기에 추가했습니다'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _searchStations(String keyword) async {
    if (keyword.trim().isEmpty) {
      setState(() {
        searchResults = [];
        isSearching = false;
      });
      return;
    }

    setState(() {
      isSearching = true;
    });

    try {
      final results = await BusService.searchStations(keyword);
      if (mounted) {
        setState(() {
          searchResults = results;
          isSearching = false;
        });
        
        for (var station in results) {
          if (!stationFavoriteStatus.containsKey(station.stationId)) {
            stationFavoriteStatus[station.stationId] = await _isStationFavorite(station.stationId);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          searchResults = [];
          isSearching = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('검색 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  void _navigateToStation(BusStation station) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BusDetailScreen(station: station),
      ),
    );
    
    if (result == true) _loadFavoriteStations();
  }

  void _navigateToFavoriteStation(Map<String, dynamic> favoriteStation) async {
    final station = BusStation(
      stationId: favoriteStation['stationId'],
      stationName: favoriteStation['stationName'],
      stationNum: favoriteStation['stationNum'],
      x: 0.0,
      y: 0.0,
      district: favoriteStation['district'],
    );
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BusDetailScreen(station: station),
      ),
    );
    
    if (result == true) _loadFavoriteStations();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;

    return Container(
      color: bgColor,
      child: ListView(
        padding: const EdgeInsets.all(0),
        children: [
          const SizedBox(height: 60),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              '버스 알림',
              style: TextStyle(
                fontSize: 40,
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.3)
                      : const Color.fromRGBO(21, 21, 21, 0.1),
                  offset: const Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  color: textColor.withValues(alpha: 0.6),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: '정류장명 또는 번호를 입력하세요',
                      hintStyle: TextStyle(
                        color: textColor.withValues(alpha: 0.5),
                      ),
                      border: InputBorder.none,
                    ),
                    onChanged: _searchStations,
                  ),
                ),
                if (isSearching)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          if (_searchController.text.isNotEmpty && searchResults.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                '검색 결과 (${searchResults.length}개)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...searchResults.take(10).map((station) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Card(
                    color: cardColor,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: GestureDetector(
                        onTap: () => _toggleFavoriteStation(_busStationToMap(station)),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: Colors.transparent,
                          ),
                          child: Icon(
                            (stationFavoriteStatus[station.stationId] ?? false) 
                                ? Icons.star 
                                : Icons.star_border,
                            color: (stationFavoriteStatus[station.stationId] ?? false)
                                ? const Color.fromRGBO(255, 197, 30, 1)
                                : textColor.withValues(alpha: 0.6),
                            size: 24,
                          ),
                        ),
                      ),
                      title: Text(
                        station.baseStationName,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Builder(
                            builder: (context) {
                              final direction = station.getDirectionFromCoordinate(BusService.getCachedStations());
                              if (direction.isNotEmpty) {
                                return Text(
                                  direction,
                                  style: TextStyle(
                                    color: const Color.fromRGBO(255, 197, 30, 1),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                          Text(
                            '정류장 번호: ${station.stationNum}',
                            style: TextStyle(
                              fontSize: 12,
                              color: textColor.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        color: textColor.withValues(alpha: 0.4),
                        size: 16,
                      ),
                      onTap: () => _navigateToStation(station),
                    ),
                  ),
                )),
          ] else if (_searchController.text.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                '즐겨찾기',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (favoriteStations.isEmpty) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.star_border,
                      size: 48,
                      color: textColor.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '즐겨찾기 역이 없습니다',
                      style: TextStyle(
                        fontSize: 16,
                        color: textColor.withValues(alpha: 0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '역을 검색하고 별 아이콘을 눌러 즐겨찾기에 추가하세요',
                      style: TextStyle(
                        fontSize: 14,
                        color: textColor.withValues(alpha: 0.5),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ] else ...[
              ...favoriteStations.map((station) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Card(
                      color: cardColor,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: GestureDetector(
                          onTap: () => _toggleFavoriteStation(station),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: Colors.transparent,
                            ),
                            child: Icon(
                              (stationFavoriteStatus[station['stationId']] ?? true) 
                                  ? Icons.star 
                                  : Icons.star_border,
                              color: (stationFavoriteStatus[station['stationId']] ?? true)
                                  ? const Color.fromRGBO(255, 197, 30, 1)
                                  : textColor.withValues(alpha: 0.6),
                              size: 24,
                            ),
                          ),
                        ),
                        title: Text(
                          station['stationName'] ?? '',
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '정류장 번호: ${station['stationNum'] ?? ''}',
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.6),
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          color: textColor.withValues(alpha: 0.4),
                          size: 16,
                        ),
                        onTap: () => _navigateToFavoriteStation(station),
                      ),
                    ),
                  )),
            ],
          ] else if (_searchController.text.isNotEmpty && searchResults.isEmpty && !isSearching) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.search_off,
                    size: 48,
                    color: textColor.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '검색 결과가 없습니다.',
                    style: TextStyle(
                      fontSize: 16,
                      color: textColor.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '정류장명이나 번호를 정확히 입력해주세요.',
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor.withValues(alpha: 0.5),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
