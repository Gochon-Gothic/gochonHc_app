import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gochon_mobile/services/user_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
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
    scopes: ['email', 'profile'],
    serverClientId: '38240410420-3hsiq53tf3etuajnptqbba2gfkt9rvh9.apps.googleusercontent.com',
  );
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential?> signInWithApple() async {
    try {
      print('Apple 로그인 시작...');

      final rawNonce = _generateNonce();
      final nonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      print('Apple 자격 증명서 받음: ${appleCredential.email}');
      print('Apple identityToken 존재: ${appleCredential.identityToken != null}');
      print('Apple authorizationCode 존재: ${appleCredential.authorizationCode != null}');
      print('Apple userIdentifier: ${appleCredential.userIdentifier}');

      if (appleCredential.identityToken == null) {
        throw Exception('Apple identityToken이 null입니다.');
      }

      final credential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken!,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode, // firebase_auth 4.3.0+ 필수
      );

      print('Firebase 인증 시작...');
      print('OAuthCredential 생성 완료');
      final userCredential = await _auth.signInWithCredential(credential);
      print('Firebase 로그인 성공: ${userCredential.user?.email}');

      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        String? displayName;
        if (appleCredential.givenName != null ||
            appleCredential.familyName != null) {
          displayName =
              '${appleCredential.familyName ?? ''}${appleCredential.givenName ?? ''}'
                  .trim();
        }

        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'email': userCredential.user!.email,
          'displayName': displayName ?? userCredential.user!.displayName,
          'photoURL': userCredential.user!.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return userCredential;
    } catch (e) {
      print('Apple 로그인 에러 상세: $e');
      print('에러 타입: ${e.runtimeType}');
      if (e is FirebaseAuthException) {
        print('Firebase Auth 에러 코드: ${e.code}');
        print('Firebase Auth 에러 메시지: ${e.message}');
      }
      throw Exception('Apple 로그인 실패: $e');
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      print('Google 로그인 시작...');

      if (Platform.isIOS) {
        print('iOS 플랫폼에서 실행 중');
      }

      print('Google Sign-In 상태 확인 중...');
      final isSignedIn = await _googleSignIn.isSignedIn();
      print('현재 로그인 상태: $isSignedIn');

      if (isSignedIn) {
        print('이미 로그인된 상태입니다. 로그아웃 후 다시 시도합니다.');
        await _googleSignIn.signOut();
      }

      print('Google Sign-In 프로세스 시작...');
      print('플랫폼: ${Platform.isAndroid ? "Android" : Platform.isIOS ? "iOS" : "Other"}');
      
      GoogleSignInAccount? googleUser;
      try {
        googleUser = await _googleSignIn.signIn();
      } catch (signInError) {
        print('Google Sign-In 호출 중 오류 발생: $signInError');
        print('오류 타입: ${signInError.runtimeType}');
        rethrow;
      }

      if (googleUser == null) {
        print('사용자가 로그인을 취소했습니다.');
        return null;
      }

      print('Google 사용자 정보: ${googleUser.email}');

      print('Google 인증 토큰 요청 중...');
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        print('Google 인증 토큰이 null입니다.');
        throw Exception('Google 인증 토큰을 가져올 수 없습니다.');
      }

      print('Firebase 인증 시작...');
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

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

      if (Platform.isIOS &&
          (e.toString().contains('simulator') ||
              e.toString().contains('Lost connection'))) {
        throw Exception(
            'iOS 시뮬레이터에서는 Google Sign-In이 제한될 수 있습니다. 실제 기기에서 테스트해주세요.');
      }

      throw Exception('Google 로그인 실패: $e');
    }
  }

  Future<bool> checkUserExists(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      return userDoc.exists;
    } catch (e) {
      print('사용자 문서 확인 실패: $e');
      return false;
    }
  }

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

  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
      await UserService.instance.clearUserInfo();
    } catch (e) {
      throw Exception('로그아웃 실패: $e');
    }
  }

  // 재인증 수행
  Future<void> _reauthenticate() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('로그인된 사용자가 없습니다.');
    }

    // 사용자의 로그인 제공자 확인
    final providerData = user.providerData;
    if (providerData.isEmpty) {
      throw Exception('로그인 제공자 정보를 찾을 수 없습니다.');
    }

    final providerId = providerData.first.providerId;
    
    if (providerId == 'google.com') {
      // Google 재인증
      try {
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          throw Exception('Google 재인증이 취소되었습니다.');
        }
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await user.reauthenticateWithCredential(credential);
      } catch (e) {
        throw Exception('Google 재인증 실패: $e');
      }
    } else if (providerId == 'apple.com') {
      // Apple 재인증
      try {
        final rawNonce = _generateNonce();
        final nonce = sha256.convert(utf8.encode(rawNonce)).toString();
        
        final appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
          nonce: nonce,
        );
        
        if (appleCredential.identityToken == null) {
          throw Exception('Apple identityToken이 null입니다.');
        }
        
        final credential = OAuthProvider("apple.com").credential(
          idToken: appleCredential.identityToken!,
          rawNonce: rawNonce,
          accessToken: appleCredential.authorizationCode,
        );
        
        await user.reauthenticateWithCredential(credential);
      } catch (e) {
        throw Exception('Apple 재인증 실패: $e');
      }
    } else {
      throw Exception('지원하지 않는 로그인 방식입니다: $providerId');
    }
  }

  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('로그인된 사용자가 없습니다.');
      }

      // 1. 재인증 수행 (계정 삭제 전 필수)
      try {
        await _reauthenticate();
      } catch (e) {
        // 재인증 실패 시 사용자에게 명확한 메시지 전달
        if (e.toString().contains('취소')) {
          throw Exception('재인증이 취소되었습니다. 계정 삭제를 취소합니다.');
        }
        throw Exception('재인증이 필요합니다. 다시 로그인 후 시도해주세요: $e');
      }

      final uid = user.uid;
      
      // 2. Firestore에서 사용자 데이터 삭제
      try {
        await _firestore.collection('users').doc(uid).delete();
      } catch (e) {
        print('Firestore 삭제 실패: $e');
        // Firestore 삭제 실패해도 계속 진행
      }
      
      // 3. Google Sign-In 로그아웃 (Google 로그인인 경우)
      try {
        if (await _googleSignIn.isSignedIn()) {
          await _googleSignIn.signOut();
        }
      } catch (e) {
        print('Google Sign-In 로그아웃 실패: $e');
        // Google 로그아웃 실패해도 계속 진행
      }
      
      // 4. 로컬 사용자 정보 삭제
      try {
        await UserService.instance.clearUserInfo();
      } catch (e) {
        print('로컬 데이터 삭제 실패: $e');
        // 로컬 삭제 실패해도 계속 진행
      }
      
      // 5. Firebase Auth 계정 삭제 (재인증 후 가능)
      await user.delete();
      
      // 6. Firebase Auth 로그아웃
      await _auth.signOut();
    } catch (e) {
      print('계정 삭제 에러: $e');
      if (e is FirebaseAuthException) {
        if (e.code == 'requires-recent-login') {
          throw Exception('보안을 위해 재인증이 필요합니다. 다시 시도해주세요.');
        }
        throw Exception('계정 삭제 실패: ${e.message ?? e.code}');
      }
      // 이미 Exception인 경우 그대로 전달
      if (e is Exception) {
        rethrow;
      }
      throw Exception('계정 삭제 실패: $e');
    }
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }
}
