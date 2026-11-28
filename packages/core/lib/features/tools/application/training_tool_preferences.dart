import 'dart:convert';
import 'package:core/core/services/core_preferences.dart';
import 'package:riverpod/riverpod.dart';

/// Device preferences only: no exercise IDs, account IDs, targets or history.
/// Separate units avoid treating pounds as kilograms.
final trainingToolPreferencesProvider=Provider<TrainingToolPreferences>(
  (ref)=>TrainingToolPreferences(null));

class PlatePreferences {
  final double barWeight;
  final bool limited;
  final Map<double,int> stock;
  PlatePreferences({required this.barWeight,required this.limited,required Map<double,int> stock})
    :stock=Map.unmodifiable(stock);
  static List<double> plates(bool lb)=>lb?const [45,35,25,10,5,2.5]:
    const [25,20,15,10,5,2.5,1.25];
  factory PlatePreferences.defaults(bool lb)=>PlatePreferences(
    barWeight:lb?45:20,limited:false,stock:{for(final p in plates(lb))p:2});
  Map<String,dynamic> toJson()=>{'bar':barWeight,'limited':limited,
    'stock':{for(final e in stock.entries)e.key.toString():e.value}};
  factory PlatePreferences.fromJson(Map<String,dynamic> json,bool lb){
    final defaults=PlatePreferences.defaults(lb);
    final bar=json['bar'];
    final raw=json['stock'];
    if(bar is! num || !bar.isFinite || bar<=0 || bar>2000 ||
       json['limited'] is! bool || raw is! Map) return defaults;
    final stock=<double,int>{};
    for(final p in plates(lb)){
      final n=raw[p.toString()];
      if(n is! int || n<0 || n>200)return defaults;
      stock[p]=n;
    }
    return PlatePreferences(barWeight:bar.toDouble(),limited:json['limited'] as bool,stock:stock);
  }
}

class TrainingToolPreferences {
  final CorePreferenceStore? _store;
  TrainingToolPreferences(this._store);
  static const timerKey='stk_training_free_timer_v1';
  static String plateKey(bool lb)=>'stk_training_plates_v1_${lb?'lb':'kg'}';
  Map<String,dynamic>? read(String key){
    try{
      final raw=_store?.getString(key);
      if(raw==null)return null;
      final decoded=jsonDecode(raw);
      return decoded is Map<String,dynamic>?decoded:null;
    }catch(_){return null;}
  }
  Future<bool> write(String key,Map<String,dynamic> value)async{
    try{return await _store?.setString(key,jsonEncode(value))??false;}
    catch(_){return false;}
  }
  PlatePreferences loadPlates(bool lb)=>PlatePreferences.fromJson(read(plateKey(lb))??{},lb);
  Future<bool> savePlates(bool lb,PlatePreferences value)=>write(plateKey(lb),value.toJson());
}
