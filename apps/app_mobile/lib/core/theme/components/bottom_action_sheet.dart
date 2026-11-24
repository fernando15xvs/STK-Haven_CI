import 'package:flutter/material.dart';
import '../app_colors.dart';

class BottomActionSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required List<Widget> children,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.of(context).surfaceHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppUiTokens.of(context).cardRadius + 4),
        ),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom:
                MediaQuery.of(ctx).viewInsets.bottom +
                MediaQuery.of(ctx).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.of(context).surfaceBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                  color: AppColors.of(ctx).textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ...children,
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
