import 'package:flutter/material.dart';
import 'package:core/core/constants/muscle_taxonomy_v1.dart';
import 'package:core/features/exercises/application/muscle_hierarchy_browser.dart';

/// Returns an anatomy node ID on selection, '' to clear, or null on dismissal.
/// All operations are read-only; historical labels are never reclassified.
class MuscleHierarchyPicker extends StatefulWidget {
  const MuscleHierarchyPicker({super.key});

  @override
  State<MuscleHierarchyPicker> createState() => _MuscleHierarchyPickerState();
}

class _MuscleHierarchyPickerState extends State<MuscleHierarchyPicker> {
  String? _parentId;

  @override
  Widget build(BuildContext context) {
    final parent = MuscleTaxonomyV1.byId[_parentId];
    final children = MuscleHierarchyBrowser.childrenOf(_parentId);
    final trail = MuscleHierarchyBrowser.pathTo(_parentId);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_parentId != null)
                IconButton(
                  key: const Key('anatomy_back'),
                  tooltip: 'Volver al grupo anterior',
                  onPressed: () => setState(
                    () => _parentId = parent?.parentId,
                  ),
                  icon: const Icon(Icons.arrow_back),
                ),
              Expanded(
                child: Text(
                  parent?.labelEs ?? 'Explorar músculos',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              TextButton(
                key: const Key('anatomy_clear'),
                onPressed: () => Navigator.of(context).pop(''),
                child: const Text('Todos'),
              ),
            ],
          ),
          if (trail.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                trail.map((node) => node.labelEs).join(' › '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
          const Text(
            'Toca una fila para filtrar ejercicios. Usa la flecha para '
            'explorar los subgrupos. Las porciones son énfasis, no músculos '
            'independientes.',
          ),
          const SizedBox(height: 8),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: children.length,
              itemBuilder: (context, index) {
                final node = children[index];
                final hasChildren =
                    MuscleHierarchyBrowser.childrenOf(node.id).isNotEmpty;
                final kind = node.isCategory
                    ? 'Categoría'
                    : node.isRegionalEmphasis
                        ? 'Énfasis regional'
                        : 'Músculo';
                return ListTile(
                  key: Key('anatomy_select_${node.id}'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: Text(
                    node.labelEs,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(kind),
                  onTap: () => Navigator.of(context).pop(node.id),
                  trailing: hasChildren
                      ? IconButton(
                          key: Key('anatomy_expand_${node.id}'),
                          tooltip: 'Explorar ${node.labelEs}',
                          onPressed: () =>
                              setState(() => _parentId = node.id),
                          icon: const Icon(Icons.chevron_right),
                        )
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
