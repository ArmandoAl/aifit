import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_router.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/wardrobe/presentation/bloc/wardrobe_bloc.dart';
import 'features/wardrobe/data/wardrobe_repository_impl.dart';
import 'features/stylist/presentation/bloc/chat_bloc.dart';
import 'features/stylist/data/stylist_repository.dart';
import 'features/outfit/presentation/bloc/outfit_generation_bloc.dart';
import 'features/outfit/presentation/bloc/saved_outfits_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const AIFitApp());
}

class AIFitApp extends StatelessWidget {
  const AIFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => AuthBloc(authRepository: AuthRepository()),
        ),
        BlocProvider(
          create: (context) => WardrobeBloc(
            repository: WardrobeRepositoryImpl(),
          ),
        ),
        BlocProvider(
          create: (context) => ChatBloc(repository: StylistRepository()),
        ),
        BlocProvider(
          create: (context) => OutfitGenerationBloc(),
        ),
        BlocProvider(
          create: (context) => SavedOutfitsBloc(),
        ),
      ],
      child: Builder(
        builder: (context) {
          // Ahora este context SÍ tiene acceso a los BlocProviders
          return MaterialApp.router(
            title: 'AIFit',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            routerConfig: createRouter(context),
          );
        },
      ),
    );
  }
}
