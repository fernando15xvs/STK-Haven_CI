import 'package:core/domain/models/settings_state.dart';
import 'package:core/features/faith/data/bible_public_domain_source.dart';
import 'package:core/features/profile/presentation/providers/settings_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlatformSettingsPage extends ConsumerWidget {
  const PlatformSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('App y dispositivo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: 'Rendimiento y accesibilidad',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.speed_outlined),
                title: const Text('Modo rendimiento'),
                subtitle: Text(
                  switch (settings.performanceMode) {
                    PerformanceMode.automatic =>
                      'Equilibra presentación, batería y preferencias del sistema.',
                    PerformanceMode.quality =>
                      'Prioriza la presentación visual cuando el dispositivo puede sostenerla.',
                    PerformanceMode.savings =>
                      'Reduce animaciones y coste gráfico antes de reducir funcionalidad.',
                  },
                ),
                trailing: DropdownButton<PerformanceMode>(
                  value: settings.performanceMode,
                  items: PerformanceMode.values
                      .map(
                        (mode) => DropdownMenuItem(
                          value: mode,
                          child: Text(mode.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) notifier.setPerformanceMode(value);
                  },
                ),
              ),
              const Divider(height: 1),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Reducir movimiento'),
                subtitle: const Text(
                  'Reduce transiciones y efectos para una interfaz más estable.',
                ),
                value: settings.reduceMotion,
                onChanged: notifier.setReduceMotion,
              ),
              const Divider(height: 1),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.accessibility_new_outlined),
                title: Text('Preferencias del sistema'),
                subtitle: Text(
                  'STK Haven también respeta las preferencias de accesibilidad del sistema operativo.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Funciones del dispositivo',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('Notificaciones'),
                subtitle: Text(
                  kIsWeb
                      ? 'Los recordatorios locales están disponibles en Android y iOS.'
                      : 'Las horas se programan usando la zona horaria actual del dispositivo.',
                ),
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.directions_walk_outlined),
                title: const Text('Movimiento y pasos'),
                subtitle: Text(
                  kIsWeb
                      ? 'El contador de pasos está disponible en la app móvil.'
                      : 'STK Haven usa el contador nativo del dispositivo y actualiza el progreso automáticamente.',
                ),
              ),
              const Divider(height: 1),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.storage_outlined),
                title: Text('Datos locales'),
                subtitle: Text(
                  'La app es local-first. Las copias y la sincronización se administran desde “Datos y sincronización”.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Acerca de',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.menu_book_outlined),
                title: const Text('Contenido bíblico'),
                subtitle: const Text(
                  '${BiblePublicDomainSource.translationName} · '
                  '${BiblePublicDomainSource.licenseName}',
                ),
                trailing: const Icon(Icons.info_outline),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Fuente del contenido bíblico'),
                    content: const Text(
                      'Traducción: ${BiblePublicDomainSource.translationName}\n'
                      'Fuente: ${BiblePublicDomainSource.sourceName}\n'
                      'Snapshot: ${BiblePublicDomainSource.sourceTag}\n'
                      'Licencia: ${BiblePublicDomainSource.licenseName}\n\n'
                      'La Biblia solo se prepara cuando el módulo Fe está habilitado.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cerrar'),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined),
                title: const Text('Licencias de software'),
                subtitle: const Text(
                  'Consulta los avisos de Flutter y de las dependencias incluidas.',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'STK Haven',
                  applicationVersion: '1.0.0',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}
