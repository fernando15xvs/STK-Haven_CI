import 'package:core/domain/models/study_resource.dart';
import 'package:core/features/faith/data/bible_public_domain_source.dart';

class StudyResourceCatalog {
  const StudyResourceCatalog._();

  static const List<StudyResource> resources = <StudyResource>[
    StudyResource(
      id: 'rv1909',
      title: BiblePublicDomainSource.translationName,
      author: 'Traducción histórica',
      kind: StudyResourceKind.bible,
      topics: <String>['Biblia', 'lectura', 'estudio', 'fe'],
      source: BiblePublicDomainSource.sourceName,
      licenseName: BiblePublicDomainSource.licenseName,
      licenseUrl: BiblePublicDomainSource.licenseUrl,
      textBundled: false,
      routeHint: 'bible',
    ),
    StudyResource(
      id: 'personal_notes',
      title: 'Mis notas y reflexiones',
      author: 'Usuario',
      kind: StudyResourceKind.personalNotes,
      topics: <String>['notas', 'reflexión', 'personal'],
      source: 'Datos locales del usuario',
      licenseName: 'Contenido propio del usuario',
      textBundled: false,
      routeHint: 'reflections',
    ),
    StudyResource(
      id: 'stk_study_plans',
      title: 'Planes de estudio STK Haven',
      author: 'STK Haven',
      kind: StudyResourceKind.stkPlan,
      topics: <String>['planes', 'hábitos', 'lectura', 'estudio'],
      source: 'STK Haven',
      licenseName: 'Contenido original de STK Haven',
      textBundled: false,
      routeHint: 'plans',
    ),
  ];

  static List<StudyResource> search(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return List<StudyResource>.unmodifiable(resources);
    return resources.where((resource) {
      final haystack = <String>[
        resource.title,
        resource.author,
        resource.source,
        resource.licenseName,
        ...resource.topics,
      ].join(' ').toLowerCase();
      return haystack.contains(normalized);
    }).toList(growable: false);
  }

  static StudyResource? byId(String id) {
    for (final resource in resources) {
      if (resource.id == id) return resource;
    }
    return null;
  }
}
