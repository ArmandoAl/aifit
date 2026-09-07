import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/l10n/app_strings_es.dart';
import '../../../../core/services/onboarding_gate_service.dart';
import '../../../../core/services/onboarding_prefs.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/atelier_wordmark.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_state.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingStep> _steps = [
    OnboardingStep(
      number: '01',
      icon: Icons.camera_alt_outlined,
      title: 'Tu identidad',
      description:
          'Fotos claras de cara y cuerpo. Así el try-on conserva tu piel, tu silueta y tu presencia.',
      examples: [
        'Cuerpo completo de frente',
        'Perfil lateral',
        'Primer plano del rostro',
        'Luz natural, fondo limpio',
      ],
    ),
    OnboardingStep(
      number: '02',
      icon: Icons.checkroom_outlined,
      title: AppStringsEs.buildWardrobe,
      description: AppStringsEs.buildWardrobeDesc,
      examples: [
        'Prenda extendida',
        'Buena iluminación',
        'Fondo despejado',
        'Una prenda por foto',
      ],
    ),
    OnboardingStep(
      number: '03',
      icon: Icons.auto_awesome_outlined,
      title: AppStringsEs.getRecommendations,
      description: AppStringsEs.getRecommendationsDesc,
      examples: [
        'Describe la ocasión',
        'Looks con tu armario',
        'Coordinación de color',
        'Try-on virtual',
      ],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finishTips({required bool goToPhotoSetup}) async {
    await OnboardingPrefs.markTipsSeen();
    OnboardingGateService.invalidateCache();

    if (!mounted) return;

    if (!goToPhotoSetup) {
      context.go('/wardrobe');
      return;
    }

    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      final hasPhotos = await OnboardingGateService.userHasIdentityPhotos(
        authState.user.id,
      );
      if (!mounted) return;
      if (hasPhotos) {
        context.go('/wardrobe');
        return;
      }
    }

    context.go('/setup-photos');
  }

  void _nextPage() {
    if (_currentPage < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finishTips(goToPhotoSetup: true);
    }
  }

  void _skip() {
    _finishTips(goToPhotoSetup: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 8, 0),
              child: Row(
                children: [
                  const AtelierWordmark(
                    fontSize: 22,
                    showRule: false,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _skip,
                    child: Text(
                      AppStringsEs.skip.toUpperCase(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemCount: _steps.length,
                itemBuilder: (context, index) {
                  final step = _steps[index];
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
                    child: Column(
                      children: [
                        Text(
                          step.number,
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 64,
                            fontWeight: FontWeight.w500,
                            color: AppColors.gold.withValues(alpha: 0.55),
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.4),
                            ),
                            boxShadow: AppTheme.ambientCardShadow,
                          ),
                          child: Icon(
                            step.icon,
                            size: 36,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          step.title,
                          style: theme.textTheme.headlineLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          step.description,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppColors.secondary,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusLg),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStringsEs.tips.toUpperCase(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppColors.gold,
                                ),
                              ),
                              const SizedBox(height: 14),
                              ...step.examples.map(
                                (example) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.north_east,
                                        size: 14,
                                        color: AppColors.gold,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          example,
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _steps.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 28 : 7,
                  height: 3,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? AppColors.primary
                        : AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _nextPage,
                  child: Text(
                    (_currentPage == _steps.length - 1
                            ? AppStringsEs.getStarted
                            : AppStringsEs.next)
                        .toUpperCase(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

class OnboardingStep {
  final String number;
  final IconData icon;
  final String title;
  final String description;
  final List<String> examples;

  OnboardingStep({
    required this.number,
    required this.icon,
    required this.title,
    required this.description,
    required this.examples,
  });
}
