import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'motivation_file_dedup.dart';
import 'motivation_artwork_processor.dart';

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
    required this.fileName, required this.mode, required this.importedAt,
    this.favorite=false, this.artworkFileName, this.thumbnailFileName});
  final String id, title, fileName;
  final String? artworkFileName;
  final String? thumbnailFileName;
  final MotivationMode mode;
  final DateTime importedAt;
  final bool favorite;
  bool get isVideo => p.extension(fileName).toLowerCase() == '.mp4';
  MotivationTrack copyWith({String? title, MotivationMode? mode,
    bool? favorite, String? artworkFileName, bool clearArtwork=false,
    String? thumbnailFileName}) =>
    MotivationTrack(id:id, title:title??this.title, fileName:fileName,
      mode:mode??this.mode, importedAt:importedAt,
      favorite:favorite??this.favorite,
      artworkFileName:clearArtwork?null:(artworkFileName??this.artworkFileName),
      thumbnailFileName:thumbnailFileName??this.thumbnailFileName);
  Map<String,dynamic> toJson()=>{'id':id,'title':title,'fileName':fileName,
    'mode':mode.name,'importedAt':importedAt.toIso8601String(),
    'favorite':favorite,'artworkFileName':artworkFileName,
    'thumbnailFileName':thumbnailFileName};
  factory MotivationTrack.fromJson(Map<String,dynamic> j) {
    final name=j['fileName'] as String;
    if(p.basename(name)!=name || name.contains('..')) {
      throw const FormatException('Nombre de archivo inválido');
    }
    final artwork=j['artworkFileName'] as String?;
    final thumbnail=j['thumbnailFileName'] as String?;
    for(final name in [artwork,thumbnail]){
      if(name!=null &&
          (p.basename(name)!=name || name.contains('..'))){
        throw const FormatException('Nombre de portada inválido');
      }
    }
    return MotivationTrack(id:j['id'] as String,title:j['title'] as String,
      fileName:name,mode:MotivationMode.values.firstWhere(
        (m)=>m.name==j['mode'],orElse:()=>MotivationMode.discipline),
      importedAt:DateTime.parse(j['importedAt'] as String),
      // Existing stage-1 records omit this field.
      favorite:j['favorite']==true, artworkFileName:artwork,
      thumbnailFileName:thumbnail);
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

  /// Isolated in-memory snapshot for widget layout tests. Does not touch
  /// SharedPreferences, the system picker, or private device media.
  /// Production always uses [instance], which loads its real local library.
  @visibleForTesting
  MotivationLibrary.testSnapshot({
    required List<MotivationTrack> tracks,
    List<MotivationPlaylist> playlists=const [],
  }) {
    _tracks.addAll(tracks);
    _playlists.addAll(playlists);
    _loaded=true;
  }

  static final instance=MotivationLibrary._();
  static const supportedExtensions=<String>{'mp3','m4a','aac','wav','mp4'};
  static const maxFileBytes=512*1024*1024;
  static const maxArtworkBytes=8*1024*1024;
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
  /// A manual cover takes precedence, then a locally extracted MP4 frame.
  /// Neither path ever resolves to remote media or arbitrary user directories.
  String? artworkPath(MotivationTrack track) {
    if(_directory==null)return null;
    for(final name in [track.artworkFileName,track.thumbnailFileName]){
      if(name==null || p.basename(name)!=name || name.contains('..'))continue;
      final file=File(p.join(_directory!.path,name));
      if(file.existsSync())return file.path;
    }
    return null;
  }

  /// Creates a bounded private thumbnail once per video, outside every
  /// ListTile build. An unsupported codec must never prevent importing MP4.
  Future<bool> ensureVideoThumbnail(String trackId) async {
    await load();
    final index=_tracks.indexWhere((t)=>t.id==trackId);
    if(index<0 || !_tracks[index].isVideo)return false;
    final track=_tracks[index];
    if(track.thumbnailFileName!=null &&
        artworkPath(track)!=null)return true;
    final path=filePath(track);
    if(!await File(path).exists())return false;
    final name='thumb_${const Uuid().v4()}.jpg';
    final destination=File(p.join(_directory!.path,name));
    final temp=File(destination.path+'.part');
    var mayStillBeReferenced=false;
    try {
      // Native Android/iOS extraction, never a frame decoder per list tile.
      final bytes=await VideoThumbnail.thumbnailData(
        video:path,imageFormat:ImageFormat.JPEG,
        timeMs:0,maxWidth:400,quality:65);
      if(bytes==null || bytes.isEmpty || bytes.length>2*1024*1024)
        return false;
      await temp.writeAsBytes(bytes,flush:true);
      await temp.rename(destination.path);
      // A file may have been removed while extraction was running.
      final latest=_tracks.indexWhere((t)=>t.id==trackId);
      if(latest<0){
        await destination.delete();
        return false;
      }
      final previous=_tracks[latest];
      _tracks[latest]=previous.copyWith(thumbnailFileName:name);
      try {
        await _changed();
      }catch(_){
        _tracks[latest]=previous;
        try{
          // A failed first write may already be on disk. Confirm that the
          // previous metadata is persisted before deleting new artwork.
          await _changed();
        }catch(_){
          mayStillBeReferenced=true;
          notifyListeners();
        }
        rethrow;
      }
      final old=previous.thumbnailFileName;
      if(old!=null && old!=name){
        final stale=File(p.join(_directory!.path,old));
        try{
          if(await stale.exists())await stale.delete();
        }catch(_){/* A stale cover is safer than a broken new reference. */}
      }
      return true;
    }catch(_){
      try{if(await temp.exists())await temp.delete();}catch(_){}
      if(!mayStillBeReferenced){
        try{if(await destination.exists())await destination.delete();}catch(_){}
      }
      return false;
    }
  }

  Future<bool> chooseArtwork(
    String trackId, {
    Future<MotivationCoverFocus?> Function(String localFilePath)? requestFocus,
  }) async {
    await load();
    final idx=_tracks.indexWhere((t)=>t.id==trackId);
    if(idx<0)return false;
    final picked=await FilePicker.pickFiles(type:FileType.custom,
      allowedExtensions:const ['jpg','jpeg','png','webp']);
    if(picked.isEmpty)return false;
    final item=picked.first;
    if(item.path==null)return false;
    final bytes=await item.length();
    if(bytes<=0 || bytes>maxArtworkBytes){
      throw const FormatException('La portada debe pesar menos de 8 MB.');
    }
    final ext=p.extension(item.name).toLowerCase().replaceFirst('.', '');
    if(!const {'jpg','jpeg','png','webp'}.contains(ext))return false;
    // Cropping is optional; cancellation must preserve the old cover.
    final focus=requestFocus==null
      ?const MotivationCoverFocus()
      :await requestFocus(item.path!);
    if(focus==null)return false;
    final currentIdx=_tracks.indexWhere((t)=>t.id==trackId);
    if(currentIdx<0)return false;
    // Canonicalize all accepted photo formats to one small private PNG.
    final name='art_${const Uuid().v4()}.png';
    final destination=File(p.join(_directory!.path,name));
    final temp=File(destination.path+'.part');
    var mayStillBeReferenced=false;
    try{
      await MotivationArtworkProcessor.writeSquareCover(
        source:File(item.path!),destination:temp,focus:focus);
      if(!await temp.exists() || await temp.length()==0){
        throw const FileSystemException('Portada incompleta');
      }
      await temp.rename(destination.path);
      // Cropping and I/O are asynchronous. The original track might have
      // been deleted or reordered while the editor was open. Never attach
      // its cover to another track through an outdated list index.
      final latestIdx=_tracks.indexWhere((track)=>track.id==trackId);
      if(latestIdx<0){
        throw const FileSystemException('El archivo original ya no existe');
      }
      final previous=_tracks[latestIdx];
      _tracks[latestIdx]=previous.copyWith(artworkFileName:name);
      try{
        await _changed();
      }catch(_){
        _tracks[latestIdx]=previous;
        try{
          await _changed();
        }catch(_){
          // The new cover may still be referenced by a partially persisted
          // snapshot. Keep the file instead of creating a broken image.
          mayStillBeReferenced=true;
          notifyListeners();
        }
        rethrow;
      }
      final old=previous.artworkFileName;
      if(old!=null && old!=name){
        final file=File(p.join(_directory!.path,old));
        try{
          if(await file.exists())await file.delete();
        }catch(_){/* Keep an orphan instead of failing a saved cover. */}
      }
      return true;
    }catch(_){
      try{if(await temp.exists())await temp.delete();}catch(_){}
      if(!mayStillBeReferenced){
        try{if(await destination.exists())await destination.delete();}catch(_){}
      }
      rethrow;
    }
  }

  Future<void> clearArtwork(String id) async {
    final idx=_tracks.indexWhere((t)=>t.id==id);
    if(idx<0)return;
    final previous=_tracks[idx];
    final old=previous.artworkFileName;
    if(old==null)return;
    _tracks[idx]=previous.copyWith(clearArtwork:true);
    try{
      await _changed();
    }catch(_){
      // Keep the old visible artwork when metadata persistence fails.
      _tracks[idx]=previous;
      notifyListeners();
      rethrow;
    }
    final file=File(p.join(_directory!.path,old));
    try{
      if(await file.exists())await file.delete();
    }catch(_){
      // Metadata is already committed: an orphaned cover is safer than
      // reporting that the user's successful change failed.
    }
  }

  List<MotivationTrack> forSelection(String selection){
    if(selection=='favorites'){
      return _tracks.where((t)=>t.favorite).toList();
    }
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
    final importedVideos=<String>[];
    final importedIds=<String>{};
    final copiedFiles=<File>[];
    var attemptedMetadataSave=false;
    try{
      for(final f in files){
        final ext=p.extension(f.name).toLowerCase().replaceFirst('.','');
        if(f.path==null || !supportedExtensions.contains(ext))continue;
        final expected=await f.length();
        if(expected<=0 || expected>maxFileBytes){
          throw const FormatException('Archivo vacío o superior a 512 MB');
        }
        final incoming=File(f.path!);
        // Equal content with another filename is still one local copy.
        // Compare chunks rather than buffering a large video in memory.
        final existing=[
          for(final old in _tracks)
            if(p.extension(old.fileName).toLowerCase()=='.$ext')
              File(filePath(old)),
        ];
        if(await MotivationFileDedup.matchesAny(incoming,existing))continue;
        final id=const Uuid().v4();
        final dest=File(p.join(_directory!.path,'$id.$ext'));
        final temp=File(dest.path+'.part');
        try{
          await incoming.openRead().pipe(temp.openWrite());
          if(await temp.length()!=expected){
            throw const FileSystemException('Importación incompleta');
          }
          await temp.rename(dest.path);
          copiedFiles.add(dest);
          importedIds.add(id);
          _tracks.add(MotivationTrack(id:id,
            title:p.basenameWithoutExtension(f.name),fileName:'$id.$ext',
            mode:mode,importedAt:DateTime.now()));
          if(ext=='mp4')importedVideos.add(id);
          count++;
        }catch(_){
          if(await temp.exists())await temp.delete();
          if(await dest.exists())await dest.delete();
          rethrow;
        }
      }
      if(count>0){
        attemptedMetadataSave=true;
        await _changed();
      }
    }catch(_){
      // Roll back only this import batch, never unrelated library entries.
      _tracks.removeWhere((track)=>importedIds.contains(track.id));
      var safeToDiscard=!attemptedMetadataSave;
      if(attemptedMetadataSave){
        try{
          // A failed preference write may have committed before reporting
          // failure. Re-persist the previous library before removing copies.
          await _changed();
          safeToDiscard=true;
        }catch(_){
          // Keep the copied files if metadata may still reference them.
          // Prefer recoverable orphans over permanent loss of user media.
          notifyListeners();
        }
      }
      if(safeToDiscard){
        for(final copied in copiedFiles){
          try{
            if(await copied.exists())await copied.delete();
          }catch(_){/* No data loss if cleanup fails. */}
        }
      }
      notifyListeners();
      rethrow;
    }
    // Imported content is already durable. Thumbnail errors are cosmetic.
    for(final id in importedVideos){
      await ensureVideoThumbnail(id);
    }
    return count;
  }
  Future<void> renameTrack(String id,String title) async {
    if(title.trim().isEmpty)return;
    final i=_tracks.indexWhere((t)=>t.id==id);
    if(i<0)return;
    final previous=_tracks[i];
    _tracks[i]=previous.copyWith(title:title.trim());
    try{
      await _changed();
    }catch(_){
      _tracks[i]=previous;
      notifyListeners();
      rethrow;
    }
  }
  Future<void> toggleFavorite(String id) async {
    final i=_tracks.indexWhere((t)=>t.id==id);
    if(i<0)return;
    final previous=_tracks[i];
    _tracks[i]=previous.copyWith(favorite:!previous.favorite);
    try{
      await _changed();
    }catch(_){
      _tracks[i]=previous;
      notifyListeners();
      rethrow;
    }
  }
  Future<void> changeMode(String id,MotivationMode mode) async {
    final i=_tracks.indexWhere((t)=>t.id==id);
    if(i<0)return;
    final previous=_tracks[i];
    _tracks[i]=previous.copyWith(mode:mode);
    try{
      await _changed();
    }catch(_){
      _tracks[i]=previous;
      notifyListeners();
      rethrow;
    }
  }
  Future<void> removeTrack(String id) async {
    final i=_tracks.indexWhere((t)=>t.id==id);
    if(i<0)return;
    final originalTracks=List<MotivationTrack>.of(_tracks);
    final originalPlaylists=List<MotivationPlaylist>.of(_playlists);
    final t=_tracks.removeAt(i);
    for(var k=0;k<_playlists.length;k++){
      final list=_playlists[k];
      _playlists[k]=MotivationPlaylist(id:list.id,title:list.title,
        trackIds:list.trackIds.where((x)=>x!=id).toList());
    }
    try{
      await _changed();
    }catch(_){
      // Never delete the media while its removal failed to persist.
      _tracks..clear()..addAll(originalTracks);
      _playlists..clear()..addAll(originalPlaylists);
      notifyListeners();
      rethrow;
    }
    final file=File(filePath(t));
    try{
      if(await file.exists())await file.delete();
    }catch(_){
      // The library no longer references this media. Do not roll back
      // committed metadata because an OS file delete was refused.
    }
    for(final name in [t.artworkFileName,t.thumbnailFileName]){
      if(name==null || p.basename(name)!=name || name.contains('..'))continue;
      final artwork=File(p.join(_directory!.path,name));
      try{
        if(await artwork.exists())await artwork.delete();
      }catch(_){
        // A stale cover is preferable to a broken user-facing library.
      }
    }
  }
  /// Create only explicitly selected playlist suggestions, never content.
  /// A playlist title that already exists is preserved rather than duplicated.
  Future<int> createSuggestedPlaylists(Iterable<String> suggestions) async {
    await load();
    final already={
      for(final playlist in _playlists)playlist.title.trim().toLowerCase(),
    };
    final previous=List<MotivationPlaylist>.of(_playlists);
    var created=0;
    for(final proposed in suggestions){
      final title=proposed.trim();
      if(title.isEmpty || title.length>70 ||
         !already.add(title.toLowerCase()))continue;
      _playlists.add(MotivationPlaylist(
        id:const Uuid().v4(),title:title,trackIds:const []));
      created++;
    }
    if(created>0)await _savePlaylistsWithRollback(previous);
    return created;
  }

  Future<void> createPlaylist(String title) async {
    final name=title.trim();
    if(name.isEmpty || name.length>70)return;
    if(_playlists.any((p)=>p.title.trim().toLowerCase()==name.toLowerCase()))
      return;
    final previous=List<MotivationPlaylist>.of(_playlists);
    _playlists.add(MotivationPlaylist(id:const Uuid().v4(),
      title:name,trackIds:const []));
    await _savePlaylistsWithRollback(previous);
  }
  /// Builds a new playlist only after the user reviews a local suggestion.
  /// This method never starts playback and never uploads media. Existing
  /// playlists and their order remain untouched if persistence fails.
  Future<bool> createContextPlaylist(String title,List<String> selectedIds) async {
    await load();
    final name=title.trim();
    if(name.isEmpty || name.length>70 || selectedIds.isEmpty)return false;
    if(_playlists.any((item)=>
        item.title.trim().toLowerCase()==name.toLowerCase()))return false;
    final available={for(final track in _tracks)track.id};
    final unique=<String>{};
    for(final id in selectedIds){
      if(available.contains(id))unique.add(id);
    }
    if(unique.isEmpty)return false;
    final previous=List<MotivationPlaylist>.of(_playlists);
    final added=MotivationPlaylist(id:const Uuid().v4(),
      title:name,trackIds:List<String>.unmodifiable(unique));
    _playlists.add(added);
    await _savePlaylistsWithRollback(previous);
    return true;
  }

  /// Flutter ReorderableListView passes newIndex one greater when dragging
  /// toward the bottom. Keep the resulting order persistent and stable.
  static List<String> moveIds(List<String> ids,int oldIndex,int newIndex){
    if(oldIndex<0 || oldIndex>=ids.length ||
       newIndex<0 || newIndex>ids.length){
      throw RangeError('Índices fuera de rango');
    }
    final next=List<String>.of(ids);
    if(oldIndex<newIndex)newIndex--;
    final id=next.removeAt(oldIndex);
    next.insert(newIndex,id);
    return next;
  }
  Future<void> reorderPlaylist(String id,int oldIndex,int newIndex) async {
    final i=_playlists.indexWhere((p)=>p.id==id);
    if(i<0)return;
    final current=_playlists[i];
    final ids=moveIds(current.trackIds,oldIndex,newIndex);
    if(listEquals(ids,current.trackIds))return;
    final previous=List<MotivationPlaylist>.of(_playlists);
    _playlists[i]=MotivationPlaylist(id:current.id,title:current.title,
      trackIds:ids);
    await _savePlaylistsWithRollback(previous);
  }
  Future<void> deletePlaylist(String id) async {
    if(!_playlists.any((list)=>list.id==id))return;
    final previous=List<MotivationPlaylist>.of(_playlists);
    _playlists.removeWhere((x)=>x.id==id);
    await _savePlaylistsWithRollback(previous);
  }
  Future<void> togglePlaylistTrack(String playlistId,String trackId) async {
    final i=_playlists.indexWhere((x)=>x.id==playlistId);
    if(i<0 || !_tracks.any((x)=>x.id==trackId))return;
    final list=_playlists[i], ids=List<String>.from(list.trackIds);
    if(ids.contains(trackId)){ids.remove(trackId);}else{ids.add(trackId);}
    final previous=List<MotivationPlaylist>.of(_playlists);
    _playlists[i]=MotivationPlaylist(id:list.id,title:list.title,trackIds:ids);
    await _savePlaylistsWithRollback(previous);
  }

  /// Restores the previous playlist snapshot and retries its persistence if
  /// writing the new metadata fails. No media files are ever deleted here.
  Future<void> _savePlaylistsWithRollback(
    List<MotivationPlaylist> previous,
  ) async {
    try{
      await _changed();
    }catch(_){
      _playlists..clear()..addAll(previous);
      try{
        await _changed();
      }catch(_){
        notifyListeners();
        // Recovery will retry at the next successful metadata operation.
      }
      rethrow;
    }
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
