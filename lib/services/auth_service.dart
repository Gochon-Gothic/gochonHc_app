import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gochon_mobile/services/user_service.dart';
import 'dart:io';

class AuthService {
  static AuthService? _instance;
  
  static AuthService get instance {
    _instance ??= AuthService._internal();
    return _instance!;
  }
  
  AuthService._internal();
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // iOS 시뮬레이터에서의 문제를 해결하기 위한 설정
    scopes: ['email', 'profile'],
    // 시뮬레이터에서 더 안정적으로 작동하도록 설정
    hostedDomain: 'gochon.hs.kr',
  );
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // 현재 사용자 가져오기
  User? get currentUser => _auth.currentUser;
  
  // 로그인 상태 스트림
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  // Google 로그인
  Future<UserCredential?> signInWithGoogle() async {
    try {
      print('Google 로그인 시작...');
      
      // iOS 시뮬레이터에서의 제한사항 확인
      if (Platform.isIOS) {
        print('iOS 플랫폼에서 실행 중');
        // 시뮬레이터에서는 Google Sign-In이 제한될 수 있음
      }
      
      // Google Sign-In 상태 확인
      print('Google Sign-In 상태 확인 중...');
      final isSignedIn = await _googleSignIn.isSignedIn();
      print('현재 로그인 상태: $isSignedIn');
      
      if (isSignedIn) {
        print('이미 로그인된 상태입니다. 로그아웃 후 다시 시도합니다.');
        await _googleSignIn.signOut();
      }
      
      print('Google Sign-In 프로세스 시작...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        print('사용자가 로그인을 취소했습니다.');
        return null; // 사용자가 로그인을 취소한 경우
      }

      print('Google 사용자 정보: ${googleUser.email}');
      
      // 이메일 도메인 확인
      if (!googleUser.email.endsWith('@gochon.hs.kr')) {
        print('잘못된 도메인: ${googleUser.email}');
        await _googleSignIn.signOut(); // 부분적인 구글 로그인 상태를 취소
        throw Exception('고촌고등학교 계정(@gochon.hs.kr)으로만 로그인할 수 있습니다.');
      }
      
      print('Google 인증 토큰 요청 중...');
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        print('Google 인증 토큰이 null입니다.');
        throw Exception('Google 인증 토큰을 가져올 수 없습니다.');
      }
      
      print('Firebase 인증 시작...');
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      // Firebase에 로그인
      final userCredential = await _auth.signInWithCredential(credential);
      print('Firebase 로그인 성공: ${userCredential.user?.email}');
      return userCredential;
    } catch (e) {
      print('Google 로그인 에러 상세: $e');
      print('에러 타입: ${e.runtimeType}');
      if (e is FirebaseAuthException) {
        print('Firebase Auth 에러 코드: ${e.code}');
        print('Firebase Auth 에러 메시지: ${e.message}');
      }
      
      // iOS 시뮬레이터에서의 특별한 에러 처리
      if (Platform.isIOS && (e.toString().contains('simulator') || e.toString().contains('Lost connection'))) {
        throw Exception('iOS 시뮬레이터에서는 Google Sign-In이 제한될 수 있습니다. 실제 기기에서 테스트해주세요.');
      }
      
      throw Exception('Google 로그인 실패: $e');
    }
  }
  
  // Firestore에 사용자 문서가 존재하는지 확인
  Future<bool> checkUserExists(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      return userDoc.exists;
    } catch (e) {
      print('사용자 문서 확인 실패: $e');
      return false;
    }
  }

  // Firestore에서 사용자 정보 가져오기
  Future<Map<String, dynamic>?> getUserFromFirestore(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        return userDoc.data();
      }
      return null;
    } catch (e) {
      print('Firestore 사용자 정보 가져오기 실패: $e');
      return null;
    }
  }
  
  // 로그아웃
  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
      await UserService.instance.clearUserInfo(); // 로컬 사용자 정보 삭제
    } catch (e) {
      throw Exception('로그아웃 실패: $e');
    }
  }
  
  // 계정 삭제
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Firestore에서 사용자 데이터 삭제
        await _firestore.collection('users').doc(user.uid).delete();
        
        // Firebase Auth에서 계정 삭제
        await user.delete();
      }
    } catch (e) {
      throw Exception('계정 삭제 실패: $e');
    }
  }
}
