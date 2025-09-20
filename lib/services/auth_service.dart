import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static AuthService? _instance;
  
  static AuthService get instance {
    _instance ??= AuthService._internal();
    return _instance!;
  }
  
  AuthService._internal();
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // 현재 사용자 가져오기
  User? get currentUser => _auth.currentUser;
  
  // 로그인 상태 스트림
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  // Google 로그인
  Future<UserCredential?> signInWithGoogle() async {
    try {
      print('Google Sign-In 시작'); // 디버깅용
      
      // Google Sign-In 플로우 시작
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      print('Google Sign-In 결과: $googleUser'); // 디버깅용
      
      if (googleUser == null) {
        // 사용자가 로그인을 취소한 경우
        print('사용자가 Google 로그인을 취소함'); // 디버깅용
        return null;
      }
      
      // Google 인증 정보 가져오기
      print('Google 인증 정보 가져오기 시작'); // 디버깅용
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      print('Google 인증 정보: accessToken=${googleAuth.accessToken != null}, idToken=${googleAuth.idToken != null}'); // 디버깅용
      
      // Firebase 인증을 위한 credential 생성
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      print('Firebase credential 생성 완료'); // 디버깅용
      
      // Firebase에 로그인
      print('Firebase 로그인 시작'); // 디버깅용
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      print('Firebase 로그인 완료: ${userCredential.user?.email}'); // 디버깅용
      
      // 사용자 정보를 Firestore에 저장 (첫 로그인인 경우)
      print('Firestore에 사용자 정보 저장 시작'); // 디버깅용
      await _saveUserToFirestore(userCredential.user!);
      print('Firestore에 사용자 정보 저장 완료'); // 디버깅용
      
      return userCredential;
    } catch (e) {
      print('Google 로그인 에러 상세: $e'); // 디버깅용
      throw Exception('Google 로그인 실패: $e');
    }
  }
  
  // 사용자 정보를 Firestore에 저장
  Future<void> _saveUserToFirestore(User user) async {
    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      
      // 이미 사용자 정보가 있으면 업데이트, 없으면 새로 생성
      if (!userDoc.exists) {
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName,
          'photoURL': user.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'hasSetup': false, // 초기 설정 완료 여부
        });
      } else {
        // 기존 사용자 정보 업데이트
        await _firestore.collection('users').doc(user.uid).update({
          'email': user.email,
          'displayName': user.displayName,
          'photoURL': user.photoURL,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      throw Exception('사용자 정보 저장 실패: $e');
    }
  }
  
  // 사용자 셋업 완료 여부 확인
  Future<bool> hasUserSetup(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        return data?['hasSetup'] ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  // 사용자 셋업 완료로 표시
  Future<void> markUserSetupComplete(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'hasSetup': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('셋업 완료 표시 실패: $e');
    }
  }
  
  // 로그아웃
  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
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
