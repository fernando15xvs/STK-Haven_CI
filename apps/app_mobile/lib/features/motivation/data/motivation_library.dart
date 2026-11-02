import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

enum MotivationMode {
  discipline('Disciplina'), gymSad('Gym Sad'), hype('Hype');
  const MotivationMode(this.label);
  final String label;
}
enum MotivationRepeat {
  next('Siguiente'), one('Repetir uno'),
  all('Repetir lista'), stop('Detener al finalizar');
  const MotivationRepeat(this.label);
  final String label;
}
@immutable
class MotivationTrack {
  const MotivationTrack({required this.id, required this.title,
    required this.fileName, required this.mode, required this.importedAt});
  final String id, title, fileName;
  final MotivationMode mode;
  final DateTime importedAt;
  bool get isVideo => p.extension(fileName).toLowerCase() == '.mp4';
  MotivationTrack copyWith({String? title, MotivationMode? mode}) =>
    MotivationTrack(id:id, title:title??this.title, fileName:fileName,
      mode:mode??this.mode, importedAt:importedAt);
  Map<String,dynamic> toJson()=>{'id':id,'title':title,'fileName':fileName,
    'mode':mode.name,'importedAt':importedAt.toIso8601String()};
  factory MotivationTrack.fromJson(Map<String,dynamic> j) {
    final name=j['fileName'] as String;
    if(p.basename(name)!=name || name.contains('..')) {
      throw const FormatException('Nombre de archivo inválido');
    }
    return MotivationTrack(id:j['id'] as String,title:j['title'] as String,
      fileName:name,mode:MotivationMode.values.firstWhere(
        (m)=>m.name==j['mode'],orElse:()=>MotivationMode.discipline),
      importedAt:DateTime.parse(j['importedAt'] as String));
  }
}
@immutable
class MotivationPlaylist {
  const MotivationPlaylist({required this.id,required this.title,
    required this.trackIds});
  final String id,title;
  final List<String> trackIds;
  Map<String,dynamic> toJson()=>{'id':id,'title':title,'trackIds':trackIds};
  factory MotivationPlaylist.fromJson(Map<String,dynamic> j)=>
    MotivationPlaylist(id:j['id'] as String,title:j['title'] as String,
      trackIds:List<String>.from(j['trackIds'] as List));
}

/// Local-only files: never uploaded to Supabase or shared with other users.
class MotivationLibrary extends ChangeNotifier {
  MotivationLibrary._();
  static final instance=MotivationLibrary._();
  static const supportedExtensions=<String>{'mp3','m4a','aac','wav','mp4'};
  static const maxFileBytes=512*1024*1024;
  static const _key='stk_motivation_library_v1';
  final _tracks=<MotivationTrack>[];
  final _playlists=<MotivationPlaylist>[];
  Directory? _directory;
  bool _loaded=false;
  bool get loaded=>_loaded;
  List<MotivationTrack> get tracks=>List.unmodifiable(_tracks);
  List<MotivationPlaylist> get playlists=>List.unmodifiable(_playlists);

