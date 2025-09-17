import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';
import 'login.dart';
import 'main.dart';
import 'utils/preference_manager.dart';

void main() async {
  // Flutter 바인딩 초기화
  WidgetsFlutterBinding.ensureInitialized();

  // PreferenceManager 초기화
  await PreferenceManager.initialize();

  // 디바이스 타입 감지 및 화면 방향 설정
  _setDeviceOrientation();

  // 안드로이드 시스템 UI 설정
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // 상태바/시스템 UI 표시
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: SystemUiOverlay.values,
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

// 디바이스 타입에 따른 화면 방향 설정
void _setDeviceOrientation() {
  // 화면 크기 정보 가져오기
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final size = view.physicalSize;
  final pixelRatio = view.devicePixelRatio;

  // 실제 화면 크기 (픽셀 단위)
  final screenWidth = size.width / pixelRatio;
  final screenHeight = size.height / pixelRatio;

  // 디바이스 타입 판별 (가로/세로 비율과 크기로)
  final isTablet = screenWidth > 600 || screenHeight > 600;

  if (isTablet) {
    // 패드인 경우: 모든 방향 허용
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  } else {
    // 핸드폰인 경우: 세로 모드만 고정
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      theme: ThemeData.light().copyWith(
        textTheme: ThemeData.light().textTheme.apply(fontFamily: 'SFPro'),
      ),
      darkTheme: ThemeData.dark().copyWith(
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'SFPro'),
      ),
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const LoginScreen(),
      routes: {
        '/main': (context) => const MainScreen(),
        '/login': (context) => const LoginScreen(),
      },
    );
  }
}
