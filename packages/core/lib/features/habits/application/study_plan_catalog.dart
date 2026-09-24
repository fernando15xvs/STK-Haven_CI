import 'package:core/domain/models/study_plan.dart';

class StudyPlanCatalog {
  const StudyPlanCatalog._();

  static const List<StudyPlanDefinition> plans = [
    StudyPlanDefinition(
      id: 'john_7_sessions',
      title: 'Evangelio de Juan · 7 sesiones',
      description:
          'Un recorrido breve por siete capítulos. El plan guarda referencias, no copia el texto bíblico.',
      steps: [
        StudyPlanStep(index: 0, title: 'El comienzo', reference: 'Juan 1'),
        StudyPlanStep(index: 1, title: 'Nuevo nacimiento', reference: 'Juan 3'),
        StudyPlanStep(index: 2, title: 'Pan de vida', reference: 'Juan 6'),
        StudyPlanStep(index: 3, title: 'El buen pastor', reference: 'Juan 10'),
        StudyPlanStep(index: 4, title: 'Servicio y amor', reference: 'Juan 13'),
        StudyPlanStep(index: 5, title: 'Permanecer', reference: 'Juan 15'),
        StudyPlanStep(index: 6, title: 'Cierre y propósito', reference: 'Juan 20'),
      ],
    ),
    StudyPlanDefinition(
      id: 'psalms_7_sessions',
      title: 'Salmos · 7 sesiones',
      description: 'Siete lecturas seleccionadas para reflexión personal.',
      steps: [
        StudyPlanStep(index: 0, title: 'Camino', reference: 'Salmos 1'),
        StudyPlanStep(index: 1, title: 'Confianza', reference: 'Salmos 23'),
        StudyPlanStep(index: 2, title: 'Espera', reference: 'Salmos 27'),
        StudyPlanStep(index: 3, title: 'Refugio', reference: 'Salmos 46'),
        StudyPlanStep(index: 4, title: 'Gratitud', reference: 'Salmos 100'),
        StudyPlanStep(index: 5, title: 'Ayuda', reference: 'Salmos 121'),
        StudyPlanStep(index: 6, title: 'Examen personal', reference: 'Salmos 139'),
      ],
    ),
    StudyPlanDefinition(
      id: 'proverbs_7_sessions',
      title: 'Proverbios · 7 sesiones',
      description: 'Siete capítulos enfocados en sabiduría y decisiones.',
      steps: [
        StudyPlanStep(index: 0, title: 'Sabiduría', reference: 'Proverbios 1'),
        StudyPlanStep(index: 1, title: 'Confianza', reference: 'Proverbios 3'),
        StudyPlanStep(index: 2, title: 'Palabras', reference: 'Proverbios 12'),
        StudyPlanStep(index: 3, title: 'Disciplina', reference: 'Proverbios 13'),
        StudyPlanStep(index: 4, title: 'Decisiones', reference: 'Proverbios 16'),
        StudyPlanStep(index: 5, title: 'Amistad', reference: 'Proverbios 17'),
        StudyPlanStep(index: 6, title: 'Carácter', reference: 'Proverbios 31'),
      ],
    ),
  ];

  static StudyPlanDefinition? byId(String id) {
    for (final plan in plans) {
      if (plan.id == id) return plan;
    }
    return null;
  }
}
