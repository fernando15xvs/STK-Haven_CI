/// Local snapshot of a listening session. It carries only stable library IDs,
/// never paths, audio bytes, remote URLs or autoplay permission.
class MotivationResumeSnapshot {
  const MotivationResumeSnapshot({
    required this.trackId,
    required this.queueIds,
    required this.positionMs,
  });

  final String trackId;
  final List<String> queueIds;
  final int positionMs;

  Map<String,dynamic> toJson()=>{
    'v':1,
    'trackId':trackId,
    'queueIds':queueIds,
    'positionMs':positionMs,
  };

  factory MotivationResumeSnapshot.fromJson(Map<String,dynamic> json){
    if(json['v']!=1)throw const FormatException('Versión incompatible');
    final id=json['trackId'];
    final raw=json['queueIds'];
    final position=json['positionMs'];
    if(id is! String || id.isEmpty ||
       raw is! List || raw.isEmpty || raw.length>500 ||
       position is! int || position<0 ||
       position>24*60*60*1000){
      throw const FormatException('Sesión anterior inválida');
    }
    final ids=<String>[];
    for(final element in raw){
      if(element is! String || element.isEmpty || element.length>128){
        throw const FormatException('Identificador inválido');
      }
      if(!ids.contains(element))ids.add(element);
    }
    if(!ids.contains(id))throw const FormatException('Pista ausente');
    return MotivationResumeSnapshot(
      trackId:id,
      queueIds:List.unmodifiable(ids),
      positionMs:position,
    );
  }
}
