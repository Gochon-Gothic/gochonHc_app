import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gochon_mobile/firebase_options.dart';
import 'package:gochon_mobile/services/auth_service.dart';
import 'package:gochon_mobile/services/user_service.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/initial_setup_screen.dart';
import 'main.dart';
import 'utils/preference_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
      home: const AuthWrapper(), // 로그인 상태에 따라 화면을 결정하는 위젯
      routes: {
        '/main': (context) => const MainScreen(),
        '/login': (context) => const LoginScreen(),
        '/initial_setup': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
          final userEmail = args?['userEmail'] as String? ?? '';
          final uid = args?['uid'] as String? ?? '';
          return InitialSetupScreen(userEmail: userEmail, uid: uid);
        },
      },
    );
  }
}
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        // 연결 상태 확인
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 로그인된 사용자가 있는지 확인
        if (snapshot.hasData) {
          final user = snapshot.data!;
          return FutureBuilder<bool>(
            future: UserService.instance.doesUserExist(user.uid),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (userSnapshot.hasData && userSnapshot.data!) {
                return const MainScreen();
              } else {
                // 정보 없음 -> 초기 설정 화면
                return InitialSetupScreen(
                  userEmail: user.email ?? '',
                  uid: user.uid,
                );
              }
            },
          );
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
