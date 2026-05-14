import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import '../../data/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(const AuthLoading()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthLoginRequested>(_onAuthLoginRequested);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);

    // Auto-check auth on initialization
    add(const AuthCheckRequested());
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    
    // Small delay to ensure router is ready
    await Future.delayed(const Duration(milliseconds: 300));
    
    try {
      // Verificar si hay usuario autenticado
      final user = authRepository.currentUser;
      
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        emit(const AuthUnauthenticated());
      }
    } catch (e) {
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onAuthLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    debugPrint("🔵 AuthBloc: Login requested");
    emit(const AuthLoading());
    
    try {
      final user = await authRepository.signInWithGoogle();
      
      if (user != null) {
        debugPrint("═══════════════════════════════════════════════════");
        debugPrint("✅ AuthBloc: Login exitoso");
        debugPrint("   Usuario: ${user.name}");
        debugPrint("   UID: ${user.id}");
        debugPrint("   Email: ${user.email ?? 'N/A'}");
        debugPrint("═══════════════════════════════════════════════════");
        emit(AuthAuthenticated(user));
        debugPrint("✅ AuthBloc: Estado AuthAuthenticated emitido");
      } else {
        debugPrint("⚠️ AuthBloc: Login returned null (user cancelled)");
        emit(const AuthUnauthenticated());
      }
    } catch (e) {
      debugPrint("❌ AuthBloc: Login error - $e");
      emit(AuthError(e.toString()));
      await Future.delayed(const Duration(milliseconds: 500));
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onAuthLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await authRepository.signOut();
      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }
}
