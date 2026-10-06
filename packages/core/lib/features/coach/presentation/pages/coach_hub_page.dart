import 'package:core/features/coach/presentation/pages/coach_connections_page.dart';
import 'package:core/features/coach_pro/application/coach_pro_entitlement_provider.dart';
import 'package:core/features/coach_pro/presentation/coach_pro_dashboard_page.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:core/features/profile/presentation/providers/user_experience_profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CoachHubPage extends ConsumerWidget {
  const CoachHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(appIdentityProvider);
    final profile = ref.watch(userExperienceProfileProvider).value;
    final entitlement = ref.watch(coachProEntitlementProvider);
    final isCoach = profile?.isCoach ?? false;
    final hasCoachPro = entitlement.value?.accessActive ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Coach')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Espacio profesional',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      identity.signedIn
                          ? 'Gestiona clientes y herramientas profesionales desde un solo lugar.'
                          : 'Inicia sesión con una cuenta permanente para usar las funciones Coach.',
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StatusChip(
                          label: isCoach
                              ? 'Modo Coach activo'
                              : 'Modo Coach no activo',
                          active: isCoach,
                        ),
                        _StatusChip(
                          label: hasCoachPro
                              ? 'Coach Pro activo'
                              : 'Coach Pro no activo',
                          active: hasCoachPro,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'TRABAJO PROFESIONAL',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
            ),
            const SizedBox(height: 10),
            _HubCard(
              icon: Icons.groups_2_outlined,
              title: 'Clientes y conexiones',
              subtitle:
                  'Invitaciones, relaciones, permisos y acceso a fichas vinculadas.',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CoachConnectionsPage(
                    professionalOnly: true,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _HubCard(
              icon: Icons.dashboard_outlined,
              title: 'Coach Pro',
              subtitle:
                  'Cartera profesional, seguimiento, programas, tareas y revisiones.',
              trailingText: entitlement.when(
                loading: () => 'Consultando…',
                error: (_, _) => 'No disponible',
                data: (value) => value?.accessActive == true
                    ? '${value!.activeClientCount}/${value.clientLimit} clientes'
                    : 'Sin acceso activo',
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CoachProDashboardPage(),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Los permisos de cada cliente siguen siendo la autoridad. '
                  'Abrir este espacio no concede acceso adicional a información compartida.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  const _HubCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailingText,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailingText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 10,
        ),
        leading: Icon(
          icon,
          size: 30,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(subtitle),
            if (trailingText != null) ...[
              const SizedBox(height: 6),
              Text(
                trailingText!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.active,
  });

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(
        active ? Icons.check_circle_outline : Icons.info_outline,
        size: 18,
      ),
      label: Text(label),
    );
  }
}
