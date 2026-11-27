import 'package:core/database/hive/hive_boxes.dart';
import 'package:hive/hive.dart';
import 'package:riverpod/riverpod.dart';

/// Local manual diary. A date is the morning on which the user woke up.
/// Missing is distinct from a real zero-minute night; no sensor data is inferred.
class SleepDiary {
  final Map<String,int> entries;
  final int? goalMinutes;
  final Map<String,int> qualities;
  const SleepDiary._(this.entries,this.goalMinutes,this.qualities);
  factory SleepDiary.empty() => const SleepDiary._({},null,{});

  int? qualityFor(DateTime date) => qualities[dayKey(date)];

  static int? suggestedMinimumMinutes(int? age) => age == null ? null :
    age >= 15 && age < 18 ? 480 : age >= 18 ? 420 : null;
  SleepDiary withQuality(DateTime date, int quality) {
    if (quality < 1 || quality > 5) throw ArgumentError('Calidad inválida.');
    return SleepDiary._(entries, goalMinutes,
      Map.unmodifiable({...qualities, dayKey(date): quality}));
  }

  List<int?> window(DateTime today, int days) => List.generate(days, (i) =>
    minutesFor(DateTime(today.year, today.month, today.day - days + i + 1)));

  double? average(DateTime today, int days) {
    final recorded = window(today, days).whereType<int>().toList();
    return recorded.isEmpty ? null : recorded.reduce((a,b)=>a+b)/recorded.length;
  }

  static String dayKey(DateTime value) {
    final d = value.toLocal();
    return '${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  }

  int? minutesFor(DateTime date) => entries[dayKey(date)];
  List<MapEntry<String,int>> recent({int limit = 14}) {
    final rows = entries.entries.toList()..sort((a,b)=>b.key.compareTo(a.key));
    return List.unmodifiable(rows.take(limit.clamp(0,365).toInt()));
  }

  SleepDiary withEntry(DateTime date,int minutes) {
    if(minutes<0 || minutes>1440) throw ArgumentError('Duración inválida.');
    return SleepDiary._(Map.unmodifiable({...entries,dayKey(date):minutes}),goalMinutes,qualities);
  }

  SleepDiary withoutEntry(DateTime date) {
    final next = Map<String,int>.from(entries)..remove(dayKey(date));
    final nextQuality = Map<String,int>.from(qualities)..remove(dayKey(date));
    return SleepDiary._(Map.unmodifiable(next),goalMinutes,Map.unmodifiable(nextQuality));
  }

  SleepDiary withGoal(int? minutes) {
    if(minutes!=null && (minutes<=0 || minutes>1440)) throw ArgumentError('Meta inválida.');
    return SleepDiary._(entries,minutes,qualities);
  }

  Map<String,dynamic> toJson()=>{'entries':entries,'goalMinutes':goalMinutes,'qualities':qualities};
  factory SleepDiary.fromJson(Object? raw) {
    if(raw is! Map) return SleepDiary.empty();
    final entries=<String,int>{};
    final values=raw['entries'];
    if(values is Map) {
      for(final entry in values.entries) {
        final key=entry.key;
        final minutes=entry.value;
        if(key is! String || minutes is! int || minutes<0 || minutes>1440)continue;
        final date=DateTime.tryParse(key);
        if(date!=null && dayKey(date)==key)entries[key]=minutes;
      }
    }
    final goal=raw['goalMinutes'];
    final qualities = <String,int>{};
    final rawQuality = raw['qualities'];
    if (rawQuality is Map) {
      for (final entry in rawQuality.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is! String || value is! int || value < 1 || value > 5) continue;
        final date = DateTime.tryParse(key);
        if (date != null && dayKey(date) == key) qualities[key] = value;
      }
    }
    return SleepDiary._(Map.unmodifiable(entries),
      goal is int && goal>0 && goal<=1440?goal:null,Map.unmodifiable(qualities));
  }
}

/// Existing metadata box participates in backup/restore. No migration or new
/// Hive adapter; sleep data is never mixed with recovery scores.
class SleepDiaryRepository {
  static const storageKey='home_sleep_diary_v1';
  final Box<dynamic> box;
  SleepDiaryRepository(this.box);
  SleepDiary read()=>SleepDiary.fromJson(box.get(storageKey));
  Future<void> save(SleepDiary diary)=>box.put(storageKey,diary.toJson());
}
final sleepDiaryRepositoryProvider=Provider<SleepDiaryRepository>((ref)=>
  SleepDiaryRepository(Hive.box<dynamic>(HiveBoxes.metadata)));
final sleepDiaryProvider=NotifierProvider<SleepDiaryNotifier,SleepDiary>(SleepDiaryNotifier.new);
class SleepDiaryNotifier extends Notifier<SleepDiary> {
  SleepDiaryRepository get _repository=>ref.read(sleepDiaryRepositoryProvider);
  @override
  SleepDiary build()=>Hive.isBoxOpen(HiveBoxes.metadata)
      ? ref.watch(sleepDiaryRepositoryProvider).read() : SleepDiary.empty();

  Future<void> saveQuality(DateTime date,int quality) async {
    final next = _repository.read().withQuality(date,quality);
    await _repository.save(next);
    state = next;
  }

  Future<void> saveNight(DateTime date,int minutes,{int? quality}) async {
    var next=_repository.read().withEntry(date,minutes);
    if (quality != null) next = next.withQuality(date,quality);
    await _repository.save(next);
    state=next;
  }
  Future<void> deleteNight(DateTime date) async {
    final next=_repository.read().withoutEntry(date);
    await _repository.save(next);
    state=next;
  }
  Future<void> setGoal(int? minutes) async {
    final next=_repository.read().withGoal(minutes);
    await _repository.save(next);
    state=next;
  }
  void refresh()=>state=_repository.read();
}
