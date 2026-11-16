import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart' show PlayerState, ProcessingState;
import 'package:gym_tracker/core/theme/app_colors.dart';
import '../application/motivation_playback.dart';
import '../application/motivation_library_search.dart';
import '../application/motivation_playlist_presets.dart';
import '../data/motivation_library.dart';
import 'widgets/motivation_audio_settings_sheet.dart';
import 'widgets/motivation_cover_crop_sheet.dart';

class _MotivationImportOptions {
  const _MotivationImportOptions({
    required this.title,
    required this.mode,
    required this.favorite,
    required this.playlistIds,
    required this.chooseArtwork,
  });
  final String title;
  final MotivationMode mode;
  final bool favorite;
  final Set<String> playlistIds;
  final bool chooseArtwork;
}

class MotivationPage extends StatefulWidget {
  const MotivationPage({super.key});
  @override
  State<MotivationPage> createState()=>_MotivationPageState();
}
class _MotivationPageState extends State<MotivationPage> {
  final library=MotivationLibrary.instance;
  final player=MotivationPlayback.instance;
  String selection='all';
  MotivationMode importMode=MotivationMode.discipline;
  bool busy=false;
  String searchQuery='';
  MotivationMediaFilter mediaFilter=MotivationMediaFilter.all;
  final searchController=TextEditingController();
  @override
  void initState(){
    super.initState();
    library.addListener(_refresh);
    player.addListener(_refresh);
    unawaited(player.loadAudioPreferences());
    unawaited(library.load().catchError((Object _){
      // Native exceptions may embed private device paths: never show them.
      _message('No se pudo abrir la biblioteca. Inténtalo de nuevo.');
    }));
  }
  void _refresh(){if(mounted)setState((){});}
  @override
  void dispose(){
    library.removeListener(_refresh);
    player.removeListener(_refresh);
    searchController.dispose();
    super.dispose();
  }
  void _message(String msg){
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content:Text(msg)));
  }
  Future<void> _import() async {
    if(busy)return;
    setState(()=>busy=true);
    try{
      final before=library.tracks.map((t)=>t.id).toSet();
      final count=await library.importFromPicker(mode:importMode);
      if(!mounted)return;
      _message(count==0?'No se añadieron archivos.':
        'Importados: '+count.toString()+' archivo(s).');
      // Entire personalization flow is optional: the imported media already
      // exists locally even if the user skips editing or cancels the picker.
      if(count>0){
        final imported=library.tracks.where((t)=>!before.contains(t.id)).toList();
        if(imported.isNotEmpty && mounted){
          final edit=await showModalBottomSheet<bool>(
            context:context,useSafeArea:true,showDragHandle:true,
            builder:(ctx)=>SafeArea(child:Column(
              mainAxisSize:MainAxisSize.min,children:[
                ListTile(
                  title:Text(imported.length==1
                    ? 'Personalizar archivo importado'
                    : 'Personalizar ${imported.length} archivos',
                    style:AppTypography.headlineMedium),
                  subtitle:const Text('Opcional: nombre, modo, favorito, '
                    'playlist y portada. Puedes editarlo después.'),
                ),
                ListTile(
                  leading:const Icon(Icons.edit_outlined),
                  title:const Text('Personalizar'),
                  onTap:()=>Navigator.pop(ctx,true),
                ),
                ListTile(
                  leading:const Icon(Icons.check_circle_outline),
                  title:const Text('Importar directamente'),
                  onTap:()=>Navigator.pop(ctx,false),
                ),
              ],
            )),
          );
          if(edit==true && mounted){
            for(final track in imported){
              if(!mounted)break;
              final options=await _importOptions(track);
              if(options==null)continue;
              final current=library.tracks.where((t)=>t.id==track.id).toList();
              if(current.isEmpty)continue;
              final selected=current.first;
              try{
                if(options.title.isNotEmpty &&
                    options.title.trim()!=selected.title){
                  await library.renameTrack(track.id,options.title.trim());
                }
                if(options.mode!=selected.mode){
                  await library.changeMode(track.id,options.mode);
                }
                if(options.favorite!=selected.favorite){
                  await library.toggleFavorite(track.id);
                }
                for(final id in options.playlistIds){
                  await library.togglePlaylistTrack(id,track.id);
                }
                if(options.chooseArtwork){
                  await library.chooseArtwork(
                    track.id,
                    requestFocus:(filePath)=>MotivationCoverCropSheet.show(
                      context,filePath),
                  );
                }
              }catch(_){
                if(mounted)_message('No se guardó la personalización. '
                  'El archivo importado se conserva.');
              }
            }
          }
        }
      }
    }catch(_){_message('No se pudo importar el archivo. '
      'Revisa el formato y vuelve a intentarlo.');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<_MotivationImportOptions?> _importOptions(
    MotivationTrack track) async {
    final controller=TextEditingController(text:track.title);
    var mode=track.mode;
    var favorite=track.favorite;
    var cover=false;
    final selectedLists=<String>{};
    try{
      return await showModalBottomSheet<_MotivationImportOptions>(
        context:context,useSafeArea:true,isScrollControlled:true,
        showDragHandle:true,
        builder:(ctx)=>StatefulBuilder(
          builder:(ctx,refresh)=>Padding(
            padding:EdgeInsets.only(bottom:MediaQuery.viewInsetsOf(ctx).bottom),
            child:FractionallySizedBox(
              heightFactor:.75,
              child:Column(children:[
                ListTile(
                  title:Text('Editar archivo',style:AppTypography.headlineMedium),
                  subtitle:Text(track.fileName,maxLines:1,
                    overflow:TextOverflow.ellipsis),
                ),
                Expanded(child:ListView(padding:const EdgeInsets.all(16),
                  children:[
                    TextField(
                      key:const ValueKey('motivation_import_title'),
                      controller:controller,maxLength:70,
                      decoration:const InputDecoration(
                        labelText:'Nombre (opcional)',
                        border:OutlineInputBorder()),
                    ),
                    DropdownButtonFormField<MotivationMode>(
                      initialValue:mode,
                      isExpanded:true,
                      decoration:const InputDecoration(
                        labelText:'Modo',border:OutlineInputBorder()),
                      items:[for(final value in MotivationMode.values)
                        DropdownMenuItem(value:value,child:Text(value.label))],
                      onChanged:(value){
                        if(value!=null)refresh(()=>mode=value);
                      },
                    ),
                    CheckboxListTile(
                      title:const Text('Añadir a favoritos'),
                      contentPadding:EdgeInsets.zero,value:favorite,
                      onChanged:(v)=>refresh(()=>favorite=v??false),
                    ),
                    CheckboxListTile(
                      title:const Text('Elegir portada privada'),
                      subtitle:Text(track.isVideo
                        ?'Si no eliges una imagen se usa la miniatura del MP4.'
                        :'Si no eliges imagen se usa el arte STK.'),
                      contentPadding:EdgeInsets.zero,value:cover,
                      onChanged:(v)=>refresh(()=>cover=v??false),
                    ),
                    if(library.playlists.isNotEmpty) ...[
                      const Divider(),
                      Text('Añadir a playlists',
                        style:AppTypography.headlineSmall),
                      for(final list in library.playlists)
                        CheckboxListTile(
                          title:Text(list.title),
                          contentPadding:EdgeInsets.zero,
                          value:selectedLists.contains(list.id),
                          onChanged:(v)=>refresh((){
                            if(v==true){selectedLists.add(list.id);}
                            else{selectedLists.remove(list.id);}
                          }),
                        ),
                    ],
                  ],
                )),
                Padding(padding:const EdgeInsets.all(16),child:Row(children:[
                  TextButton(
                    onPressed:()=>Navigator.pop(ctx),
                    child:const Text('Omitir archivo')),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed:(){
                      final title=controller.text.trim();
                      Navigator.pop(ctx,_MotivationImportOptions(
                        title:title.isEmpty?track.title:title,
                        mode:mode,favorite:favorite,
                        playlistIds:Set.of(selectedLists),
                        chooseArtwork:cover));
                    },
                    icon:const Icon(Icons.check_rounded),
                    label:const Text('Guardar cambios'),
                  ),
                ])),
              ]),
            ),
          ),
        ),
      );
    }finally{
      controller.dispose();
    }
  }

  Future<String?> _askName(String title,{String initial=''}) async {
    final controller=TextEditingController(text:initial);
    final name=await showDialog<String>(
      context:context,
      builder:(ctx)=>AlertDialog(
        title:Text(title),
        content:TextField(controller:controller,autofocus:true,maxLength:70,
          decoration:const InputDecoration(labelText:'Nombre')),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx),
            child:const Text('Cancelar')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,controller.text.trim()),
            child:const Text('Guardar')),
        ]));
    controller.dispose();
    return name==null||name.isEmpty?null:name;
  }
  Future<void> _createPlaylist() async {
    final name=await _askName('Nueva playlist');
    if(name!=null)await library.createPlaylist(name);
  }
  Future<void> _choosePlaylistIdeas() async {
    final missing=MotivationPlaylistPresets.notYetCreated(library.playlists);
    if(missing.isEmpty){
      _message('Ya tienes todas las playlists sugeridas.');
      return;
    }
    final selected=<String>{};
    final chosen=await showModalBottomSheet<List<String>>(
      context:context,useSafeArea:true,isScrollControlled:true,
      showDragHandle:true,
      builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh)=>SafeArea(
        child:Padding(
          padding:EdgeInsets.fromLTRB(
            16,8,16,16+MediaQuery.viewInsetsOf(ctx).bottom),
          child:Column(mainAxisSize:MainAxisSize.min,children:[
            ListTile(
              title:Text('Ideas para tus playlists',
                style:AppTypography.headlineMedium),
              subtitle:const Text('Elige solo las que quieras crear. '
                'No añadiremos archivos ni iniciaremos música.'),
            ),
            for(final name in missing)
              CheckboxListTile(
                key:ValueKey('motivation_preset_${name.hashCode}'),
                title:Text(name),value:selected.contains(name),
                onChanged:(value)=>refresh((){
                  if(value==true){selected.add(name);}
                  else{selected.remove(name);}
                }),
              ),
            const SizedBox(height:10),
            SizedBox(width:double.infinity,child:FilledButton(
              onPressed:selected.isEmpty?null:
                ()=>Navigator.pop(ctx,selected.toList()),
              child:Text('Crear ${selected.length} playlist(s)'),
            )),
          ]),
        ),
      )),
    );
    if(chosen==null || chosen.isEmpty || !mounted)return;
    try{
      final count=await library.createSuggestedPlaylists(chosen);
      if(mounted)_message('Playlists nuevas: $count.');
    }catch(_){
      if(mounted)_message('No se pudieron guardar las playlists.');
    }
  }

  /// A suggestion is shown only on request: no playlist or audio is
  /// created, modified or started before explicit user confirmation.
  Future<void> _suggestContextPlaylist() async {
    if(library.tracks.isEmpty){
      _message('Primero importa música o vídeos a tu biblioteca.');
      return;
    }
    final contextChoice=await showModalBottomSheet<MotivationPlaylistContext>(
      context:context,useSafeArea:true,showDragHandle:true,
      builder:(ctx)=>SafeArea(child:ListView(
        shrinkWrap:true,
        children:[
          ListTile(
            title:Text('¿Para qué momento?',
              style:AppTypography.headlineMedium),
            subtitle:const Text('Solo usaremos archivos locales. '
              'Elegir un contexto no inicia la reproducción.'),
          ),
          for(final option in MotivationPlaylistContext.values)
            ListTile(
              title:Text(option.title),
              subtitle:Text('Pistas en modo ${option.reason}'),
              trailing:const Icon(Icons.chevron_right_rounded),
              onTap:()=>Navigator.pop(ctx,option),
            ),
        ],
      )),
    );
    if(contextChoice==null || !mounted)return;
    final suggestions=MotivationPlaylistPresets.suggestTracks(
      library.tracks,contextChoice);
    if(suggestions.isEmpty){
      _message('No hay pistas para ese contexto. '
        'Puedes cambiar sus modos o crear una playlist manual.');
      return;
    }
    final selected=<String>{for(final track in suggestions)track.id};
    final picked=await showModalBottomSheet<List<String>>(
      context:context,useSafeArea:true,isScrollControlled:true,
      showDragHandle:true,
      builder:(ctx)=>FractionallySizedBox(
        heightFactor:.75,
        child:StatefulBuilder(builder:(ctx,refresh)=>Column(children:[
          Padding(padding:const EdgeInsets.fromLTRB(16,8,16,6),
            child:Column(
              crossAxisAlignment:CrossAxisAlignment.start,
              children:[
                Text(contextChoice.title,style:AppTypography.headlineMedium),
                const SizedBox(height:4),
                const Text('Revisa y elige tus pistas. No se reproducirá '
                  'ningún archivo automáticamente.'),
              ],
            )),
          Expanded(child:ListView(children:[
            for(final track in suggestions)
              CheckboxListTile(
                key:ValueKey('motivation_context_track_${track.id}'),
                secondary:_MotivationArtwork(track:track,size:42),
                title:Text(track.title,maxLines:2,
                  overflow:TextOverflow.ellipsis),
                subtitle:Text(track.mode.label),
                value:selected.contains(track.id),
                onChanged:(enabled)=>refresh((){
                  if(enabled==true){selected.add(track.id);}
                  else{selected.remove(track.id);}
                }),
              ),
          ])),
          SafeArea(top:false,child:Padding(
            padding:const EdgeInsets.all(16),
            child:SizedBox(width:double.infinity,child:FilledButton(
              onPressed:selected.isEmpty?null:()=>Navigator.pop(ctx,[
                for(final track in suggestions)
                  if(selected.contains(track.id))track.id,
              ]),
              child:Text('Continuar con ${selected.length} pistas'),
            )),
          )),
        ])),
      ),
    );
    if(picked==null || picked.isEmpty || !mounted)return;
    final title=await _askName('Guardar playlist sugerida',
      initial:contextChoice.title);
    if(title==null || !mounted)return;
    try{
      final created=await library.createContextPlaylist(title,picked);
      if(!mounted)return;
      _message(created
        ?'Playlist guardada. Puedes reproducirla cuando quieras.'
        :'No se creó la lista: revisa el nombre y que no exista otra igual.');
    }catch(_){
      if(mounted)_message('No se pudo guardar la playlist. '
        'Tus archivos originales se conservan.');
    }
  }

  Future<void> _edit(MotivationTrack track,String action) async {
    if(action=='favorite'){
      await library.toggleFavorite(track.id);
    }else if(action=='rename'){
      final title=await _askName('Renombrar',initial:track.title);
      if(title!=null)await library.renameTrack(track.id,title);
    }else if(action=='cover'){
      try{
        final saved=await library.chooseArtwork(
                    track.id,
                    requestFocus:(filePath)=>MotivationCoverCropSheet.show(
                      context,filePath),
                  );
        if(saved)_message('Portada guardada en este dispositivo.');
      }catch(_){_message('No se pudo guardar la portada. '
        'Revisa la imagen y vuelve a intentarlo.');}
    }else if(action=='clearCover'){
      await library.clearArtwork(track.id);
    }else if(action=='thumbnail'){
      final generated=await library.ensureVideoThumbnail(track.id);
      if(!generated)_message('Este video no permite extraer miniatura. '
        'Puedes elegir una imagen manual.');
    }else if(action=='mode'){
      if(!mounted)return;
      await showModalBottomSheet<void>(context:context,
        builder:(ctx)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,
          children:[for(final m in MotivationMode.values)
            ListTile(
              leading:Icon(m==track.mode?Icons.check_circle:
                Icons.circle_outlined),
              title:Text(m.label),
              onTap:(){
                Navigator.pop(ctx);
                unawaited(library.changeMode(track.id,m));
              }),
          ])));
    }else if(action=='list'){
      if(library.playlists.isEmpty){
        _message('Primero crea una playlist.');
        return;
      }
      if(!mounted)return;
      await showModalBottomSheet<void>(context:context,
        builder:(ctx)=>SafeArea(child:StatefulBuilder(
          builder:(ctx,update)=>Column(mainAxisSize:MainAxisSize.min,children:[
            const ListTile(title:Text('Añadir a playlists')),
            for(final list in library.playlists)
              CheckboxListTile(
                title:Text(list.title),value:list.trackIds.contains(track.id),
                onChanged:(_)async{
                  await library.togglePlaylistTrack(list.id,track.id);
                  update((){});
                }),
            TextButton(onPressed:()=>Navigator.pop(ctx),
              child:const Text('Listo')),
          ]))));
    }else if(action=='delete'){
      // The native queue may still contain this file even if another track
      // is currently selected. Deleting it without stopping the queue
      // could break playback several songs later.
      final queued=player.queue.any((item)=>item.id==track.id);
      final yes=await showDialog<bool>(context:context,
        builder:(ctx)=>AlertDialog(
          title:const Text('Eliminar archivo importado'),
          content:Text(queued
            ?'Solo se eliminará la copia privada de STK Haven. '
              'Este archivo está en la cola; se detendrá la reproducción '
              'antes de eliminarlo.'
            :'Solo se eliminará la copia privada de STK Haven.'),
          actions:[
            TextButton(onPressed:()=>Navigator.pop(ctx,false),
              child:const Text('Cancelar')),
            FilledButton(onPressed:()=>Navigator.pop(ctx,true),
              child:const Text('Eliminar')),
          ]));
      if(yes==true){
        if(queued)await player.stop();
        await library.removeTrack(track.id);
      }
    }
  }
  Future<void> _reorderCurrentPlaylist() async {
    if(!selection.startsWith('playlist:'))return;
    final id=selection.substring(9);
    final matching=library.playlists.where((p)=>p.id==id);
    if(matching.isEmpty)return;
    final list=matching.first;
    if(!mounted)return;
    await showModalBottomSheet<void>(
      context:context,
      isScrollControlled:true,
      useSafeArea:true,
      builder:(ctx)=>FractionallySizedBox(
        heightFactor:0.75,
        child:StatefulBuilder(builder:(ctx,refresh){
          final tracks=library.forSelection('playlist:$id');
          return Column(children:[
            ListTile(
              title:Text('Ordenar: ${list.title}'),
              subtitle:const Text('Mantén pulsado el asa para mover. '
                'Los cambios se guardan en el dispositivo.'),
              trailing:IconButton(
                tooltip:'Cerrar',
                onPressed:()=>Navigator.pop(ctx),
                icon:const Icon(Icons.close)),
            ),
            Expanded(
              child:tracks.isEmpty
                ?const Center(child:Text('Añade archivos antes de ordenar.'))
                :ReorderableListView.builder(
                  key:const ValueKey('motivation_playlist_reorder'),
                  buildDefaultDragHandles:false,
                  itemCount:tracks.length,
                  onReorder:(oldIndex,newIndex)async{
                    await library.reorderPlaylist(id,oldIndex,newIndex);
                    refresh((){});
                  },
                  itemBuilder:(context,i){
                    final track=tracks[i];
                    return ListTile(
                      key:ValueKey('reorder_${track.id}'),
                      title:Text(track.title,
                        maxLines:1,overflow:TextOverflow.ellipsis),
                      leading:Icon(track.isVideo
                        ?Icons.movie_outlined:Icons.music_note_outlined),
                      trailing:ReorderableDragStartListener(
                        index:i,child:const Icon(Icons.drag_handle)),
                    );
                  }),
            ),
            const SizedBox(height:12),
          ]);
        }),
      ),
    );
  }

  void _showAudioSettings(){
    showModalBottomSheet<void>(
      context:context,
      isScrollControlled:true,
      useSafeArea:true,
      builder:(ctx)=>const MotivationAudioSettingsSheet(),
    );
  }

  Future<void> _deleteList() async {
    final id=selection.substring(9);
    final yes=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Eliminar playlist'),
      content:const Text('Los archivos permanecerán en la biblioteca.'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),
          child:const Text('Cancelar')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),
          child:const Text('Eliminar')),
      ]));
    if(yes==true){
      await library.deletePlaylist(id);
      setState(()=>selection='all');
    }
  }
  Widget _filter(String key,String title){
    final colors=AppColors.of(context);
    return Padding(padding:const EdgeInsets.only(right:8),
      child:ChoiceChip(
        label:Text(title),selected:selection==key,
        selectedColor:colors.primaryFaded,
        labelStyle:TextStyle(color:selection==key?colors.primary:
          colors.textPrimary),
        onSelected:(_)=>setState(()=>selection=key)));
  }
  void _openNowPlaying() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const MotivationNowPlayingPage(),
    ));
  }

  Future<void> _playTrack(MotivationTrack track, List<MotivationTrack> tracks) async {
    // Opening the currently selected song must not restart its audio clock.
    if(player.currentTrack?.id != track.id){
      await player.playQueue(tracks,startIndex:tracks.indexOf(track));
    }
    if(!mounted)return;
    if(player.error!=null){
      _message(player.error!);
      return;
    }
    if(player.currentTrack!=null)_openNowPlaying();
  }

  Widget _player(){
    final track=player.currentTrack;
    if(track==null)return const SizedBox.shrink();
    final colors=AppColors.of(context);
    return Container(
      key:const ValueKey('motivation_now_playing'),
      decoration:BoxDecoration(color:colors.surfaceHigh,
        borderRadius:AppRadius.md_,
        border:Border.all(color:colors.surfaceBorder)),
      child:ListTile(
        contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:4),
        leading:_MotivationArtwork(track:track,size:52),
        title:Text(track.title,maxLines:1,overflow:TextOverflow.ellipsis,
          style:AppTypography.headlineSmall),
        subtitle:Text('Abrir reproductor · ${track.mode.label}',
          maxLines:1,overflow:TextOverflow.ellipsis,
          style:AppTypography.bodySmall.copyWith(color:colors.textSecondary)),
        onTap:_openNowPlaying,
        trailing:IconButton(
          tooltip:player.playing?'Pausar':'Reproducir',
          onPressed:()=>unawaited(player.togglePlay()),
          icon:Icon(player.playing?Icons.pause_circle_filled_rounded:
            Icons.play_circle_fill_rounded,color:colors.primary,size:32),
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context){
    final colors=AppColors.of(context);
    final tracks=MotivationLibrarySearch.filter(
      library.forSelection(selection),query:searchQuery,media:mediaFilter);
    return Scaffold(
      appBar:AppBar(title:const Text('STK Motivation'),
        actions:[
          IconButton(
            key:const ValueKey('motivation_settings'),
            tooltip:'Volumen, velocidad y temporizador',
            onPressed:_showAudioSettings,
            icon:const Icon(Icons.tune)),
          IconButton(tooltip:'Crear playlist',
            onPressed:()=>unawaited(_createPlaylist()),
            icon:const Icon(Icons.playlist_add)),
        ]),
      body:!library.loaded
        ?const Center(child:CircularProgressIndicator())
        :ListView(key:const ValueKey('motivation_library'),
          padding:const EdgeInsets.fromLTRB(16,16,16,100),
          children:[
            Text('Tu contenido, tu energía',
              style:AppTypography.headlineLarge),
            const SizedBox(height:5),
            Text('Importa tus MP3, M4A, WAV y MP4. Una copia privada '
              'permite reproducirlos sin internet.',
              style:AppTypography.bodyMedium.copyWith(
                color:colors.textSecondary)),
            const SizedBox(height:16),
            Row(children:[
              Expanded(child:DropdownButtonFormField<MotivationMode>(
                initialValue:importMode,
                decoration:const InputDecoration(
                  labelText:'Modo',border:OutlineInputBorder()),
                items:[for(final m in MotivationMode.values)
                  DropdownMenuItem(value:m,child:Text(m.label))],
                onChanged:(v){if(v!=null)setState(()=>importMode=v);},
              )),
              const SizedBox(width:8),
              FilledButton.icon(
                key:const ValueKey('motivation_import'),
                onPressed:busy?null:()=>unawaited(_import()),
                icon:const Icon(Icons.add),
                label:const Text('Importar')),
            ]),
            const SizedBox(height:16),
            if(player.currentTrack!=null)...[
              _player(),
              const SizedBox(height:20),
            ] else if(player.resumeTitle case final title?) ...[
              Card(
                key:const ValueKey('motivation_resume_last'),
                child:ListTile(
                  leading:const Icon(Icons.history_rounded),
                  title:Text('Retomar: $title',
                    maxLines:2,overflow:TextOverflow.ellipsis),
                  subtitle:const Text('Solo se reproduce cuando tú lo eliges.'),
                  trailing:const Icon(Icons.play_arrow_rounded),
                  onTap:()async{
                    final resumed=await player.resumeLast();
                    if(!mounted)return;
                    if(resumed){
                      _openNowPlaying();
                    }else{
                      _message('Ese archivo ya no está disponible.');
                    }
                  },
                ),
              ),
              const SizedBox(height:16),
            ],
            Row(children:[
              Expanded(child:Text('Colecciones',
                style:AppTypography.headlineMedium)),
              TextButton.icon(
                key:const ValueKey('motivation_playlist_ideas'),
                onPressed:()=>unawaited(_choosePlaylistIdeas()),
                icon:const Icon(Icons.auto_awesome_outlined),
                label:const Text('Ideas de listas'),
              ),
            ]),
            if(library.tracks.isNotEmpty)
              Align(
                alignment:Alignment.centerLeft,
                child:TextButton.icon(
                  key:const ValueKey('motivation_context_playlist_suggestion'),
                  onPressed:()=>unawaited(_suggestContextPlaylist()),
                  icon:const Icon(Icons.playlist_add_check_circle_outlined),
                  label:const Text('Sugerir según mi entrenamiento'),
                ),
              ),
            const SizedBox(height:9),
            SingleChildScrollView(scrollDirection:Axis.horizontal,
              child:Row(children:[
                _filter('all','Todos'),
                _filter('favorites','Favoritos'),
                for(final m in MotivationMode.values)
                  _filter('mode:'+m.name,m.label),
                for(final p in library.playlists)
                  _filter('playlist:'+p.id,p.title),
              ])),
            if(selection.startsWith('playlist:'))
              Row(mainAxisAlignment:MainAxisAlignment.end,children:[
                TextButton.icon(
                  onPressed:()=>unawaited(_reorderCurrentPlaylist()),
                  icon:const Icon(Icons.drag_handle),
                  label:const Text('Ordenar')),
                TextButton.icon(onPressed:()=>unawaited(_deleteList()),
                  icon:const Icon(Icons.delete_outline),
                  label:const Text('Eliminar lista')),
              ]),
            const SizedBox(height:12),
            TextField(
              key:const ValueKey('motivation_local_search'),
              controller:searchController,
              onChanged:(value)=>setState(()=>searchQuery=value),
              textInputAction:TextInputAction.search,
              decoration:InputDecoration(
                prefixIcon:const Icon(Icons.search_rounded),
                hintText:'Buscar en tus archivos',
                border:const OutlineInputBorder(),
                suffixIcon:searchQuery.isEmpty?null:IconButton(
                  tooltip:'Borrar búsqueda',
                  onPressed:(){
                    searchController.clear();
                    setState(()=>searchQuery='');
                  },
                  icon:const Icon(Icons.close_rounded)),
              ),
            ),
            const SizedBox(height:8),
            SingleChildScrollView(
              scrollDirection:Axis.horizontal,
              child:Row(children:[
                for(final choice in MotivationMediaFilter.values)
                  Padding(padding:const EdgeInsets.only(right:8),
                    child:ChoiceChip(
                      label:Text(switch(choice){
                        MotivationMediaFilter.all=>'Todos los medios',
                        MotivationMediaFilter.audio=>'Audios',
                        MotivationMediaFilter.video=>'Videos',
                      }),
                      selected:mediaFilter==choice,
                      onSelected:(_)=>setState(()=>mediaFilter=choice),
                    )),
              ]),
            ),
            const SizedBox(height:12),
            Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
              Text('Archivos ('+tracks.length.toString()+')',
                style:AppTypography.headlineMedium),
              TextButton.icon(onPressed:()=>unawaited(_createPlaylist()),
                icon:const Icon(Icons.add),label:const Text('Crear lista')),
            ]),
            if(tracks.isEmpty)
              Padding(padding:const EdgeInsets.symmetric(vertical:40),
                child:Column(children:[
                  Icon(Icons.library_music_outlined,size:54,
                    color:colors.textSecondary),
                  const SizedBox(height:12),
                  Text(searchQuery.isNotEmpty ||
                      mediaFilter!=MotivationMediaFilter.all
                    ? 'No encontramos coincidencias.'
                    : 'No hay archivos en esta colección.'),
                  if(searchQuery.isEmpty &&
                      mediaFilter==MotivationMediaFilter.all)
                    const Text('Importa contenido o añádelo a una playlist.'),
                ])),
            for(final t in tracks)
              Card(color:colors.surface,child:ListTile(
                key:ValueKey('track_'+t.id),
                leading:_MotivationArtwork(track:t,size:52),
                title:Text(t.title,maxLines:2,
                  overflow:TextOverflow.ellipsis),
                subtitle:Text(t.mode.label+' · '+(t.isVideo?'MP4':'Audio')),
                onTap:()=>unawaited(_playTrack(t,tracks)),
                trailing:PopupMenuButton<String>(
                  tooltip:'Opciones de archivo',
                  onSelected:(a)=>unawaited(_edit(t,a)),
                  itemBuilder:(_)=>[
                    PopupMenuItem(value:'favorite',child:Text(
                      t.favorite?'Quitar de favoritos':'Añadir a favoritos')),
                    const PopupMenuItem(value:'rename',child:Text('Renombrar')),
                    const PopupMenuItem(value:'cover',child:Text('Cambiar portada')),
                    if(t.artworkFileName!=null)
                      const PopupMenuItem(value:'clearCover',child:Text('Quitar portada')),
                    if(t.isVideo && t.thumbnailFileName==null)
                      const PopupMenuItem(value:'thumbnail',
                        child:Text('Generar miniatura del video')),
                    const PopupMenuItem(value:'mode',child:Text('Cambiar modo')),
                    const PopupMenuItem(value:'list',child:Text('Playlists')),
                    const PopupMenuItem(value:'delete',child:Text('Eliminar copia')),
                  ]),
              )),
          ]),
    );
  }
}

