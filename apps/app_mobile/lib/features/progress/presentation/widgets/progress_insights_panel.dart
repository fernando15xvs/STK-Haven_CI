import 'package:core/features/progress/application/progress_insight_calculator.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// No new tab: these observations only appear inside Progreso > Resumen.
/// Dismissal IDs are local, scoped to filter/evidence and never sent to cloud.
class ProgressInsightsPanel extends StatefulWidget {
  const ProgressInsightsPanel({super.key, required this.insights});

  final List<ProgressInsight> insights;

  @override
  State<ProgressInsightsPanel> createState() => _ProgressInsightsPanelState();
}

class _ProgressInsightsPanelState extends State<ProgressInsightsPanel> {
  static const _dismissedKey = 'progress_insights.dismissed.v1';
  SharedPreferences? _prefs;
  Set<String> _dismissed = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _prefs = prefs;
        _dismissed = prefs.getStringList(_dismissedKey)?.toSet() ?? {};
        _loading = false;
      });
    } catch (_) {
      // Storage failure should not hide observations or crash Progreso.
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _dismiss(String id) async {
    setState(() => _dismissed = {..._dismissed, id});
    // Cap storage growth; keep only recent dismissed evidence identities.
    final current = _dismissed.toList();
    if (current.length > 80) {
      _dismissed = current.skip(current.length - 80).toSet();
    }
    await _prefs?.setStringList(_dismissedKey, _dismissed.toList());
  }

  Future<void> _restore() async {
    setState(() => _dismissed = {});
    await _prefs?.remove(_dismissedKey);
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.insights
        .where((item) => !_dismissed.contains(item.id))
        .toList(growable: false);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('OBSERVACIONES DEL ENTRENAMIENTO',
            style: theme.textTheme.titleSmall),
        const SizedBox(height: 5),
        Text('Lecturas automáticas de tus registros. No son diagnósticos '
            'ni recomendaciones obligatorias.',
            style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(14),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (widget.insights.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'Todavía no hay evidencia suficiente en este período '
              'para generar observaciones fiables.',
            ),
          )
        else if (visible.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text('Has descartado las observaciones disponibles.'),
          )
        else
          for (final insight in visible)
            Padding(
              key: ValueKey('insight_${insight.id}'),
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            switch (insight.type) {
                              ProgressInsightType.consistency =>
                                Icons.event_available_outlined,
                              ProgressInsightType.exercise =>
                                Icons.show_chart_outlined,
                              ProgressInsightType.muscle =>
                                Icons.layers_outlined,
                            },
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(insight.title,
                              style: theme.textTheme.titleSmall)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(insight.explanation),
                      const SizedBox(height: 8),
                      Text('Evidencia: ${insight.evidence}',
                          style: theme.textTheme.bodySmall),
                      const SizedBox(height: 3),
                      Text(insight.periodLabel,
                          style: theme.textTheme.bodySmall),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          key: ValueKey('dismiss_${insight.id}'),
                          onPressed: () => _dismiss(insight.id),
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Descartar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        if (!_loading && _dismissed.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const ValueKey('restore_progress_insights'),
              onPressed: _restore,
              child: const Text('Restablecer observaciones descartadas'),
            ),
          ),
      ],
    );
  }
}
