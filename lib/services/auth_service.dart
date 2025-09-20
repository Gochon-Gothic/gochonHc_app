import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gochon_mobile/services/user_service.dart';

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
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        return null; // 사용자가 로그인을 취소한 경우
      }

      // 이메일 도메인 확인
      if (!googleUser.email.endsWith('@gochon.hs.kr')) {
        await _googleSignIn.signOut(); // 부분적인 구글 로그인 상태를 취소
        throw Exception('고촌고등학교 계정(@gochon.hs.kr)으로만 로그인할 수 있습니다.');
      }
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      // Firebase에 로그인
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print('Google 로그인 에러 상세: $e'); // 디버깅용
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
