import 'package:core/domain/models/nutrition_history_entry.dart';
import 'package:hive/hive.dart';

class NutritionHistoryRepository {
  static const String entryPrefix = 'nutrition_food_history::';
  static const int maxEntries = 100;
  static const String scopedPrefix = 'stk_nutrition_food_history_v2::';
  static const String _legacySourceKey = 'stkImportedLegacyKey';

  final Box<dynamic> _box;
  final String _prefix;

  NutritionHistoryRepository(this._box, {String? ownerId})
      : _prefix = ownerId == null ? entryPrefix
          : '$scopedPrefix${Uri.encodeComponent(ownerId)}::';

  /// Legacy unowned entries are invisible across user accounts unless a
  /// signed-in user explicitly chooses to claim them on this device.
  bool get hasLegacyEntries => _prefix != entryPrefix &&
      _box.keys.whereType<String>().any((key)=>key.startsWith(entryPrefix));

  Future<int> importLegacyEntries() async {
    if(_prefix==entryPrefix)return 0;
    final oldKeys=_box.keys.whereType<String>()
        .where((key)=>key.startsWith(entryPrefix)).toList();
    final moved=<String>[];
    for(final key in oldKeys){
      // The previous import may have copied this record but crashed before
      // removing its unowned origin. Reuse that copy, never clone it again.
      final alreadyCopied=_box.keys.whereType<String>()
        .where((candidate)=>candidate.startsWith(_prefix))
        .any((candidate){
          final value=_box.get(candidate);
          return value is Map && value[_legacySourceKey]==key;
        });
      if(alreadyCopied){
        moved.add(key);
        continue;
      }
      final raw=_box.get(key);
      if(raw is! Map)continue;
      try{
        final old=NutritionHistoryEntry.fromJson(
          Map<String,dynamic>.from(raw));
        if(old.id.trim().isEmpty)continue;
        var nextId=old.id;
        if(_box.containsKey('$_prefix$nextId')){
          var suffix=1;
          do{
            nextId='legacy_${old.id}_$suffix';
            suffix++;
          }while(_box.containsKey('$_prefix$nextId'));
        }
        final movedEntry=NutritionHistoryEntry(
          id:nextId,analyzedAt:old.analyzedAt,
          dishHint:old.dishHint,estimate:old.estimate,
          isFavorite:old.isFavorite,consumedAt:old.consumedAt,
          consumedFraction:old.consumedFraction);
        // Write owned copy first; remove legacy only after every write.
        await _box.put('$_prefix$nextId',
          movedEntry.toJson()..[_legacySourceKey]=key);
        moved.add(key);
      }catch(_){/* Unreadable legacy bytes are never deleted here. */}
    }
    await _box.deleteAll(moved);
    return moved.length;
  }

  List<NutritionHistoryEntry> getEntries() {
    final entries = <NutritionHistoryEntry>[];
    for (final key in _box.keys) {
      if (key is! String || !key.startsWith(_prefix)) continue;
      final raw = _box.get(key);
      if (raw is! Map) continue;
      try {
        final entry = NutritionHistoryEntry.fromJson(
          Map<String, dynamic>.from(raw),
        );
        if (entry.id.isEmpty) continue;
        entries.add(entry);
      } catch (_) {
        // Ignore malformed local entries instead of breaking the screen.
      }
    }
    entries.sort((a, b) => b.analyzedAt.compareTo(a.analyzedAt));
    return entries;
  }

  /// User-saved dish names only, with no automatic consumption or image
  /// storage. Counts never cross account prefixes and are never uploaded.
  List<String> frequentDishes({int minimum=2,int limit=6}) {
    final counts=<String,int>{};
    final names=<String,String>{};
    for(final entry in getEntries()){
      final raw=entry.estimate.dishName.trim();
      if(raw.isEmpty || raw.length>100)continue;
      final key=raw.toLowerCase().replaceAll(RegExp(r'\s+'),' ');
      if(key.isEmpty)continue;
      counts.update(key,(current)=>current+1,ifAbsent:()=>1);
      names.putIfAbsent(key,()=>raw);
    }
    final ordered=counts.keys.where((name)=>counts[name]!>=minimum)
      .toList()..sort((a,b){
        final byCount=counts[b]!.compareTo(counts[a]!);
        return byCount!=0?byCount:a.compareTo(b);
      });
    return List<String>.unmodifiable([
      for(final key in ordered.take(limit.clamp(0,10).toInt()))names[key]!,
    ]);
  }

  Future<void> save(NutritionHistoryEntry entry) async {
    if (entry.id.trim().isEmpty) {
      throw ArgumentError.value(entry.id, 'entry.id', 'No puede estar vacío.');
    }
    await _box.put('$_prefix${entry.id}', entry.toJson());
    final entries = getEntries();
    if (entries.length <= maxEntries) return;
    // Keep favorited meals when ordinary old entries can be evicted first.
    final overflow=entries.length-maxEntries;
    final oldest=entries.reversed.toList();
    final evictions=<NutritionHistoryEntry>[
      ...oldest.where((entry)=>!entry.isFavorite),
      ...oldest.where((entry)=>entry.isFavorite),
    ].take(overflow);
    for(final stale in evictions){
      await _box.delete('$_prefix${stale.id}');
    }
  }

  /// Changes only a saved record belonging to this account's local prefix.
  Future<void> setFavorite(String id,bool favorite) async {
    final key='$_prefix$id';
    final data=_box.get(key);
    if(data is! Map)return;
    final entry=NutritionHistoryEntry.fromJson(
      Map<String,dynamic>.from(data));
    // Preserve migration provenance if a user changes their favorite state
    // while an interrupted legacy cleanup still needs a retry.
    final next=entry.copyWith(isFavorite:favorite).toJson();
    if(data[_legacySourceKey] is String){
      next[_legacySourceKey]=data[_legacySourceKey];
    }
    await _box.put(key,next);
  }

  Future<void> setConsumption(String id,DateTime? date,{double fraction=1.0}) async {
    if(date!=null && !NutritionHistoryEntry.validFraction(fraction)) {
      throw ArgumentError.value(fraction,'fraction','Porción inválida');
    }
    final key='$_prefix$id';
    final data=_box.get(key);
    if(data is! Map)return;
    final entry=NutritionHistoryEntry.fromJson(Map<String,dynamic>.from(data));
    final next=entry.copyWith(consumedAt:date,clearConsumption:date==null,
      consumedFraction:fraction).toJson();
    if(data[_legacySourceKey] is String)next[_legacySourceKey]=data[_legacySourceKey];
    await _box.put(key,next);
  }

  Future<void> delete(String id) => _box.delete('$_prefix$id');

  Future<void> clear() async {
    final keys = _box.keys
        .whereType<String>()
        .where((key) => key.startsWith(_prefix))
        .toList(growable: false);
    await _box.deleteAll(keys);
  }
}