/// MP4 visuals are silent and synchronised to the background audio engine.
class _SilentVideoPreview extends StatefulWidget {
  const _SilentVideoPreview({super.key,required this.path,required this.playback,
    this.maxHeight=260});
  final String path;
  final MotivationPlayback playback;
  final double maxHeight;
  @override
  State<_SilentVideoPreview> createState()=>_SilentVideoPreviewState();
}
class _SilentVideoPreviewState extends State<_SilentVideoPreview>
    with WidgetsBindingObserver {
  VideoPlayerController? controller;
  final ValueNotifier<VideoPlayerController?> _cinemaSource=ValueNotifier(null);
  StreamSubscription<Duration>? position;
  StreamSubscription<PlayerState>? playing;
  bool ready=false,visible=true,seeking=false;
  bool _videoFailed=false;
  DateTime? _lastPositionCorrection;
  @override
  void initState(){
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.playback.addListener(_syncVideoLoop);
    unawaited(_setup());
  }
  @override
  void didUpdateWidget(covariant _SilentVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Changing the current MP4 can keep the same element/state. Never show
    // frames or seek events from the previous track with the new audio clock.
    if(oldWidget.path != widget.path ||
       oldWidget.playback != widget.playback){
      oldWidget.playback.removeListener(_syncVideoLoop);
      widget.playback.addListener(_syncVideoLoop);
      _resetVideoSource();
    }
  }

  void _resetVideoSource() {
    final previous=controller;
    controller=null;
    _cinemaSource.value=null;
    final oldPosition=position;
    final oldPlaying=playing;
    position=null;
    playing=null;
    ready=false;
    seeking=false;
    _videoFailed=false;
    _lastPositionCorrection=null;
    if(mounted)setState((){});
    if(oldPosition!=null)unawaited(oldPosition.cancel());
    if(oldPlaying!=null)unawaited(oldPlaying.cancel());
    if(previous!=null)unawaited(previous.dispose());
    unawaited(_setup());
  }

  Future<void> _setup() async {
    // Only an explicit retry creates another decoder after a failure.
    // Replacing a track disposes the previous controller in _resetVideoSource.
    if(controller!=null)return;
    _videoFailed=false;
    final c=VideoPlayerController.file(File(widget.path),
      videoPlayerOptions:VideoPlayerOptions(mixWithOthers:true));
    controller=c;
    try{
      await c.initialize();
      // A replacement/dispose already owns the old controller cleanup.
      if(!mounted || controller!=c)return;
      await c.setVolume(0);
      // Video has no audible track: just_audio is the only sound clock.
      // Its repeat-one policy must also be applied to the visual decoder.
      await c.setLooping(widget.playback.repeat==MotivationRepeat.one);
      await c.seekTo(widget.playback.position);
      if(widget.playback.playing && visible)unawaited(c.play());
      position=widget.playback.audio.positionStream.listen((pos){
        if(!mounted || controller!=c ||
           !c.value.isInitialized || !visible)return;
        final drift=(c.value.position-pos).inMilliseconds.abs();
        final now=DateTime.now();
        final loopJustRestarted=pos< const Duration(milliseconds:500) &&
          c.value.position>const Duration(seconds:2);
        final elapsed=_lastPositionCorrection==null
          ?const Duration(seconds:5)
          :now.difference(_lastPositionCorrection!);
        // Correct large drift, but not on every short position tick.
        if(drift>900 && !seeking &&
           (loopJustRestarted || elapsed>const Duration(milliseconds:900))){
          _lastPositionCorrection=now;
          seeking=true;
          unawaited(c.seekTo(pos).whenComplete(()=>seeking=false)
            .catchError((Object _){ /* Source was switched. */ }));
        }
      });
      playing=widget.playback.audio.playerStateStream.listen((state){
        if(!mounted || controller!=c || !c.value.isInitialized)return;
        if(state.playing &&
           state.processingState!=ProcessingState.completed && visible){
          unawaited(c.play());
        }else{
          unawaited(c.pause());
        }
      });
      _cinemaSource.value=c;
      setState((){
        ready=true;
        _videoFailed=false;
      });
    }catch(_){
      if(controller==c){
        controller=null;
        _cinemaSource.value=null;
        if(mounted)setState((){
          ready=false;
          _videoFailed=true;
        });
        unawaited(c.dispose());
      }
    }
  }
  void _syncVideoLoop(){
    final c=controller;
    if(!mounted || c==null || !c.value.isInitialized)return;
    final loop=widget.playback.repeat==MotivationRepeat.one;
    if(c.value.isLooping!=loop)unawaited(c.setLooping(loop));
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    visible=state==AppLifecycleState.resumed;
    final c=controller;
    if(c==null || !c.value.isInitialized)return;
    if(!visible){unawaited(c.pause());}
    else{
      unawaited(c.seekTo(widget.playback.position));
      if(widget.playback.playing)unawaited(c.play());
    }
  }
  @override
  void dispose(){
    WidgetsBinding.instance.removeObserver(this);
    widget.playback.removeListener(_syncVideoLoop);
    unawaited(position?.cancel());
    unawaited(playing?.cancel());
    final old=controller;
    controller=null;
    _cinemaSource.value=null;
    _cinemaSource.dispose();
    if(old!=null)unawaited(old.dispose());
    super.dispose();
  }
  void _openCinema() {
    final c=controller;
    if(c==null || !c.value.isInitialized || !mounted)return;
    // Reuse the existing silent controller. A second native decoder would
    // otherwise compete with the shared just_audio clock.
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder:(pageContext)=>Scaffold(
        backgroundColor:Colors.black,
        appBar:AppBar(
          backgroundColor:Colors.black,
          foregroundColor:Colors.white,
          title:const Text('Modo cine'),
        ),
        body:SafeArea(
          child:Column(children:[
            Expanded(
              child:ValueListenableBuilder<VideoPlayerController?>(
                valueListenable:_cinemaSource,
                builder:(ctx,active,_)=>Center(
                  child:active==null || !active.value.isInitialized
                    ?const Text('Video no disponible',
                        style:TextStyle(color:Colors.white))
                    :AspectRatio(
                      aspectRatio:active.value.aspectRatio,
                      child:VideoPlayer(active),
                    ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation:widget.playback,
              builder:(ctx,_) {
                final player=widget.playback;
                return Padding(
                  key:const ValueKey('motivation_cinema_shared_controls'),
                  padding:const EdgeInsets.fromLTRB(16,8,16,16),
                  child:Column(
                    mainAxisSize:MainAxisSize.min,
                    children:[
                      Text(
                        player.currentTrack?.title??'STK Motivation',
                        maxLines:1,overflow:TextOverflow.ellipsis,
                        style:AppTypography.bodyMedium.copyWith(
                          color:Colors.white),
                      ),
                      const SizedBox(height:4),
                      Text(
                        player.completed?'Reproducción finalizada':
                          player.playing?'Reproduciendo':'En pausa',
                        style:AppTypography.bodySmall.copyWith(
                          color:Colors.white70),
                      ),
                      const SizedBox(height:8),
                      Row(mainAxisAlignment:MainAxisAlignment.center,
                        children:[
                          IconButton(
                            tooltip:'Anterior',
                            color:Colors.white,
                            onPressed:player.currentTrack==null?null:
                              ()=>unawaited(player.previous()),
                            icon:const Icon(Icons.skip_previous_rounded,
                              size:32),
                          ),
                          const SizedBox(width:8),
                          IconButton.filled(
                            key:const ValueKey('motivation_cinema_toggle'),
                            tooltip:player.playing?'Pausar':'Reproducir',
                            onPressed:player.currentTrack==null?null:
                              ()=>unawaited(player.togglePlay()),
                            icon:Icon(player.playing?Icons.pause_rounded:
                              (player.completed?Icons.replay_rounded:
                                Icons.play_arrow_rounded),size:32),
                            style:IconButton.styleFrom(
                              minimumSize:const Size(56,56)),
                          ),
                          const SizedBox(width:8),
                          IconButton(
                            tooltip:player.canSkipNext
                              ?'Siguiente pista':'No hay otra pista',
                            color:Colors.white,
                            onPressed:player.canSkipNext
                              ?()=>unawaited(player.next()):null,
                            icon:const Icon(Icons.skip_next_rounded,size:32),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ]),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context){
    final c=controller;
    if(!ready || c==null)return Container(
      // Decoder errors must grow at 200% text, not clip a retry button
      // inside a fixed 180dp region.
      constraints:const BoxConstraints(minHeight:180),
      padding:const EdgeInsets.all(AppSpacing.md),
      alignment:Alignment.center,
      color:Theme.of(context).colorScheme.surfaceContainer,
      child:Column(mainAxisSize:MainAxisSize.min,
        mainAxisAlignment:MainAxisAlignment.center,children:[
        Icon(_videoFailed?Icons.broken_image_outlined:
          Icons.movie_outlined,size:36),
        if(_videoFailed)...[
          const SizedBox(height:8),
          Text('No se pudo mostrar el vídeo.',
            key:const ValueKey('motivation_video_decoder_error'),
            style:AppTypography.bodySmall),
          const SizedBox(height:8),
          OutlinedButton.icon(
            key:const ValueKey('motivation_video_retry'),
            onPressed:()=>unawaited(_setup()),
            icon:const Icon(Icons.refresh_rounded),
            label:const Text('Reintentar vídeo'),
          ),
        ],
      ]));
    return ClipRRect(borderRadius:AppRadius.md_,
      child:Stack(children:[
        ConstrainedBox(
          constraints:BoxConstraints(maxHeight:widget.maxHeight),
          child:AspectRatio(
            aspectRatio:c.value.aspectRatio,
            child:VideoPlayer(c))),
        Positioned(
          right:8,top:8,
          child:IconButton.filledTonal(
            tooltip:'Ver video en pantalla completa',
            onPressed:_openCinema,
            icon:const Icon(Icons.fullscreen_rounded),
          ),
        ),
      ]));
  }
}

class _MotivationArtwork extends StatelessWidget {
  const _MotivationArtwork({required this.track,required this.size});
  final MotivationTrack track;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors=AppColors.of(context);
    final path=MotivationLibrary.instance.artworkPath(track);
    return ClipRRect(
      borderRadius:BorderRadius.circular(size<80?11:20),
      child:SizedBox(width:size,height:size,
        child:path==null
          ?ColoredBox(color:colors.primaryFaded,
              child:Icon(track.isVideo?Icons.movie_outlined:
                Icons.music_note_rounded,color:colors.primary,size:size*.35))
          :Image.file(File(path),fit:BoxFit.cover,
              errorBuilder:(_,__,___)=>ColoredBox(
                color:colors.primaryFaded,
                child:Icon(Icons.image_not_supported_outlined,
                  color:colors.primary,size:size*.3)),
              ),
      ),
    );
  }
}

/// Dedicated STK playback surface. The engine is NOT recreated on navigation.
class MotivationNowPlayingPage extends StatefulWidget {
  const MotivationNowPlayingPage({super.key});

  @override
  State<MotivationNowPlayingPage> createState()=>_MotivationNowPlayingPageState();
}

class _MotivationNowPlayingPageState extends State<MotivationNowPlayingPage> {
  final player=MotivationPlayback.instance;
  final library=MotivationLibrary.instance;
  double? _scrubMs;
  String? _scrubTrackId;
  String _clock(Duration d){
    final minutes=d.inMinutes;
    return '${minutes.toString().padLeft(2,'0')}:'
      '${d.inSeconds.remainder(60).toString().padLeft(2,'0')}';
  }

  Future<void> _rename(MotivationTrack track) async {
    final ctrl=TextEditingController(text:track.title);
    final title=await showDialog<String>(context:context,builder:(ctx)=>
      AlertDialog(
        title:const Text('Nombre del archivo'),
        content:TextField(controller:ctrl,maxLength:70,autofocus:true,
          decoration:const InputDecoration(labelText:'Título')),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx),
            child:const Text('Cancelar')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,ctrl.text.trim()),
            child:const Text('Guardar')),
        ],
      ),
    );
    ctrl.dispose();
    if(title!=null && title.isNotEmpty)await library.renameTrack(track.id,title);
  }

  Future<void> _editArtwork(MotivationTrack track,{bool clear=false}) async {
    try{
      if(clear){
        await library.clearArtwork(track.id);
      }else{
        await library.chooseArtwork(
                    track.id,
                    requestFocus:(filePath)=>MotivationCoverCropSheet.show(
                      context,filePath),
                  );
      }
    }catch(_){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('No se pudo actualizar la portada. '
          'Comprueba el formato e inténtalo de nuevo.')));
    }
  }

  void _showQueue(){
    showModalBottomSheet<void>(
      context:context,useSafeArea:true,isScrollControlled:true,
      showDragHandle:true,
      builder:(ctx)=>FractionallySizedBox(
        heightFactor:.65,
        child:Column(children:[
          Padding(padding:const EdgeInsets.all(16),
            child:Text('A continuación',style:AppTypography.headlineMedium)),
          Expanded(child:ListView.builder(
            itemCount:player.queue.length,
            itemBuilder:(ctx,i){
              final track=player.queue[i];
              return ListTile(
                leading:_MotivationArtwork(track:track,size:40),
                title:Text(track.title,maxLines:1,overflow:TextOverflow.ellipsis),
                selected:player.currentTrack?.id==track.id,
                onTap:(){
                  Navigator.pop(ctx);
                  unawaited(player.playAtIndex(i));
                },
              );
            },
          )),
        ]),
      ),
    );
  }

  void _settings(){
    showModalBottomSheet<void>(context:context,isScrollControlled:true,
      useSafeArea:true,builder:(_)=>const MotivationAudioSettingsSheet());
  }

  @override
  Widget build(BuildContext context) {
    final colors=AppColors.of(context);
    return AnimatedBuilder(
      animation:Listenable.merge([player,library]),
      builder:(context,_) {
        final track=player.currentTrack;
        if(_scrubTrackId!=track?.id){
          _scrubTrackId=track?.id;
          _scrubMs=null;
        }
        return Scaffold(
          backgroundColor:colors.background,
          appBar:AppBar(
            title:const Text('STK Motivation'),
            actions:track==null?null:[
              IconButton(
                tooltip:track.favorite?'Quitar favorito':'Añadir favorito',
                onPressed:()=>unawaited(library.toggleFavorite(track.id)),
                icon:Icon(track.favorite?Icons.favorite:Icons.favorite_border,
                  color:track.favorite?colors.primary:null)),
              PopupMenuButton<String>(
                tooltip:'Editar archivo',
                onSelected:(value){
                  if(value=='rename')unawaited(_rename(track));
                  if(value=='cover')unawaited(_editArtwork(track));
                  if(value=='clearCover')
                    unawaited(_editArtwork(track,clear:true));
                },
                itemBuilder:(_)=>[
                  const PopupMenuItem(value:'rename',
                    child:Text('Renombrar')),
                  const PopupMenuItem(value:'cover',
                    child:Text('Elegir imagen')),
                  if(track.artworkFileName!=null)
                    const PopupMenuItem(value:'clearCover',
                      child:Text('Quitar portada')),
                ],
              ),
            ],
          ),
          body:SafeArea(
            child:track==null
              ?Center(child:Padding(
                  padding:const EdgeInsets.all(AppSpacing.lg),
                  child:Column(
                    mainAxisSize:MainAxisSize.min,
                    children:[
                      const Icon(Icons.music_off_outlined,size:36),
                      const SizedBox(height:AppSpacing.sm),
                      Text('No hay archivos reproduciéndose.',
                        textAlign:TextAlign.center,
                        style:AppTypography.bodyMedium),
                      // When a native codec fails the queue is cleared.
                      // The player still explains the failure without
                      // exposing a private file path to the UI.
                      if(player.error!=null)...[
                        const SizedBox(height:AppSpacing.sm),
                        Text(player.error!,
                          key:const ValueKey('motivation_safe_playback_error'),
                          textAlign:TextAlign.center,
                          style:AppTypography.bodySmall.copyWith(
                            color:colors.error)),
                      ],
                    ],
                  ),
                ))
              :LayoutBuilder(builder:(context,constraints){
                final artSize=(constraints.maxWidth-40).clamp(180.0,380.0);
                return ListView(
                  key:const ValueKey('stk_now_playing_screen'),
                  padding:const EdgeInsets.fromLTRB(20,12,20,32),
                  children:[
                    Center(
                      child:track.isVideo
                        ?_SilentVideoPreview(
                            key:const ValueKey('now_playing_video_shared'),
                            path:library.filePath(track),
                            playback:player,
                            maxHeight:artSize,
                          )
                        :AnimatedSwitcher(
                            duration:MediaQuery.of(context).disableAnimations
                              ?Duration.zero
                              :const Duration(milliseconds:180),
                            child:KeyedSubtree(
                              key:ValueKey('now_playing_audio_art_${track.id}_'
                                '${track.artworkFileName ?? 'fallback'}'),
                              child:_MotivationArtwork(
                                track:track,size:artSize),
                            ),
                          ),
                    ),
                    const SizedBox(height:22),
                    Text(track.title,maxLines:2,overflow:TextOverflow.ellipsis,
                      style:AppTypography.headlineLarge),
                    Text('STK Motivation · ${track.mode.label}',
                      style:AppTypography.bodyMedium.copyWith(
                        color:colors.textSecondary)),
                    if(player.completed)
                      Text('Finalizado · Puedes volver a reproducir',
                        style:AppTypography.bodySmall.copyWith(
                          color:colors.textSecondary)),
                    const SizedBox(height:20),
                    StreamBuilder<Duration>(
                      stream:player.audio.positionStream,
                      builder:(context,snapshot){
                        final position=snapshot.data??player.position;
                        final duration=player.duration??Duration.zero;
                        final max=duration.inMilliseconds;
                        final current=position.inMilliseconds.clamp(0,max);
                        final preview=(_scrubMs?.clamp(0,max.toDouble()) ??
                          current.toDouble()).toDouble();
                        return Column(children:[
                          Slider(
                            key:const ValueKey('motivation_scrubber'),
                            semanticFormatterCallback:(v)=>
                              '${_clock(Duration(milliseconds:v.round()))} '
                              'de ${_clock(duration)}',
                            value:preview,
                            max:max>0?max.toDouble():1,
                            onChangeStart:max==0?null:(v)=>
                              setState(()=>_scrubMs=v),
                            onChanged:max==0?null:(v)=>
                              setState(()=>_scrubMs=v),
                            // One seek on release, never a burst per pixel.
                            onChangeEnd:max==0?null:(v){
                              setState(()=>_scrubMs=null);
                              unawaited(player.seek(
                                Duration(milliseconds:v.round())));
                            },
                          ),
                          Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,
                            children:[
                              Text(_clock(Duration(milliseconds:preview.round())),
                                style:AppTypography.bodySmall),
                              Text(_clock(duration),style:AppTypography.bodySmall),
                            ]),
                        ]);
                      },
                    ),
                    const SizedBox(height:16),
                    Row(
                      mainAxisAlignment:MainAxisAlignment.spaceEvenly,
                      children:[
                        IconButton(
                          tooltip:player.queue.length<2
                            ?'El modo aleatorio requiere dos pistas'
                            :(player.shuffleActive?'Desactivar aleatorio':'Activar aleatorio'),
                          onPressed:player.queue.length<2?null:
                            ()=>unawaited(player.toggleShuffle()),
                          icon:Icon(Icons.shuffle_rounded,
                            color:player.shuffleActive?colors.primary:colors.textSecondary)),
                        IconButton(
                          tooltip:'Anterior',
                          onPressed:()=>unawaited(player.previous()),
                          icon:const Icon(Icons.skip_previous_rounded,size:34)),
                        IconButton.filled(
                          tooltip:player.playing?'Pausar':'Reproducir',
                          onPressed:()=>unawaited(player.togglePlay()),
                          icon:Icon(player.playing?Icons.pause_rounded:
                            (player.completed?Icons.replay_rounded:
                            Icons.play_arrow_rounded),size:36),
                          style:IconButton.styleFrom(minimumSize:const Size(70,70),
                            backgroundColor:colors.primary,
                            foregroundColor:colors.onPrimary)),
                        IconButton(
                          key:const ValueKey('motivation_next_track'),
                          tooltip:player.canSkipNext
                            ?'Siguiente pista'
                            :'No hay otra pista disponible',
                          onPressed:player.canSkipNext
                            ?()=>unawaited(player.next()):null,
                          icon:const Icon(Icons.skip_next_rounded,size:34)),
                        PopupMenuButton<MotivationRepeat>(
                          key:const ValueKey('motivation_repeat_picker'),
                          tooltip:'Reproducción: ${player.repeat.label}',
                          onSelected:(repeat)=>unawaited(player.setRepeat(repeat)),
                          icon:Icon(
                            player.repeat==MotivationRepeat.one
                              ?Icons.repeat_one_rounded:Icons.repeat_rounded,
                            color:player.repeat==MotivationRepeat.next
                              ?colors.textSecondary:colors.primary),
                          itemBuilder:(_)=>[
                            for(final mode in MotivationRepeat.values)
                              PopupMenuItem(value:mode,
                                child:Row(children:[
                                  if(player.repeat==mode)
                                    Icon(Icons.check,color:colors.primary,size:17),
                                  const SizedBox(width:8),Text(mode.label),
                                ])),
                          ],
                        ),
                      ],
                    ),
                    Semantics(
                      liveRegion:true,
                      child:Text(
                        'Modo: ${player.repeat.label}',
                        key:const ValueKey('motivation_repeat_state'),
                        textAlign:TextAlign.center,
                        style:AppTypography.bodySmall.copyWith(
                          color:colors.textSecondary),
                      ),
                    ),
                    const SizedBox(height:16),
                    OutlinedButton.icon(
                      onPressed:_showQueue,
                      icon:const Icon(Icons.queue_music_rounded),
                      label:const Text('A continuación'),
                    ),
                    TextButton.icon(
                      onPressed:_settings,
                      icon:const Icon(Icons.tune_rounded),
                      label:const Text('Volumen · Velocidad · Apagado'),
                    ),
                    if(player.error!=null)
                      Text(player.error!,style:AppTypography.bodySmall.copyWith(
                        color:colors.error)),
                  ],
                );
              }),
          ),
        );
      },
    );
  }
}
