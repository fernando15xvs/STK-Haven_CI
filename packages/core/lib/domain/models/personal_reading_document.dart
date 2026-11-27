import 'package:core/domain/models/habit_task.dart';

class PersonalReadingDocument {
  final String id;
  final String title;
  final String originalFileName;
  final String localPath;
  final DateTime importedAt;
  final DateTime? lastReadAt;
  final int currentPage;
  final int totalPages;
  final String author;
  final String fingerprint;
  final bool physical;
  final bool favorite;
  final bool finished;
  final int goalDays;
  final DateTime? goalStartedAt;
  final Set<int> bookmarks;
  final Map<int,String> pageNotes;
  final Map<int,List<String>> highlights;
  final List<ReadingSession> sessions;

  const PersonalReadingDocument({
    required this.id,
    required this.title,
    required this.originalFileName,
    required this.localPath,
    required this.importedAt,
    this.lastReadAt,
    this.currentPage = 1,
    this.totalPages = 0,
    this.author = '', this.fingerprint = '', this.physical = false,
    this.favorite = false, this.finished = false, this.goalDays = 14,
    this.goalStartedAt, this.bookmarks = const {}, this.pageNotes = const {}, this.highlights=const {}, this.sessions = const [],
  });

  double get progress {
    if (totalPages <= 0) return 0;
    return (currentPage / totalPages).clamp(0.0, 1.0).toDouble();
  }

  int get suggestedPagesPerDay => pagesPerDayAt(DateTime.now());

  int pagesPerDayAt(DateTime now) {
    if (totalPages <= 0) return 0;
    final remaining = (totalPages - currentPage).clamp(0, totalPages);
    if (remaining == 0) return 0;
    final start = goalStartedAt;
    final elapsed = start==null?0:DateTime(now.year,now.month,now.day).difference(DateTime(start.year,start.month,start.day)).inDays;
    return (remaining / (goalDays-elapsed).clamp(1,365)).ceil();
  }

