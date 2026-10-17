import 'package:core/domain/models/verse.dart';
import 'package:core/features/faith/data/bible_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An editorial note is NOT a verse or a translation of Scripture.
class ContextualPassage {
  final String book;
  final int chapter;
  final int start;
  final int end;
  final String meaning;
  final String question;
  final String closingThought;

  const ContextualPassage(this.book, this.chapter, this.start, this.end,
      this.meaning, this.question, this.closingThought);

  String get key => '$book-$chapter-$start-$end';
}

class ContextualPassageCatalog {
  const ContextualPassageCatalog._();

  /// Short complete units, instead of selecting a verse out of context.
  static const passages = <ContextualPassage>[
    ContextualPassage('Salmos', 23, 1, 3,
      'El salmista expresa su confianza en el cuidado y la guía de Dios, incluso en la necesidad de reposo.',
      '¿Dónde necesitas descansar y aceptar ayuda hoy?',
      'El cuidado y el descanso también tienen un lugar en tu camino.'),
    ContextualPassage('Mateo', 11, 28, 30,
      'Jesús invita a las personas cansadas y cargadas a acercarse a él y aprender de su mansedumbre.',
      '¿Qué carga puedes reconocer sin exigirte más?',
      'No todo se resuelve aumentando la exigencia; también importa descansar.'),
    ContextualPassage('Filipenses', 4, 6, 7,
      'Pablo anima a presentar las preocupaciones a Dios en oración, con gratitud, y habla de su paz.',
      '¿Qué te gustaría agradecer hoy?',
      'Reconoce lo que hiciste con gratitud, sin convertir el progreso en una presión.'),
    ContextualPassage('Eclesiastés', 3, 1, 3,
      'El autor recuerda que la vida tiene diferentes momentos y que no todas las etapas son iguales.',
      '¿Qué necesita esta etapa de tu vida?',
      'Cada etapa tiene su propio ritmo; recomenzar también forma parte del camino.'),
    ContextualPassage('Romanos', 12, 9, 12,
      'Pablo describe una vida guiada por el amor sincero, la esperanza, la paciencia y la oración.',
      '¿Qué gesto de paciencia puedes practicar contigo o con alguien más?',
      'La constancia puede convivir con la paciencia y el cuidado.'),
    ContextualPassage('Lamentaciones', 3, 22, 24,
      'En un libro que reconoce el sufrimiento, estas líneas recuerdan la misericordia y la esperanza en Dios.',
      '¿Qué pequeño comienzo puedes valorar hoy?',
      'Volver después de una pausa también puede ser un comienzo esperanzador.'),
    ContextualPassage('Proverbios', 3, 5, 6,
      'Este consejo llama a confiar en Dios en lugar de depender exclusivamente del propio entendimiento.',
      '¿En qué aspecto te vendría bien pedir orientación?',
      'No tienes que tener todo resuelto para avanzar.'),
    ContextualPassage('Gálatas', 6, 9, 10,
      'Pablo anima a perseverar en hacer el bien y a aprovechar oportunidades para cuidar a otros.',
      '¿Qué acto de bien puedes sostener con paciencia?',
      'La constancia importa, pero no mide tu valor como persona.'),
    ContextualPassage('Santiago', 1, 2, 4,
      'Santiago habla de la perseverancia ante las pruebas de la fe; no de ignorar límites físicos.',
      '¿Qué has aprendido de una dificultad reciente?',
      'Puedes aprender de las dificultades sin exigirte perfección.'),
    ContextualPassage('1 Tesalonicenses', 5, 16, 18,
      'Pablo anima a una actitud de oración y gratitud en la vida cotidiana.',
      '¿Por qué puedes dar gracias hoy?',
      'Celebra el tiempo que pudiste dedicarte hoy.'),
  ];

