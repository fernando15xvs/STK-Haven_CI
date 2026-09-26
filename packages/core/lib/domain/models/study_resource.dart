enum StudyResourceKind { bible, personalNotes, stkPlan }

class StudyResource {
  final String id;
  final String title;
  final String author;
  final StudyResourceKind kind;
  final List<String> topics;
  final String source;
  final String licenseName;
  final String licenseUrl;
  final bool textBundled;
  final String routeHint;

  const StudyResource({
    required this.id,
    required this.title,
    required this.author,
    required this.kind,
    this.topics = const <String>[],
    required this.source,
    required this.licenseName,
    this.licenseUrl = '',
    this.textBundled = false,
    this.routeHint = '',
  });
}
