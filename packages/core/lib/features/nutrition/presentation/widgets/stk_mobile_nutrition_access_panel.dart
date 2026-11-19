import 'package:core/features/nutrition/application/nutrition_access_state.dart';
import 'package:core/features/nutrition/data/nutrition_adult_access_service.dart';
import 'package:flutter/material.dart';

/// A compact, mobile-only explanation of what the user can do NOW.
///
/// No unavailable verification flow is linked from here. Backend outages and
/// real unverified results remain different, while both fail closed.
class StkMobileNutritionAccessPanel extends StatelessWidget {
  const StkMobileNutritionAccessPanel({
    super.key,
    required this.access,
    required this.check,
    this.onRetry,
  });

  final NutritionAccessState access;
  final NutritionAdultCheck check;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final typography = Theme.of(context).textTheme;

    final isMinor = access == NutritionAccessState.minor;
    final checking = !isMinor && check == NutritionAdultCheck.checking;
    final showNetworkError =
        !isMinor && check == NutritionAdultCheck.unavailable;
    final signedOut = !isMinor && check == NutritionAdultCheck.signedOut;
    final ageUnknown = access == NutritionAccessState.ageUnknown &&
        !checking && !showNetworkError && !signedOut;

    final title = isMinor
        ? 'Nutrición para tu etapa'
        : ageUnknown
            ? 'Alimentación y bienestar'
            : checking
                ? 'Comprobando tu plan'
                : showNetworkError
                    ? 'No se pudo comprobar el acceso'
                    : signedOut
                        ? 'Plan disponible con tu cuenta'
                        : 'Plan calórico pendiente de acceso';

    final subtitle = isMinor
        ? 'Explora comidas y hábitos sin metas calóricas.'
        : ageUnknown
            ? 'Explora Food Vision sin un objetivo numérico.'
            : checking
                ? 'Revisando el estado de tu cuenta.'
                : showNetworkError
                    ? 'Comprueba tu conexión e inténtalo otra vez.'
                    : signedOut
                        ? 'Inicia sesión para consultar tu plan.'
                        : 'Food Vision sigue disponible sin cifras.';

    final detail = isMinor
        ? 'Durante la adolescencia ofrecemos información sobre alimentos, '
            'energía, crecimiento y recuperación sin objetivos de restricción.'
        : ageUnknown
            ? 'Puedes reconocer alimentos con Food Vision. Si indicas tu '
                'fecha de nacimiento, podremos adaptar el contenido; esa '
                'fecha no demuestra mayoría de edad.'
            : checking
                ? 'Estamos consultando el acceso vigente. Mientras tanto '
                    'los cálculos numéricos permanecerán ocultos.'
                : showNetworkError
                    ? 'No obtuvimos una respuesta válida. Esto no significa '
                        'que hayas perdido el acceso. Reintenta cuando '
                        'recuperes la conexión; las cifras quedan protegidas.'
                    : signedOut
                        ? 'Puedes usar la orientación descriptiva. Los '
                            'cálculos personalizados requieren una cuenta '
                            'con autorización vigente.'
                        : 'Los cálculos requieren un permiso activo del servidor. '
                            'Ni cambiar tu fecha de nacimiento ni aceptar '
                            'condiciones concede ese permiso. Mientras tanto, '
                            'puedes reconocer alimentos sin cifras.';

    return Container(
      key: const ValueKey('stk_mobile_nutrition_access'),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (checking)
                SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.primary,
                  ),
                )
              else
                Icon(isMinor ? Icons.spa_outlined : Icons.info_outline,
                    size: 20, color: colors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: typography.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: typography.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        )),
                  ],
                ),
              ),
              IconButton(
                key: const ValueKey('stk_nutrition_access_info'),
                tooltip: 'Información sobre tu plan',
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  builder: (sheetContext) => SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 10, 22, 26),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: Theme.of(sheetContext)
                              .textTheme.titleLarge),
                          const SizedBox(height: 10),
                          Text(detail),
                        ],
                      ),
                    ),
                  ),
                ),
                icon: const Icon(Icons.help_outline_rounded),
              ),
            ],
          ),
          if (showNetworkError && onRetry != null) ...[
            const SizedBox(height: 6),
            TextButton.icon(
              key: const ValueKey('stk_nutrition_access_retry'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reintentar'),
            ),
          ],
        ],
      ),
    );
  }
}