  Future<void> load() async {
    if(_loaded)return;
    final dir=await getApplicationSupportDirectory();
    _directory=Directory(p.join(dir.path,'stk_motivation'));
    await _directory!.create(recursive:true);
    final prefs=await SharedPreferences.getInstance();
    final raw=prefs.getString(_key);
    if(raw!=null){
      try{
        final j=jsonDecode(raw) as Map<String,dynamic>;
        for(final item in (j['tracks'] as List? ?? [])){
          try{
            final t=MotivationTrack.fromJson(Map<String,dynamic>.from(item as Map));
            if(await File(filePath(t)).exists())_tracks.add(t);
          }catch(_){}
        }
        for(final item in (j['playlists'] as List? ?? [])){
          try{_playlists.add(MotivationPlaylist.fromJson(
            Map<String,dynamic>.from(item as Map)));}catch(_){}
        }
      }catch(_){/* Preserve existing files on unreadable metadata. */}
    }
    _loaded=true;
    notifyListeners();
  }
  String filePath(MotivationTrack t){
    if(_directory==null)throw StateError('Biblioteca sin inicializar');
    return p.join(_directory!.path,t.fileName);
  }
  List<MotivationTrack> forSelection(String selection){
    if(selection.startsWith('mode:')){
      final mode=selection.substring(5);
      return _tracks.where((t)=>t.mode.name==mode).toList();
    }
    if(selection.startsWith('playlist:')){
      final id=selection.substring(9);
      for(final list in _playlists){
        if(list.id==id){
          final byId={for(final t in _tracks)t.id:t};
          return [for(final key in list.trackIds)
            if(byId.containsKey(key))byId[key]!];
        }
      }
      return [];
    }
    return List.of(_tracks);
  }
  Future<int> importFromPicker({required MotivationMode mode}) async {
    await load();
    final pick=await FilePicker.pickFiles(
      type:FileType.custom,allowedExtensions:supportedExtensions.toList());
    if(pick.isEmpty)return 0;
    return importFiles(pick,mode:mode);
  }
  Future<int> importFiles(List<PlatformFile> files,
    {required MotivationMode mode}) async {
    await load();
    var count=0;
    for(final f in files){
      final ext=p.extension(f.name).toLowerCase().replaceFirst('.','');
      if(f.path==null || !supportedExtensions.contains(ext))continue;
      final expected=await f.length();
      if(expected<=0 || expected>maxFileBytes){
        throw const FormatException('Archivo vacío o superior a 512 MB');
      }
      final id=const Uuid().v4();
      final dest=File(p.join(_directory!.path,'$id.$ext'));
      final temp=File(dest.path+'.part');
      try{
        await File(f.path!).openRead().pipe(temp.openWrite());
        if(await temp.length()!=expected){
          throw const FileSystemException('Importación incompleta');
        }
        await temp.rename(dest.path);
        _tracks.add(MotivationTrack(id:id,
          title:p.basenameWithoutExtension(f.name),fileName:'$id.$ext',
          mode:mode,importedAt:DateTime.now()));
        count++;
      }catch(_){
        if(await temp.exists())await temp.delete();
        if(await dest.exists())await dest.delete();
        rethrow;
      }
    }
    if(count>0)await _changed();
    return count;
  }
  Future<void> renameTrack(String id,String title) async {
    if(title.trim().isEmpty)return;
    final i=_tracks.indexWhere((t)=>t.id==id);
    if(i<0)return;
    _tracks[i]=_tracks[i].copyWith(title:title.trim());
    await _changed();
  }
  Future<void> changeMode(String id,MotivationMode mode) async {
    final i=_tracks.indexWhere((t)=>t.id==id);
    if(i<0)return;
    _tracks[i]=_tracks[i].copyWith(mode:mode);
    await _changed();
  }
  Future<void> removeTrack(String id) async {
    final i=_tracks.indexWhere((t)=>t.id==id);
    if(i<0)return;
    final t=_tracks.removeAt(i);
    for(var k=0;k<_playlists.length;k++){
      final list=_playlists[k];
      _playlists[k]=MotivationPlaylist(id:list.id,title:list.title,
        trackIds:list.trackIds.where((x)=>x!=id).toList());
    }
    await _changed();
    final file=File(filePath(t));
    if(await file.exists())await file.delete();
  }
  Future<void> createPlaylist(String title) async {
    if(title.trim().isEmpty)return;
    _playlists.add(MotivationPlaylist(id:const Uuid().v4(),
      title:title.trim(),trackIds:const []));
    await _changed();
  }
  Future<void> deletePlaylist(String id) async {
    _playlists.removeWhere((x)=>x.id==id);
    await _changed();
  }
  Future<void> togglePlaylistTrack(String playlistId,String trackId) async {
    final i=_playlists.indexWhere((x)=>x.id==playlistId);
    if(i<0 || !_tracks.any((x)=>x.id==trackId))return;
    final list=_playlists[i], ids=List<String>.from(list.trackIds);
    if(ids.contains(trackId)){ids.remove(trackId);}else{ids.add(trackId);}
    _playlists[i]=MotivationPlaylist(id:list.id,title:list.title,trackIds:ids);
    await _changed();
  }
  Future<void> _changed() async {
    final prefs=await SharedPreferences.getInstance();
    final saved=await prefs.setString(_key,jsonEncode({
      'tracks':_tracks.map((x)=>x.toJson()).toList(),
      'playlists':_playlists.map((x)=>x.toJson()).toList(),
    }));
    if(!saved)throw const FileSystemException('No se pudo guardar biblioteca');
    notifyListeners();
  }
}
