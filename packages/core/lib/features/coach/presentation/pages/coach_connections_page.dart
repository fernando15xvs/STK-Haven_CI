import 'package:core/domain/models/coach_relationship.dart';
import 'package:core/domain/models/user_experience_profile.dart';
import 'package:core/features/coach/application/coach_client_provider.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:core/features/profile/presentation/providers/user_experience_profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CoachConnectionsPage extends ConsumerStatefulWidget {
  const CoachConnectionsPage({super.key});

  @override
  ConsumerState<CoachConnectionsPage> createState() =>
      _CoachConnectionsPageState();
}

class _CoachConnectionsPageState
    extends ConsumerState<CoachConnectionsPage> {
  final TextEditingController _codeController = TextEditingController();
  bool _requestedInitialLoad = false;
  Set<CoachPermission> _invitePermissions = const {
    CoachPermission.viewWorkouts,
    CoachPermission.viewProgress,
    CoachPermission.assignPrograms,
    CoachPermission.comment,
  };

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _scheduleInitialLoad(bool signedIn) {
    if (!signedIn || _requestedInitialLoad) return;
    _requestedInitialLoad = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(coachClientProvider.notifier).refreshRelationships();
    });
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(appIdentityProvider);
    final profile = ref.watch(userExperienceProfileProvider).value;
    final coachState = ref.watch(coachClientProvider);
    final userId = identity.userId;
    final isCoach =
        profile?.capabilities.contains(UserCapability.coach) ?? false;

    _scheduleInitialLoad(identity.signedIn);

    ref.listen(coachClientProvider, (previous, next) {
      if (next.message == null ||
          next.message == previous?.message) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(next.message!)),
      );
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Coach & Clientes')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: RefreshIndicator(
              onRefresh: () async {
                await ref
                    .read(coachClientProvider.notifier)
                    .refreshRelationships();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
                children: [
                  _AccountCard(
                    signedIn: identity.signedIn,
                    email: identity.email,
                    isCoach: isCoach,
                  ),
                  if (!identity.signedIn) ...[
                    const SizedBox(height: 16),
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Text(
                          'Las funciones Coach/Cliente requieren una cuenta '
                          'permanente. Inicia sesión desde Perfil > Copia en la '
                          'nube y vuelve aquí.',
                        ),
                      ),
                    ),
                  ] else ...[
                    if (isCoach) ...[
                      const SizedBox(height: 24),
                      _SectionHeader(
                        title: 'Invitar cliente',
                        subtitle:
                            'El código expira y la app guarda solo su hash.',
                      ),
                      const SizedBox(height: 10),
                      _InviteBuilder(
                        selected: _invitePermissions,
                        busy: coachState.busy,
                        onChanged: (permissions) {
                          setState(() => _invitePermissions = permissions);
                        },
                        onCreate: () => ref
                            .read(coachClientProvider.notifier)
                            .createInvitation(
                              permissions: _invitePermissions,
                            ),
                      ),
                      if (coachState.invitationCode != null) ...[
                        const SizedBox(height: 10),
                        _InvitationCodeCard(
                          code: coachState.invitationCode!,
                        ),
                      ],
                    ],
                    const SizedBox(height: 24),
                    const _SectionHeader(
                      title: 'Vincular entrenador',
                      subtitle:
                          'Revisa quién invita y qué permisos pide antes de aceptar.',
                    ),
                    const SizedBox(height: 10),
                    _AcceptInvitationCard(
                      controller: _codeController,
                      busy: coachState.busy,
                      onPreview: _previewInvitation,
                    ),
                    const SizedBox(height: 24),
                    _SectionHeader(
                      title: isCoach
                          ? 'Mis relaciones'
                          : 'Mi entrenador',
                      subtitle:
                          'Solo aparecen cuentas vinculadas a tu usuario.',
                    ),
                    const SizedBox(height: 10),
                    if (coachState.operation ==
                            CoachClientOperation.loading &&
                        coachState.relationships.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (coachState.relationships.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'Todavía no existen relaciones vinculadas.',
                          ),
                        ),
                      )
                    else
                      for (final relationship
                          in coachState.relationships) ...[
                        _RelationshipCard(
                          relationship: relationship,
                          currentUserId: userId,
                          busy: coachState.busy,
                          onPermissions: relationship.isClient(userId) &&
                                  relationship.isActive
                              ? () => _editPermissions(relationship)
                              : null,
                          onRevoke: relationship.isActive
                              ? () => _confirmRevoke(relationship)
                              : null,
                        ),
                        const SizedBox(height: 10),
                      ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _previewInvitation() async {
    final preview = await ref
        .read(coachClientProvider.notifier)
        .previewInvitation(_codeController.text);
    if (!mounted || preview == null) return;

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revisar invitación'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                preview.coachDisplayName?.trim().isNotEmpty == true
                    ? preview.coachDisplayName!
                    : 'Entrenador',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'La invitación vence el '
                '${_dateTimeLabel(preview.expiresAt.toLocal())}.',
              ),
              const SizedBox(height: 18),
              const Text(
                'Permisos solicitados',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (preview.permissions.isEmpty)
                const Text('Sin permisos de datos adicionales.')
              else
                ...preview.permissions.map(
                  (permission) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      children: [
                        const Icon(Icons.check_rounded, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_permissionLabel(permission))),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              Text(
                'Podrás cambiar estos permisos o revocar al entrenador después.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Aceptar y vincular'),
          ),
        ],
      ),
    );

    if (accepted != true || !mounted) return;
    final success = await ref
        .read(coachClientProvider.notifier)
        .acceptInvitation(_codeController.text);
    if (success && mounted) {
      _codeController.clear();
    }
  }

  Future<void> _editPermissions(
    CoachClientRelationship relationship,
  ) async {
    var draft = Set<CoachPermission>.from(relationship.permissions);

    final selected = await showDialog<Set<CoachPermission>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Qué puede ver mi entrenador'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final permission in CoachPermission.values)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: draft.contains(permission),
                      title: Text(_permissionLabel(permission)),
                      onChanged: (enabled) {
                        setDialogState(() {
                          final next = Set<CoachPermission>.from(draft);
                          if (enabled) {
                            next.add(permission);
                          } else {
                            next.remove(permission);
                          }
                          draft = next;
                        });
                      },
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, draft),
              child: const Text('Guardar permisos'),
            ),
          ],
        ),
      ),
    );

    if (selected == null) return;
    await ref.read(coachClientProvider.notifier).setPermissions(
          relationshipId: relationship.id,
          permissions: selected,
        );
  }

  Future<void> _confirmRevoke(
    CoachClientRelationship relationship,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revocar acceso'),
        content: const Text(
          'La relación dejará de dar acceso inmediatamente. '
          'Tu historial propio no se elimina.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Revocar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref
        .read(coachClientProvider.notifier)
        .revokeRelationship(relationship.id);
  }
}

