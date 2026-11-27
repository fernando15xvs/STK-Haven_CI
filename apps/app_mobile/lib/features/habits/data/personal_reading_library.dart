import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:core/domain/models/personal_reading_document.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
export 'package:core/domain/models/personal_reading_document.dart';

/// Native file adapter. Metadata and files are not part of STK's cloud backup.
class PersonalReadingLibraryRepository {
  static const _storageKey='personal_reading_library_v1';
  static const _uuid=Uuid();
  static Future<void> _tail=Future.value();
  Future<T> _write<T>(Future<T> Function() op) {
    final next=_tail.then((_)=>op());
    _tail=next.then<void>((_) {},onError:(Object _,StackTrace __){});
    return next;
  }
  Future<Directory> _directory() async {
    final root=await getApplicationDocumentsDirectory();
    final dir=Directory(p.join(root.path,'reading_library'));
    await dir.create(recursive:true);
    return dir;
  }
  Future<List<PersonalReadingDocument>> load() async {
    final prefs=await SharedPreferences.getInstance();
    final raw=prefs.getString(_storageKey);
    if(raw==null||raw.isEmpty)return [];
    final decoded=jsonDecode(raw);
    if(decoded is! List)throw const FormatException('Biblioteca no válida');
    final dir=await _directory();
    final docs=decoded.whereType<Map>().map((m)=>PersonalReadingDocument.fromJson(Map<String,dynamic>.from(m)))
      .where((d)=>d.id.isNotEmpty&&d.title.isNotEmpty).map((d)=>d.physical?d:d.copyWith(localPath:p.join(dir.path,'${d.id}.pdf'))).toList();
    docs.sort((a,b)=>(b.lastReadAt??b.importedAt).compareTo(a.lastReadAt??a.importedAt));
    return docs;
  }
  Future<PersonalReadingDocument?> importPdf() async {
    final picked=await FilePicker.pickFiles(type:FileType.custom,allowedExtensions:['pdf']);
    if(picked.isEmpty)return null;
    final item=picked.first;
    final path=item.path;
    if(path==null||path.isEmpty)return null;
    final file=File(path);
    if(await file.length()==0)throw const FormatException('Archivo vacío');
    final hash=(await sha256.bind(file.openRead()).first).toString();
    return _write(()async{
      final docs=await load();
      for(final doc in docs.where((d)=>!d.physical)){
        final existing=File(doc.localPath);
        if(!await existing.exists())continue;
        final fingerprint=doc.fingerprint.isNotEmpty?doc.fingerprint:(await sha256.bind(existing.openRead()).first).toString();
        if(fingerprint==hash)return doc;
      }
      final id=_uuid.v4();
      final dir=await _directory();
      final destination=p.join(dir.path,'$id.pdf');
      await file.copy(destination);
      final title=p.basenameWithoutExtension(item.name).replaceAll(RegExp(r'[_-]+'),' ').trim();
      final document=PersonalReadingDocument(id:id,title:title.isEmpty?'Libro importado':title,
        originalFileName:item.name,localPath:destination,importedAt:DateTime.now(),fingerprint:hash,goalStartedAt:DateTime.now());
      try{await _save([document,...docs]);}catch(_){await File(destination).delete();rethrow;}
      return document;
    });
  }
  Future<PersonalReadingDocument> addPhysical(String title,int pages,{String author=''})=>_write(()async{
    if(title.trim().isEmpty||pages<1)throw ArgumentError('Título y páginas requeridos');
    final doc=PersonalReadingDocument(id:_uuid.v4(),title:title.trim(),author:author.trim(),
      originalFileName:'',localPath:'',physical:true,importedAt:DateTime.now(),totalPages:pages,goalStartedAt:DateTime.now());
    await _save([doc,...await load()]);
    return doc;
  });
  Future<PersonalReadingDocument?> update(String id,PersonalReadingDocument Function(PersonalReadingDocument) edit)=>_write(()async{
    final docs=await load();
    final i=docs.indexWhere((d)=>d.id==id);
    if(i<0)return null;
    docs[i]=edit(docs[i]);
    await _save(docs);
    return docs[i];
  });
  Future<void> updateProgress(PersonalReadingDocument document,{required int currentPage,int? totalPages}) async {
    await update(document.id,(d){
      final total=totalPages??d.totalPages;
      return d.copyWith(currentPage:currentPage.clamp(1,total>0?total:1000000).toInt(),totalPages:total,lastReadAt:DateTime.now());
    });
  }
  Future<PersonalReadingDocument?> checkpoint(String id,{required int page,required int totalPages,required ReadingSession session})=>
    update(id,(d)=>d.copyWith(currentPage:page.clamp(1,totalPages>0?totalPages:1000000).toInt(),totalPages:totalPages,
      lastReadAt:DateTime.now(),sessions:[...d.sessions.where((s)=>s.id!=session.id),if(session.seconds>0)session]));
  Future<void> rename(String id,String title)async{
    if(title.trim().isEmpty)return;
    await update(id,(d)=>d.copyWith(title:title.trim()));
  }
  Future<void> remove(PersonalReadingDocument document)=>_write(()async{
    final docs=await load();
    final match=docs.where((d)=>d.id==document.id).firstOrNull;
    if(match==null)return;
    if(!match.physical){
      final file=File(match.localPath);
      if(await file.exists())await file.delete();
    }
    await _save(docs.where((d)=>d.id!=document.id).toList());
  });
  Future<void> _save(List<PersonalReadingDocument> docs)async{
    final prefs=await SharedPreferences.getInstance();
    if(!await prefs.setString(_storageKey,jsonEncode(docs.map((d)=>d.toJson()).toList())))throw StateError('No se guardó la biblioteca');
  }
}
