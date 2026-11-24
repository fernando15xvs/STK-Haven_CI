import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/core/theme/components/premium_card.dart';
import 'package:flutter/material.dart';

/// Shared Perfil settings surface built on the canonical PremiumCard.
class ProfileSectionCard extends StatelessWidget {
  const ProfileSectionCard({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final ui = AppUiTokens.of(context);
    return PremiumCard(
      padding: EdgeInsets.fromLTRB(ui.cardPadding, ui.cardPadding - 2,
          ui.cardPadding, AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontVariations: const [FontVariation('wght', 700)],
                ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}
