import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/services/firestore_service.dart';
import '../domain/user_model.dart' as app_model;

class AuthRepository {
  final FirebaseFirestore _firestore = FirestoreService.instance;
  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  Future<void>? _googleInit;

  static const String _webClientId =
      '268248668862-f1fp960traqm1i0t6ir8sms4qt23339d.apps.googleusercontent.com';

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

  Stream<app_model.User?> get authStateChanges =>
      _auth.authStateChanges().map((u) => u == null ? null : _toAppUser(u));

  app_model.User? get currentUser {
    final u = _auth.currentUser;
    return u == null ? null : _toAppUser(u);
  }

  /// URL de retorno tras [signInWithRedirect] (query o hash con apiKey/mode).
  bool isWebAuthRedirectReturn(Uri uri) {
    if (!kIsWeb) return false;
    if (uri.path.contains('__/auth')) return true;
    if (uri.queryParameters.containsKey('apiKey')) return true;
    if (uri.queryParameters.containsKey('mode')) return true;
    return uri.fragment.contains('apiKey=') || uri.fragment.contains('mode=');
  }

  /// Debe llamarse una sola vez en [main], antes de [runApp].
  Future<app_model.User?> bootstrapWebSession() async {
    if (!kIsWeb) return null;

    try {
      await _auth.setPersistence(fb_auth.Persistence.LOCAL);
    } catch (e) {
      debugPrint('⚠️ setPersistence: $e');
    }

    final likelyReturn = isWebAuthRedirectReturn(Uri.base);

    try {
      final result = await _auth.getRedirectResult();
      final user = result.user;
      if (user != null) {
        debugPrint('✅ bootstrap getRedirectResult: ${user.email}');
        await _syncFirebaseUserToFirestore(user);
        return _toAppUser(user);
      }
      final credential = result.credential;
      if (credential != null && _auth.currentUser == null) {
        final cred = await _auth.signInWithCredential(credential);
        final signedIn = cred.user;
        if (signedIn != null) {
          debugPrint('✅ bootstrap signInWithCredential: ${signedIn.email}');
          await _syncFirebaseUserToFirestore(signedIn);
          return _toAppUser(signedIn);
        }
      }
      debugPrint(
        'ℹ️ bootstrap getRedirectResult: sin sesión (likelyReturn=$likelyReturn)',
      );
    } catch (e, st) {
      debugPrint('❌ bootstrap getRedirectResult: $e\n$st');
    }

    final existing = _auth.currentUser;
    if (existing != null) {
      debugPrint('✅ bootstrap currentUser: ${existing.email}');
      return _toAppUser(existing);
    }

    if (likelyReturn) {
      try {
        final user = await _auth
            .authStateChanges()
            .where((u) => u != null)
            .map((u) => u!)
            .first
            .timeout(const Duration(seconds: 8));
        debugPrint('✅ bootstrap authStateChanges: ${user.email}');
        await _syncFirebaseUserToFirestore(user);
        return _toAppUser(user);
      } catch (e) {
        debugPrint('⚠️ bootstrap espera authStateChanges: $e');
      }
    }

    return null;
  }

  Future<app_model.User?> signInWithGoogle() async {
    try {
      debugPrint('🔐 Google Sign-In - Starting...');
      debugPrint('   kIsWeb: $kIsWeb');
      debugPrint('   Platform: ${defaultTargetPlatform.name}');

      if (kIsWeb) {
        return _signInWithGoogleWebPopup();
      }

      final firebaseUser = await _signInWithGoogleNative();

      try {
        await _syncFirebaseUserToFirestore(firebaseUser);
      } catch (e) {
        debugPrint('⚠️ Firestore sync failed (non-critical): $e');
      }

      _logAuthenticatedUser(firebaseUser);
      return _toAppUser(firebaseUser);
    } on fb_auth.FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        debugPrint('⚠️ Google Sign-In cancelled by user');
        return null;
      }
      debugPrint('❌ Firebase Auth Error: ${e.code} - ${e.message}');
      throw Exception('Google Sign-In Error: ${e.message}');
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        debugPrint('⚠️ Google Sign-In cancelled by user');
        return null;
      }
      debugPrint('❌ Google Sign-In Error: $e');
      throw Exception('Google Sign-In Error: $e');
    } catch (e) {
      debugPrint('❌ Google Sign-In Error: $e');
      throw Exception('Google Sign-In Error: $e');
    }
  }

  /// Popup en web (COOP/COEP ya no bloquean el opener en hosting).
  Future<app_model.User?> _signInWithGoogleWebPopup() async {
    debugPrint('🌐 Using Firebase signInWithPopup (web)');
    final provider = fb_auth.GoogleAuthProvider();
    provider.setCustomParameters({'prompt': 'select_account'});
    final userCredential = await _auth.signInWithPopup(provider);
    final user = userCredential.user;
    if (user == null) {
      throw Exception('Google Sign-In: Firebase devolvió usuario nulo');
    }

    try {
      await _syncFirebaseUserToFirestore(user);
    } catch (e) {
      debugPrint('⚠️ Firestore sync failed (non-critical): $e');
    }

    _logAuthenticatedUser(user);
    return _toAppUser(user);
  }

  Future<fb_auth.User> _signInWithGoogleNative() async {
    await _ensureGoogleInitialized();
    debugPrint('✅ Google Sign-In initialized (native)');

    final googleUser = await _googleSignIn.authenticate();
    debugPrint('✅ Google user authenticated: ${googleUser.email}');

    final googleAuth = googleUser.authentication;
    if (googleAuth.idToken == null) {
      throw Exception('Google Sign-In failed: missing idToken');
    }

    final credential = fb_auth.GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;
    if (user == null) {
      throw Exception('FirebaseAuth returned null user');
    }
    return user;
  }

  void _logAuthenticatedUser(fb_auth.User firebaseUser) {
    debugPrint('═══════════════════════════════════════════════════');
    debugPrint('✅ USUARIO AUTENTICADO CON GOOGLE');
    debugPrint('   UID: ${firebaseUser.uid}');
    debugPrint('   Email: ${firebaseUser.email ?? 'N/A'}');
    debugPrint('═══════════════════════════════════════════════════');
  }

  Future<void> _syncFirebaseUserToFirestore(fb_auth.User user) async {
    final userRef = _firestore.collection('users').doc(user.uid);
    final now = FieldValue.serverTimestamp();

    final doc = await userRef.get();
    if (!doc.exists) {
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

    await userRef.set({
      'displayName': user.displayName ?? '',
      'email': user.email ?? '',
      'photoUrl': user.photoURL ?? '',
      'lastLogin': now,
      'updatedAt': now,
    }, SetOptions(merge: true));
  }

  Future<void> signOut() async {
    debugPrint('🔓 Sign out');
    await _auth.signOut();
    if (kIsWeb) return;

    try {
      await _ensureGoogleInitialized();
      await _googleSignIn.disconnect();
    } catch (_) {
      // No-op
    }
  }
}