class _AccountCard extends StatelessWidget {
  final bool signedIn;
  final String? email;
  final bool isCoach;

  const _AccountCard({
    required this.signedIn,
    required this.email,
    required this.isCoach,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(
              signedIn
                  ? Icons.verified_user_outlined
                  : Icons.person_off_outlined,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    signedIn ? 'Cuenta permanente' : 'Modo local',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    signedIn
                        ? [
                            email ?? 'Sesión activa',
                            if (isCoach) 'Modo entrenador activo',
                          ].join(' · ')
                        : 'Coach/Cliente permanece desactivado.',
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

class _InviteBuilder extends StatelessWidget {
  final Set<CoachPermission> selected;
  final bool busy;
  final ValueChanged<Set<CoachPermission>> onChanged;
  final VoidCallback onCreate;

  const _InviteBuilder({
    required this.selected,
    required this.busy,
    required this.onChanged,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Permisos que propones',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final permission in CoachPermission.values)
                  FilterChip(
                    label: Text(_permissionLabel(permission)),
                    selected: selected.contains(permission),
                    onSelected: busy
                        ? null
                        : (enabled) {
                            final next =
                                Set<CoachPermission>.from(selected);
                            if (enabled) {
                              next.add(permission);
                            } else {
                              next.remove(permission);
                            }
                            onChanged(next);
                          },
                  ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: busy ? null : onCreate,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Crear código de invitación'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvitationCodeCard extends StatelessWidget {
  final String code;

  const _InvitationCodeCard({required this.code});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Código de invitación',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            SelectableText(
              code,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Compártelo solo con la persona que quieres vincular. '
              'El código real no se guarda en la base de datos.',
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Código copiado.')),
                );
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copiar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AcceptInvitationCard extends StatelessWidget {
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onPreview;

  const _AcceptInvitationCard({
    required this.controller,
    required this.busy,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !busy,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Código de invitación',
                  hintText: 'Ej. A1B2C3D4E5F6G7H8',
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: busy ? null : onPreview,
              child: const Text('Revisar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RelationshipCard extends StatelessWidget {
  final CoachClientRelationship relationship;
  final String? currentUserId;
  final bool busy;
  final VoidCallback? onPermissions;
  final VoidCallback? onRevoke;

  const _RelationshipCard({
    required this.relationship,
    required this.currentUserId,
    required this.busy,
    this.onPermissions,
    this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    final asCoach = relationship.isCoach(currentUserId);
    final name = relationship.counterpartDisplayName?.trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  asCoach
                      ? Icons.person_outline
                      : Icons.sports_outlined,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name?.isNotEmpty == true
                        ? name!
                        : (asCoach ? 'Cliente vinculado' : 'Entrenador vinculado'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Chip(label: Text(_statusLabel(relationship.status))),
              ],
            ),
            const SizedBox(height: 8),
            Text(asCoach ? 'Tu rol: entrenador' : 'Tu rol: cliente'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: relationship.permissions
                  .map(
                    (permission) => Chip(
                      label: Text(_permissionLabel(permission)),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(growable: false),
            ),
            if (onPermissions != null || onRevoke != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (onPermissions != null)
                    OutlinedButton.icon(
                      onPressed: busy ? null : onPermissions,
                      icon: const Icon(Icons.manage_accounts_outlined),
                      label: const Text('Permisos'),
                    ),
                  if (onRevoke != null)
                    TextButton.icon(
                      onPressed: busy ? null : onRevoke,
                      icon: const Icon(Icons.link_off_rounded),
                      label: const Text('Revocar'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

String _permissionLabel(CoachPermission permission) => switch (permission) {
      CoachPermission.viewWorkouts => 'Ver entrenamientos',
      CoachPermission.viewProgress => 'Ver progreso',
      CoachPermission.viewMeasurements => 'Ver medidas',
      CoachPermission.assignPrograms => 'Asignar programas',
      CoachPermission.viewCheckins => 'Ver check-ins',
      CoachPermission.viewNutrition => 'Ver alimentación',
      CoachPermission.comment => 'Comentar',
    };

String _statusLabel(CoachRelationshipStatus status) => switch (status) {
      CoachRelationshipStatus.active => 'Activa',
      CoachRelationshipStatus.paused => 'Pausada',
      CoachRelationshipStatus.revoked => 'Revocada',
    };

String _dateTimeLabel(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month/${value.year} $hour:$minute';
}
