import 'package:flutter/material.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';

/// A flat, theme-aware surface for related destinations or actions.
class ActionNavigationGroup extends StatelessWidget {
  const ActionNavigationGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final tokens = AppUiTokens.of(context);
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        side: BorderSide(color: colors.surfaceBorder, width: tokens.borderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, color: colors.surfaceBorder),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Full-width Material action with feedback and wrapping text.
class ActionNavigationTile extends StatelessWidget {
  const ActionNavigationTile({
    super.key, required this.icon, required this.title, this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final tokens = AppUiTokens.of(context);
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: enabled ? colors.primaryFaded : colors.surfaceHigh,
                  borderRadius: BorderRadius.circular(tokens.buttonRadius),
                ),
                child: Icon(icon, color: enabled ? colors.primary : colors.textDisabled,
                  size: 22),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.headlineSmall.copyWith(
                    color: enabled ? colors.textPrimary : colors.textDisabled)),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(subtitle!, style: AppTypography.bodySmall.copyWith(
                      color: enabled ? colors.textSecondary : colors.textDisabled)),
                  ],
                ],
              )),
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.chevron_right, size: 20,
                color: enabled ? colors.textSecondary : colors.textDisabled),
            ]),
          ),
        ),
      ),
    );
  }
}

class ActionSectionHeading extends StatelessWidget {
  const ActionSectionHeading(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Semantics(
      header: true,
      child: Text(title.toUpperCase(), style: AppTypography.labelMedium.copyWith(
        color: AppColors.of(context).textSecondary)),
    ),
  );
}