  /// Estas selecciones son temáticas; no reemplazan el pasaje fijo de Inicio.
  /// La rotación diaria original de [passages] no se modifica.
  static const _moodSpecific = <String, List<ContextualPassage>>{
    'Triste': [
      ContextualPassage('Salmos', 34, 17, 19,
        'El salmo expresa que Dios escucha a quienes atraviesan aflicciones.',
        '¿Qué emoción necesitas reconocer y expresar hoy?',
        'Reconocer una dificultad también es parte del camino.'),
      passages[5],
    ],
    'Agradecido': [
      ContextualPassage('Salmos', 100, 1, 3,
        'El salmo invita a expresar gratitud y alabanza.',
        '¿Qué pequeño gesto o momento agradeces hoy?',
        'Puedes valorar tanto los grandes como los pequeños momentos.'),
      passages[9],
    ],
    'Alegre': [
      ContextualPassage('Salmos', 30, 4, 5,
        'El salmista describe el paso de la tristeza hacia la alegría.',
        '¿Qué momento de alegría te gustaría recordar hoy?',
        'Disfrutar de los buenos momentos también merece su espacio.'),
      ContextualPassage('Salmos', 150, 1, 3,
        'El salmo invita a celebrar y alabar a Dios.',
        '¿Cómo te gustaría compartir tu alegría?',
        'La gratitud y la alegría pueden expresarse de muchas maneras.'),
    ],
    'Ansioso': [
      ContextualPassage('1 Pedro', 5, 6, 7,
        'El pasaje invita a poner las preocupaciones en manos de Dios.',
        '¿Qué preocupación te gustaría expresar con sinceridad?',
        'Puedes reconocer tus preocupaciones sin tener que resolverlas ahora.'),
      passages[2],
    ],
    'Esperanza': [
      ContextualPassage('Josué', 1, 7, 9,
        'El llamado a Josué combina ánimo, fidelidad y confianza.',
        '¿Qué te anima a seguir adelante en esta etapa?',
        'Avanzar con esperanza también admite dudas y pausas.'),
      passages[4],
    ],
    'Enojado': [
      ContextualPassage('Efesios', 4, 26, 27,
        'El pasaje distingue la emoción del enojo de las acciones que pueden hacer daño.',
        '¿Qué necesitas expresar de forma constructiva?',
        'Sentir enojo no tiene que definir tu siguiente acción.'),
      passages[7],
    ],
    'Cansado': [
      ContextualPassage('Isaías', 40, 29, 31,
        'El profeta habla de fortaleza y esperanza para quienes sienten cansancio.',
        '¿Qué forma de descanso necesitas hoy?',
        'Descansar no disminuye el valor de lo que haces.'),
      passages[1],
    ],
  };

  static const moodOptions = <String>[
    'General', 'Triste', 'Agradecido', 'Alegre',
    'Ansioso', 'Esperanza', 'Enojado', 'Cansado',
  ];

  /// Selección reproducible durante el día y distinta del mensaje fijo
  /// cuando al menos otro pasaje temático esté disponible.
  static List<ContextualPassage> forMood(
    String mood,
    DateTime day, {
    String? avoidKey,
  }) {
    final pool = _moodSpecific[mood];
    if (pool == null || pool.isEmpty) return const [];
    final offset = DateTime(day.year, day.month, day.day)
        .difference(DateTime(2024, 1, 1)).inDays;
    final index = offset % pool.length;
    final ordered = [
      for (var i = 0; i < pool.length; i++)
        pool[(index + i) % pool.length],
    ];
    if (avoidKey == null) return ordered;
    return [
      ...ordered.where((p) => p.key != avoidKey),
      ...ordered.where((p) => p.key == avoidKey),
    ];
  }

  static Future<Verse?> mood(
    BibleRepository repository, {
    required String mood,
    required DateTime day,
    Verse? dailyVerse,
  }) async {
    final avoidKey = dailyVerse == null
        ? null
        : '${dailyVerse.book}-${dailyVerse.chapter}-'
            '${dailyVerse.verse}-${dailyVerse.endVerse ?? dailyVerse.verse}';
    for (final passage in forMood(mood, day, avoidKey: avoidKey)) {
      final resolved = await resolve(repository, passage);
      if (resolved != null) return resolved;
    }
    return null;
  }

