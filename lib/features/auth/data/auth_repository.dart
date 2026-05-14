import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart' show debugPrint, defaultTargetPlatform;
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/services/firestore_service.dart';
import '../domain/user_model.dart' as app_model;

class AuthRepository {
  final FirebaseFirestore _firestore = FirestoreService.instance;
  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  Future<void>? _googleInit;

  // Web Client ID (serverClientId) - Required for Android
  // This is the OAuth 2.0 Web Client ID from Firebase Console
  // You can find it in: Firebase Console → Project Settings → Your apps → Android app → OAuth 2.0 Client IDs
  // Look for the one with type "Web application"
  static const String _webClientId = '268248668862-f1fp960traqm1i0t6ir8sms4qt23339d.apps.googleusercontent.com';

  Future<void> _ensureGoogleInitialized() {
    return _googleInit ??= _googleSignIn.initialize(
      serverClientId: _webClientId,
    );
  }

  app_model.User? _toAppUser(fb_auth.User user) {
    final name = (user.displayName?.trim().isNotEmpty ?? false)
        ? user.displayName!.trim()
        : (user.email?.trim().isNotEmpty ?? false)
            ? user.email!.trim()
            : 'User';
    return app_model.User(
      id: user.uid,
      name: name,
      avatarUrl: user.photoURL ?? '',
      email: user.email,
    );
  }

  // Stream para escuchar cambios de sesión (FirebaseAuth)
  Stream<app_model.User?> get authStateChanges =>
      _auth.authStateChanges().map((u) => u == null ? null : _toAppUser(u));

  // Verificar si hay usuario actual
  app_model.User? get currentUser {
    final u = _auth.currentUser;
    return u == null ? null : _toAppUser(u);
  }

  Future<app_model.User?> signInWithGoogle() async {
    try {
      debugPrint("🔐 Google Sign-In - Starting...");
      debugPrint("   Platform: ${defaultTargetPlatform.name}");

      await _ensureGoogleInitialized();
      debugPrint("✅ Google Sign-In initialized");

      debugPrint("   Attempting authentication...");
      final googleUser = await _googleSignIn.authenticate();
      
      debugPrint("✅ Google user authenticated: ${googleUser.email}");
      final googleAuth = googleUser.authentication;
      
      if (googleAuth.idToken == null) {
        debugPrint("❌ Google authentication missing idToken");
        throw Exception("Google Sign-In failed: missing idToken");
      }
      
      debugPrint("✅ Google idToken obtained");
      final credential = fb_auth.GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        throw Exception("FirebaseAuth returned null user");
      }

      // Sync to Firestore (with retry for transient errors)
      try {
        await _syncFirebaseUserToFirestore(firebaseUser);
      } catch (e) {
        // Firestore sync failure is not critical - user is still authenticated
        // This can happen with transient network issues
        debugPrint("⚠️ Firestore sync failed (non-critical): $e");
        // Continue - user can still use the app
      }

      debugPrint("═══════════════════════════════════════════════════");
      debugPrint("✅ USUARIO AUTENTICADO CON GOOGLE");
      debugPrint("   UID: ${firebaseUser.uid}");
      debugPrint("   Email: ${firebaseUser.email ?? 'N/A'}");
      debugPrint("   Nombre: ${firebaseUser.displayName ?? 'N/A'}");
      debugPrint("   Foto: ${firebaseUser.photoURL ?? 'N/A'}");
      debugPrint("═══════════════════════════════════════════════════");
      debugPrint("📝 IMPORTANTE: Todos los datos se asociarán con este UID");
      debugPrint("   - Firestore: users/${firebaseUser.uid}");
      debugPrint("   - Storage: users/${firebaseUser.uid}/...");
      debugPrint("═══════════════════════════════════════════════════");

      return _toAppUser(firebaseUser);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        debugPrint("⚠️ Google Sign-In cancelled by user");
        return null;
      }
      debugPrint("❌ Google Sign-In Error: $e");
      throw Exception("Google Sign-In Error: $e");
    } catch (e) {
      debugPrint("❌ Google Sign-In Error: $e");
      throw Exception("Google Sign-In Error: $e");
    }
  }

  Future<void> _syncFirebaseUserToFirestore(fb_auth.User user) async {
    final userRef = _firestore.collection('users').doc(user.uid);
    final now = FieldValue.serverTimestamp();

    final doc = await userRef.get();
    if (!doc.exists) {
      // First time: create full profile scaffold
      await userRef.set({
        'displayName': user.displayName ?? '',
        'email': user.email ?? '',
        'photoUrl': user.photoURL ?? '',
        'createdAt': now,
        'lastLogin': now,
        'preferences': {'styleTags': [], 'temperatureSensitivity': 'medium'},
        'bodyPhotos': [],
        'facePhotos': [],
        'onboardingCompleted': false,
      });
      return;
    }

    // Existing user: do NOT reset preferences/photos/onboarding fields
    await userRef.set({
      'displayName': user.displayName ?? '',
      'email': user.email ?? '',
      'photoUrl': user.photoURL ?? '',
      'lastLogin': now,
      'updatedAt': now,
    }, SetOptions(merge: true));
  }

  Future<void> signOut() async {
    debugPrint("🔓 Sign out");
    await _auth.signOut();
    try {
      await _ensureGoogleInitialized();
      await _googleSignIn.disconnect();
    } catch (_) {
      // No-op: disconnect may fail if not signed in.
    }
  }
}
