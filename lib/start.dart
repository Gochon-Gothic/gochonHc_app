import 'package:firebase_auth/firebase_auth.dart' hide UserInfo;
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
import 'screens/elective_setup_screen.dart';
import 'main.dart';
import 'utils/preference_manager.dart';
import 'models/user_info.dart';

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
      debugShowCheckedModeBanner: false,
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
// 사용자 설정 상태 확인 (Firestore만 확인, 서버에 없으면 반드시 초기 설정 화면으로)
Future<Map<String, dynamic>> _checkUserSetup(String uid) async {
  try {
    final userData = await AuthService.instance.getUserFromFirestore(uid);
    if (userData == null) {
      await UserService.instance.clearUserInfo();
      return {'hasSetup': false, 'userInfo': null, 'hasElectiveSetup': false, 'needsGradeRefresh': false};
    }
    
    // 필수 필드 확인
    final grade = userData['grade'] as int?;
    final classNum = userData['classNum'] as int?;
    final number = userData['number'] as int?;
    final name = userData['name'] as String? ?? '';
    
    // 필수 필드가 없거나 name이 비어있으면 로컬 데이터 삭제하고 설정 미완료
    if (grade == null || classNum == null || number == null || name.isEmpty) {
      await UserService.instance.clearUserInfo();
      return {'hasSetup': false, 'userInfo': null, 'hasElectiveSetup': false, 'needsGradeRefresh': false};
    }
    
    // 설정 완료 - Firestore 데이터로 로컬 동기화
    final userInfo = UserInfo.fromJson(userData);
    final hasElectiveSetup = userData['hasElectiveSetup'] == true;
    
    // 로컬에 저장 (Firestore가 source of truth)
    await UserService.instance.saveUserInfo(userInfo);
    
    final needsGradeRefresh = await PreferenceManager.instance.needsGradeRefreshThisYear();
    return {
      'hasSetup': true,
      'userInfo': userInfo,
      'hasElectiveSetup': hasElectiveSetup,
      'needsGradeRefresh': needsGradeRefresh,
    };
  } catch (_) {
    // 에러 발생 시에도 로컬 데이터 삭제하고 설정 미완료로 처리
    await UserService.instance.clearUserInfo();
    return {'hasSetup': false, 'userInfo': null, 'hasElectiveSetup': false, 'needsGradeRefresh': false};
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
          return FutureBuilder<Map<String, dynamic>>(
            future: _checkUserSetup(user.uid),
            builder: (context, setupSnapshot) {
              if (setupSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              
              final setupInfo = setupSnapshot.data;
              if (setupInfo == null) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              
              final hasSetup = setupInfo['hasSetup'] as bool;
              final userInfo = setupInfo['userInfo'] as UserInfo?;
              final hasElectiveSetup = setupInfo['hasElectiveSetup'] as bool;
              final needsGradeRefresh = setupInfo['needsGradeRefresh'] as bool? ?? false;
              
              if (!hasSetup || userInfo == null) {
                return InitialSetupScreen(
                  userEmail: user.email ?? '',
                  uid: user.uid,
                );
              }

              if (needsGradeRefresh) {
                return InitialSetupScreen(
                  userEmail: user.email ?? '',
                  uid: user.uid,
                  existingUserInfo: userInfo,
                  isGradeRefresh: true,
                );
              }
              
              if (userInfo.grade > 1 && !hasElectiveSetup) {
                return ElectiveSetupScreen(
                  userEmail: user.email ?? '',
                  uid: user.uid,
                  grade: userInfo.grade,
                  classNum: userInfo.classNum,
                  isEditMode: false,
                  isFromLogin: true,
                );
              }
              
              return const MainScreen();
            },
          );
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
