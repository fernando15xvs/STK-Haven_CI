import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import '../application/motivation_playback.dart';
import '../data/motivation_library.dart';
import 'widgets/motivation_audio_settings_sheet.dart';

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
  bool busy=false, showVideo=true;
  @override
  void initState(){
    super.initState();
    library.addListener(_refresh);
    player.addListener(_refresh);
    unawaited(player.loadAudioPreferences());
    unawaited(library.load().catchError((Object e){
      _message('No se pudo abrir la biblioteca: '+e.toString());
    }));
  }
  void _refresh(){if(mounted)setState((){});}
  @override
  void dispose(){
    library.removeListener(_refresh);
    player.removeListener(_refresh);
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
      final count=await library.importFromPicker(mode:importMode);
      _message(count==0?'No se añadieron archivos.':
        'Importados: '+count.toString()+' archivo(s).');
    }catch(e){_message('Error de importación: '+e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
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
  Future<void> _edit(MotivationTrack track,String action) async {
    if(action=='favorite'){
      await library.toggleFavorite(track.id);
    }else if(action=='rename'){
      final title=await _askName('Renombrar',initial:track.title);
      if(title!=null)await library.renameTrack(track.id,title);
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
      final yes=await showDialog<bool>(context:context,
        builder:(ctx)=>AlertDialog(
          title:const Text('Eliminar archivo importado'),
          content:const Text('Solo se eliminará la copia privada de STK Haven.'),
          actions:[
            TextButton(onPressed:()=>Navigator.pop(ctx,false),
              child:const Text('Cancelar')),
            FilledButton(onPressed:()=>Navigator.pop(ctx,true),
              child:const Text('Eliminar')),
          ]));
      if(yes==true){
        if(player.currentTrack?.id==track.id)await player.stop();
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
  String _clock(Duration d)=>d.inMinutes.toString() + ':' +
    d.inSeconds.remainder(60).toString().padLeft(2,'0');

  Widget _player(){
    final track=player.currentTrack;
    if(track==null)return const SizedBox.shrink();
    final colors=AppColors.of(context);
    final duration=player.duration??Duration.zero;
    return Container(
      key:const ValueKey('motivation_now_playing'),
      padding:const EdgeInsets.all(12),
      decoration:BoxDecoration(color:colors.surface,borderRadius:AppRadius.lg_,
        border:Border.all(color:colors.surfaceBorder)),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          Icon(track.isVideo?Icons.movie_outlined:Icons.graphic_eq,
            color:colors.primary),
          const SizedBox(width:10),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
            children:[
              Text(track.title,maxLines:1,overflow:TextOverflow.ellipsis,
                style:AppTypography.headlineMedium),
              Text(track.mode.label+' · '+(track.isVideo?'MP4':'Audio'),
                style:AppTypography.bodySmall),
            ])),
          IconButton(
            key:const ValueKey('motivation_favorite_current'),
            tooltip:track.favorite?'Quitar favorito':'Añadir favorito',
            onPressed:()=>unawaited(library.toggleFavorite(track.id)),
            icon:Icon(track.favorite?Icons.favorite:Icons.favorite_border,
              color:track.favorite?colors.primary:null)),
          IconButton(tooltip:'Detener',onPressed:()=>unawaited(player.stop()),
            icon:const Icon(Icons.stop_circle_outlined)),
        ]),
        if(track.isVideo)...[
          const SizedBox(height:10),
          if(showVideo)
            _SilentVideoPreview(
              key:ValueKey('preview_'+track.id),
              path:library.filePath(track),playback:player),
          TextButton.icon(
            onPressed:()=>setState(()=>showVideo=!showVideo),
            icon:Icon(showVideo?Icons.visibility_off:Icons.visibility),
            label:Text(showVideo?'Ocultar video':'Mostrar video')),
        ],
        StreamBuilder<Duration>(
          stream:player.audio.positionStream,
          builder:(ctx,s){
            final pos=s.data??player.position;
            final max=duration.inMilliseconds;
            return Column(children:[
              Slider(value:pos.inMilliseconds.clamp(0,max).toDouble(),
                max:max==0?1:max.toDouble(),
                onChanged:max==0?null:(v)=>unawaited(player.seek(
                  Duration(milliseconds:v.round())))),
              Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,
                children:[Text(_clock(pos)),Text(_clock(duration))]),
            ]);
          }),
        Row(mainAxisAlignment:MainAxisAlignment.center,children:[
          IconButton(tooltip:'Anterior',iconSize:32,
            onPressed:()=>unawaited(player.previous()),
            icon:const Icon(Icons.skip_previous)),
          IconButton.filled(tooltip:player.playing?'Pausar':'Reproducir',
            onPressed:()=>unawaited(player.togglePlay()),
            icon:Icon(player.playing?Icons.pause:Icons.play_arrow),
            iconSize:32),
          IconButton(tooltip:'Siguiente',iconSize:32,
            onPressed:()=>unawaited(player.next()),
            icon:const Icon(Icons.skip_next)),
        ]),
        Row(children:[
          Expanded(child:DropdownButtonHideUnderline(child:
            DropdownButton<MotivationRepeat>(
              isExpanded:true,value:player.repeat,
              items:[for(final r in MotivationRepeat.values)
                DropdownMenuItem(value:r,child:Text(r.label))],
              onChanged:(r){if(r!=null)unawaited(player.setRepeat(r));},
            ))),
          IconButton(
            tooltip:player.shuffle?'Desactivar aleatorio':'Activar aleatorio',
            onPressed:()=>unawaited(player.toggleShuffle()),
            icon:Icon(Icons.shuffle,
              color:player.shuffle?colors.primary:null)),
        ]),
        if(player.sleepTimer.active)
          Text('Apagado programado activo',
            style:TextStyle(color:colors.primary)),
        Text('El audio continúa con la pantalla bloqueada; '
          'el video solo se muestra dentro de STK Haven.',
          style:AppTypography.bodySmall.copyWith(color:colors.textSecondary)),
        if(player.error!=null)
          Text(player.error!,style:TextStyle(color:colors.error)),
      ]),
    );
  }
  @override
  Widget build(BuildContext context){
    final colors=AppColors.of(context);
    final tracks=library.forSelection(selection);
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
            ],
            Text('Colecciones',style:AppTypography.headlineMedium),
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
                  const Text('No hay archivos en esta colección.'),
                  const Text('Importa contenido o añádelo a una playlist.'),
                ])),
            for(final t in tracks)
              Card(color:colors.surface,child:ListTile(
                key:ValueKey('track_'+t.id),
                leading:Icon(t.isVideo?Icons.movie_outlined:
                  Icons.music_note_outlined,color:colors.primary),
                title:Text(t.title,maxLines:2,
                  overflow:TextOverflow.ellipsis),
                subtitle:Text(t.mode.label+' · '+(t.isVideo?'MP4':'Audio')),
                onTap:()=>unawaited(player.playQueue(
                  tracks,startIndex:tracks.indexOf(t))),
                trailing:PopupMenuButton<String>(
                  tooltip:'Opciones de archivo',
                  onSelected:(a)=>unawaited(_edit(t,a)),
                  itemBuilder:(_)=>[
                    PopupMenuItem(value:'favorite',child:Text(
                      t.favorite?'Quitar de favoritos':'Añadir a favoritos')),
                    const PopupMenuItem(value:'rename',child:Text('Renombrar')),
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
  const _SilentVideoPreview({super.key,required this.path,required this.playback});
  final String path;
  final MotivationPlayback playback;
  @override
  State<_SilentVideoPreview> createState()=>_SilentVideoPreviewState();
}
class _SilentVideoPreviewState extends State<_SilentVideoPreview>
    with WidgetsBindingObserver {
  VideoPlayerController? controller;
  StreamSubscription<Duration>? position;
  StreamSubscription<bool>? playing;
  bool ready=false,visible=true,seeking=false;
  @override
  void initState(){
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_setup());
  }
  Future<void> _setup() async {
    final c=VideoPlayerController.file(File(widget.path),
      videoPlayerOptions:VideoPlayerOptions(mixWithOthers:true));
    controller=c;
    try{
      await c.initialize();
      if(!mounted || controller!=c)return;
      await c.setVolume(0);
      await c.seekTo(widget.playback.position);
      if(widget.playback.playing && visible)unawaited(c.play());
      position=widget.playback.audio.positionStream.listen((pos){
        if(!mounted || !c.value.isInitialized || !visible)return;
        if((c.value.position-pos).inMilliseconds.abs()>900 && !seeking){
          seeking=true;
          unawaited(c.seekTo(pos).whenComplete(()=>seeking=false));
        }
      });
      playing=widget.playback.audio.playingStream.listen((value){
        if(!mounted || !c.value.isInitialized)return;
        if(value && visible){unawaited(c.play());}
        else{unawaited(c.pause());}
      });
      setState(()=>ready=true);
    }catch(_){if(mounted)setState(()=>ready=false);}
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
    unawaited(position?.cancel());
    unawaited(playing?.cancel());
    if(controller!=null)unawaited(controller!.dispose());
    super.dispose();
  }
  @override
  Widget build(BuildContext context){
    final c=controller;
    if(!ready || c==null)return Container(
      height:180,alignment:Alignment.center,
      color:Theme.of(context).colorScheme.surfaceContainer,
      child:const Icon(Icons.movie_outlined,size:40));
    return ClipRRect(borderRadius:AppRadius.md_,
      child:ConstrainedBox(
        constraints:const BoxConstraints(maxHeight:260),
        child:AspectRatio(
          aspectRatio:c.value.aspectRatio,
          child:VideoPlayer(c))));
  }
}
