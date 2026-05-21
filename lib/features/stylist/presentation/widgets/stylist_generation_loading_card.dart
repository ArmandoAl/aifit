import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class StylistGenerationLoadingCard extends StatelessWidget {
  final String? phase;

  const StylistGenerationLoadingCard({super.key, this.phase});

  String get _label {
    switch (phase) {
      case 'analyzing':
        return 'Understanding your style intent…';
      case 'filtering':
        return 'Searching your wardrobe…';
      case 'generating':
        return 'Composing outfit combinations…';
      case 'creating_image':
        return 'Creating your virtual try-on…';
      default:
        return 'Styling your look…';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Using your wardrobe & style profile',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