  PersonalReadingDocument copyWith({
    String? title,
    DateTime? lastReadAt,
    int? currentPage,
    int? totalPages,
    String? author, String? fingerprint, bool? favorite, bool? finished,
    int? goalDays, DateTime? goalStartedAt, Set<int>? bookmarks, Map<int,String>? pageNotes,Map<int,List<String>>? highlights,
    List<ReadingSession>? sessions, String? localPath,
  }) {
    return PersonalReadingDocument(
      id: id,
      title: title ?? this.title,
      originalFileName: originalFileName,
      localPath: localPath ?? this.localPath,
      importedAt: importedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      author:author??this.author,fingerprint:fingerprint??this.fingerprint,physical:physical,
      favorite:favorite??this.favorite,finished:finished??this.finished,
      goalDays:goalDays??this.goalDays,goalStartedAt:goalStartedAt??this.goalStartedAt,
      bookmarks:bookmarks??this.bookmarks,pageNotes:pageNotes??this.pageNotes,highlights:highlights??this.highlights,sessions:sessions??this.sessions,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'originalFileName': originalFileName,
        'localPath': localPath,
        'importedAt': importedAt.toIso8601String(),
        'lastReadAt': lastReadAt?.toIso8601String(),
        'currentPage': currentPage,
        'totalPages': totalPages,
        'author':author,'fingerprint':fingerprint,'physical':physical,'favorite':favorite,'finished':finished,
        'goalDays':goalDays,'goalStartedAt':goalStartedAt?.toIso8601String(),'bookmarks':bookmarks.toList(),
        'pageNotes':pageNotes.map((k,v)=>MapEntry('$k',v)),'highlights':highlights.map((k,v)=>MapEntry('$k',v)),'sessions':sessions.map((s)=>s.toJson()).toList(),
      };

  factory PersonalReadingDocument.fromJson(Map<String, dynamic> json) {
    final currentPage = (json['currentPage'] as num?)?.toInt() ?? 1;
    final totalPages = (json['totalPages'] as num?)?.toInt() ?? 0;
    return PersonalReadingDocument(
      id: '${json['id'] ?? ''}'.trim(),
      title: '${json['title'] ?? ''}'.trim(),
      originalFileName: '${json['originalFileName'] ?? ''}'.trim(),
      localPath: '${json['localPath'] ?? ''}'.trim(),
      importedAt:
          DateTime.tryParse('${json['importedAt']}') ?? DateTime.now(),
      lastReadAt: json['lastReadAt'] == null
          ? null
          : DateTime.tryParse('${json['lastReadAt']}'),
      currentPage: currentPage < 1 ? 1 : currentPage,
      totalPages: totalPages < 0 ? 0 : totalPages,
      author:'${json['author']??''}',fingerprint:'${json['fingerprint']??''}',physical:json['physical']==true,
      favorite:json['favorite']==true,finished:json['finished']==true,
      goalDays:((json['goalDays'] as num?)?.toInt()??14).clamp(1,365).toInt(),
      goalStartedAt:DateTime.tryParse('${json['goalStartedAt']}'),
      bookmarks:(json['bookmarks'] as List? ?? const []).whereType<num>().map((v)=>v.toInt()).where((v)=>v>0).toSet(),
      pageNotes:(json['pageNotes'] as Map? ?? const {}).map((k,v)=>MapEntry(int.tryParse('$k')??0,'$v'))..remove(0),
      highlights:(json['highlights'] as Map? ?? const {}).map<int,List<String>>((k,v)=>MapEntry(int.tryParse('$k')??0,(v is List?v:const []).whereType<String>().toList()))..remove(0),
      sessions:(json['sessions'] as List? ?? const []).whereType<Map>().map((v)=>ReadingSession.fromJson(Map<String,dynamic>.from(v))).toList(),
    );
  }
}

class ReadingSession {
  final String id;
  final DateTime startedAt;
  final int seconds;
  final int pagesAdvanced;
  const ReadingSession({required this.id,required this.startedAt,required this.seconds,required this.pagesAdvanced});
  Map<String,dynamic> toJson()=>{'id':id,'startedAt':startedAt.toIso8601String(),'seconds':seconds,'pagesAdvanced':pagesAdvanced};
  factory ReadingSession.fromJson(Map<String,dynamic> json)=>ReadingSession(
    id:'${json['id']??''}',startedAt:DateTime.tryParse('${json['startedAt']}')??DateTime.fromMillisecondsSinceEpoch(0),
    seconds:((json['seconds'] as num?)?.toInt()??0).clamp(0,86400).toInt(),
    pagesAdvanced:((json['pagesAdvanced'] as num?)?.toInt()??0).clamp(0,1000000).toInt());
}
abstract final class ReadingStatistics {
  static int secondsLastSevenDays(Iterable<PersonalReadingDocument> docs,DateTime now,{
    Iterable<HabitTask> tasks=const [],Iterable<HabitTaskCompletion> completions=const [],
  }) {
    final local=now.toLocal();
    final start=DateTime(local.year,local.month,local.day-6);
    final seen=<String>{};
    final librarySeconds=docs.expand((d)=>d.sessions).where((s)=>s.id.isNotEmpty&&!s.startedAt.isBefore(start)&&!s.startedAt.isAfter(now)&&seen.add(s.id))
      .fold<int>(0,(sum,s)=>sum+s.seconds);
    final ids=tasks.where((t)=>!t.faithSpecific&&t.type==HabitTaskType.readingTimer&&t.source!=HabitTaskSource.coach).map((t)=>t.id).toSet();
    final habitSeconds=completions.where((c)=>ids.contains(c.taskId)&&c.status==HabitTaskCompletionStatus.completed&&
      !c.completedAt.isBefore(start)&&!c.completedAt.isAfter(now)&&!(c.id.startsWith('reading:')&&seen.contains(c.id.substring(8))))
      .fold<int>(0,(sum,c)=>sum+c.minutesSpent*60);
    return librarySeconds+habitSeconds;
  }
}
