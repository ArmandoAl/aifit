import 'dart:async';
import 'package:aifit/features/auth/presentation/pages/login_page.dart';
import 'package:aifit/features/auth/presentation/pages/welcome_page.dart';
import 'package:aifit/features/auth/presentation/pages/photo_setup_page.dart';
import 'package:aifit/features/profile/presentation/pages/profile_page.dart';
import 'package:aifit/features/simulation/presentation/pages/outfit_result_page.dart';
import 'package:aifit/features/stylist/presentation/pages/stylist_page.dart';
import 'package:aifit/features/wardrobe/presentation/pages/wardrobe_page.dart';
import 'package:aifit/features/outfit/presentation/pages/generate_outfit_page.dart';
import 'package:aifit/features/outfit/presentation/pages/saved_outfits_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../widgets/main_layout.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/stylist/domain/chat_models.dart';

// Definimos una clave global para el navegador
final _rootNavigatorKey = GlobalKey<NavigatorState>();

// Helper class para convertir Stream en Listenable para GoRouter
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

GoRouter createRouter(BuildContext context) {
  final authBloc = context.read<AuthBloc>();

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: (context, state) {
      final authState = authBloc.state;
      final currentLocation = state.matchedLocation;

      // Si está cargando, solo permitir splash
      if (authState is AuthLoading) {
        if (currentLocation != '/splash') return '/splash';
        return null;
      }

      // Si no está autenticado
      if (authState is AuthUnauthenticated) {
        // Allow onboarding routes
        if (currentLocation == '/login' || 
            currentLocation == '/welcome' || 
            currentLocation == '/setup-photos') {
          return null; // Stay on current route
        }
        // From splash or any other route, go to login
        return '/login';
      }

      // Si está autenticado
      if (authState is AuthAuthenticated) {
        // From splash or login, go to welcome (onboarding)
        if (currentLocation == '/splash' || currentLocation == '/login') {
          return '/welcome';
        }
        // Allow welcome and setup-photos for onboarding flow
        if (currentLocation == '/welcome' || currentLocation == '/setup-photos') {
          return null;
        }
        return null;
      }

      return null;
    },
    routes: [
      // Splash Screen
      GoRoute(
        path: '/splash',
        builder: (context, state) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),

      // Login Page
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),

      // Welcome/Onboarding
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomePage(),
      ),

      // Photo Setup
      GoRoute(
        path: '/setup-photos',
        builder: (context, state) => const PhotoSetupPage(),
      ),
      // Shell Route (Barra de Navegación Inferior)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainLayout(navigationShell: navigationShell);
        },
        branches: [
          // Branch 1: Wardrobe
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/wardrobe',
                builder: (context, state) => const WardrobePage(),
              ),
            ],
          ),
          // Branch 2: Stylist / Chat
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/stylist',
                builder: (context, state) => const StylistPage(),
              ),
            ],
          ),
          // Branch 3: Profile
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
      // Ruta hija para generar outfits (fuera del bottom nav)
      GoRoute(
        path: '/generate-outfit',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const GenerateOutfitPage(),
      ),
      // Ruta hija para outfits guardados (fuera del bottom nav)
      GoRoute(
        path: '/saved-outfits',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SavedOutfitsPage(),
      ),
      // Ruta hija para resultados (fuera del bottom nav)
      GoRoute(
        path: '/outfit-result',
        parentNavigatorKey: _rootNavigatorKey, // Para cubrir la bottom bar
        builder: (context, state) {
          // Extraemos el objeto pasado como argumento
          final outfit = state.extra as GeneratedOutfit;
          return OutfitResultPage(outfit: outfit);
        },
      ),
    ],
  );
}
