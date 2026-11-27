import 'dart:convert';
import 'package:core/domain/models/private_journal_entry.dart';
import 'package:core/domain/models/habit_task.dart';
import 'package:core/features/habits/data/habit_task_repository.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
export 'package:core/domain/models/private_journal_entry.dart';

/// Native protected storage, deliberately outside STK's general backup.
class PrivateJournalRepository {
  static const _channel=MethodChannel('stk_haven/private_journal');
  static Future<void> _tail=Future.value();
  Future<T> _write<T>(Future<T> Function() op){
    final next=_tail.then((_)=>op());
    _tail=next.then<void>((_) {},onError:(Object _,StackTrace __){});
    return next;
  }
  Future<List<PrivateJournalEntry>> load()async{
    final raw=await _channel.invokeMethod<String>('read');
    final data=jsonDecode(raw??'[]');
    if(data is! List)throw const FormatException('Diario no válido');
    final rows=data.whereType<Map>().map((m)=>PrivateJournalEntry.fromJson(Map<String,dynamic>.from(m))).where((e)=>e.id.isNotEmpty).toList();
    rows.sort((a,b)=>b.createdAt.compareTo(a.createdAt));
    return rows;
  }
  Future<void> _save(List<PrivateJournalEntry> rows)async{
    if(await _channel.invokeMethod<bool>('write',{'data':jsonEncode(rows.map((e)=>e.toJson()).toList())})!=true){
      throw StateError('No se pudo guardar el diario');
    }
  }
  Future<void> put(String text,{String kind='Nota',String? id,DateTime? createdAt})=>_write(()async{
    if(text.trim().isEmpty)return;
    final key=id??const Uuid().v4();
    final rows=await load();
    await _save([PrivateJournalEntry(id:key,createdAt:createdAt??DateTime.now(),kind:kind,text:text.trim()),...rows.where((e)=>e.id!=key)]);
  });
  Future<void> delete(String id)=>_write(()async=>_save((await load()).where((e)=>e.id!=id).toList()));
  /// Copy legacy sensitive entries before redacting the original note. If
  /// protected storage fails nothing is deleted. Stable IDs make retry safe.
  Future<void> migrateLegacy(HabitTaskRepository habits)=>_write(()async{
    final tasks=habits.getTasks(includeArchived:true);
    final ids=tasks.where((t)=>t.source!=HabitTaskSource.coach&&t.visibility==HabitTaskVisibility.private).map((t)=>t.id).toSet();
    final rows=habits.getCompletions().where((c)=>ids.contains(c.taskId)&&c.note.trim().isNotEmpty).toList();
    if(rows.isEmpty)return;
    final existing=await load();
    final keys=existing.map((e)=>e.id).toSet();
    await _save([...existing,for(final c in rows)if(!keys.contains('legacy:${c.id}'))
      PrivateJournalEntry(id:'legacy:${c.id}',createdAt:c.completedAt,kind:'Registro anterior',text:c.note)]);
    for(final c in rows){
      await habits.saveCompletion(HabitTaskCompletion(id:c.id,taskId:c.taskId,completedAt:c.completedAt,minutesSpent:c.minutesSpent,quantity:c.quantity,status:c.status));
    }
  });
}