  static ContextualPassage forDay(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final offset = day.difference(DateTime(2024, 1, 1)).inDays;
    return passages[offset % passages.length];
  }

  static List<ContextualPassage> forWorkoutTheme(String theme) {
    switch (theme) {
      case 'return':
        return [passages[5], passages[3], passages[6], passages[0]];
      case 'incomplete':
        return [passages[0], passages[1], passages[3], passages[8]];
      default:
        return [passages[9], passages[2], passages[4], passages[7]];
    }
  }

  /// Uses the existing public-domain Bible library, not hard-coded Scripture.
  static Future<Verse?> resolve(
    BibleRepository repository,
    ContextualPassage passage,
  ) async {
    final books = await repository.getBooks();
    String normalize(String text) => text.toLowerCase()
      .replaceAll('á', 'a').replaceAll('é', 'e')
      .replaceAll('í', 'i').replaceAll('ó', 'o')
      .replaceAll('ú', 'u').replaceAll(RegExp(r'\s+'), ' ').trim();
    final wanted = normalize(passage.book);
    String? resolvedBook;
    for (final book in books) {
      if (normalize(book) == wanted) {
        resolvedBook = book;
        break;
      }
    }
    if (resolvedBook == null) return null;
    final chapter = await repository.getVerses(resolvedBook, passage.chapter);
    final selected = chapter.where((verse) =>
        verse.verse >= passage.start && verse.verse <= passage.end &&
        verse.text.trim().isNotEmpty).toList();
    if (selected.length != passage.end - passage.start + 1) return null;
    return Verse(
      book: resolvedBook,
      chapter: passage.chapter,
      verse: passage.start,
      endVerse: passage.end,
      text: selected.map((verse) => verse.text.trim()).join(' '),
      explanation: passage.meaning,
      reflectionQuestion: passage.question,
    );
  }

  static Future<Verse?> daily(BibleRepository repository, DateTime day) async {
    final first = forDay(day);
    final index = passages.indexOf(first);
    for (var step = 0; step < passages.length; step++) {
      final candidate = passages[(index + step) % passages.length];
      final verse = await resolve(repository, candidate);
      if (verse != null) return verse;
    }
    return null;
  }

  /// A saved choice avoids changing a reflection when reopening the same
  /// session. A small recent history prevents repeating the last four passages.
  static Future<Verse?> workout(
    BibleRepository repository, {
    required String sessionId,
    required String theme,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final pool = forWorkoutTheme(theme);
    final existing = prefs.getString('workout_reflection_session_$sessionId');
    final recent = prefs.getStringList('workout_reflection_recent_v1') ?? <String>[];
    final choices = existing == null
        ? <ContextualPassage>[
            ...pool.where((passage) => !recent.contains(passage.key)),
            ...pool.where((passage) => recent.contains(passage.key)),
          ]
        : <ContextualPassage>[
            ...passages.where((passage) => passage.key == existing),
          ];
    for (final candidate in choices) {
      final verse = await resolve(repository, candidate);
      if (verse == null) continue;
      if (existing == null) {
        await prefs.setString('workout_reflection_session_$sessionId', candidate.key);
        await prefs.setStringList('workout_reflection_recent_v1',
          [...recent.where((key) => key != candidate.key), candidate.key]
            .skip(recent.length >= 4 ? recent.length - 3 : 0).toList());
      }
      return verse;
    }
    return null;
  }

  static String closingThoughtFor(Verse verse) {
    for (final item in passages) {
      if (item.book == verse.book && item.chapter == verse.chapter &&
          item.start == verse.verse && item.end == verse.endVerse) {
        return item.closingThought;
      }
    }
    return 'Valora lo que has podido hacer hoy.';
  }
}
