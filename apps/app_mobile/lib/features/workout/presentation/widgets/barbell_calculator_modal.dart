import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:core/features/profile/application/providers/settings_provider.dart';
import 'package:core/domain/models/settings_state.dart';
import 'package:core/features/workout/application/barbell_calculator.dart';
import 'package:core/features/tools/application/training_tool_preferences.dart';

class BarbellCalculatorModal extends ConsumerStatefulWidget {
  final double? initialTargetWeight;
  final String? contextLabel;

  const BarbellCalculatorModal({super.key, this.initialTargetWeight,this.contextLabel});

  static Future<void> show(
    BuildContext context, {
    double? initialTargetWeight,
    String? contextLabel,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final keyboard = MediaQuery.viewInsetsOf(sheetContext).bottom;
        final available = MediaQuery.sizeOf(sheetContext).height - keyboard;
        return Padding(
          padding: EdgeInsets.only(bottom: keyboard),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: available * .86),
            child: BarbellCalculatorModal(initialTargetWeight: initialTargetWeight,contextLabel:contextLabel),
          ),
        );
      },
    );
  }

  @override
  ConsumerState<BarbellCalculatorModal> createState() =>
      _BarbellCalculatorModalState();
}

class _BarbellCalculatorModalState extends ConsumerState<BarbellCalculatorModal> {
  late final TextEditingController _weightCtrl;
  late final TextEditingController _barCtrl;
  late final WeightUnit _unit;
  late final List<double> _plates;
  final Map<double,int> _stock={};
  bool _limited=false;
  bool _saving=false;
  @override void initState(){
    super.initState();
    _unit=ref.read(settingsProvider).weightUnit;
    final lb=_unit==WeightUnit.lb;
    final saved=ref.read(trainingToolPreferencesProvider).loadPlates(lb);
    _plates=PlatePreferences.plates(lb);
    _stock.addAll(saved.stock);
    _limited=saved.limited;
    _barCtrl=TextEditingController(text:_fmt(saved.barWeight));
    _weightCtrl=TextEditingController(text:widget.initialTargetWeight==null?'':_fmt(widget.initialTargetWeight!));
  }
  @override void dispose(){_weightCtrl.dispose();_barCtrl.dispose();super.dispose();}
  String _fmt(double value)=>value.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'),'');
  double? _parse(String value){
    final number=double.tryParse(value.trim().replaceAll(',','.'));
    return number!=null&&number.isFinite&&number>0&&number<=2000?number:null;
  }
  Future<void> _saveConfiguration({bool reset=false}) async {
    if(_saving)return;
    final lb=_unit==WeightUnit.lb;
    final bar=_parse(_barCtrl.text);
    if(!reset&&bar==null)return;
    final config=reset?PlatePreferences.defaults(lb):
      PlatePreferences(barWeight:bar!,limited:_limited,stock:_stock);
    setState(()=>_saving=true);
    final ok=await ref.read(trainingToolPreferencesProvider).savePlates(lb,config);
    if(!mounted)return;
    setState((){
      _saving=false;
      if(ok&&reset){
        _barCtrl.text=_fmt(config.barWeight);
        _stock..clear()..addAll(config.stock);
        _limited=config.limited;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(ok?
      (reset?'Configuración restablecida':'Configuración guardada en este dispositivo'):
      'No se pudo guardar la configuración.')));
  }
  @override Widget build(BuildContext context){
    final colors=AppColors.of(context);
    final target=_parse(_weightCtrl.text);
    final bar=_parse(_barCtrl.text);
    final result=target==null||bar==null?null:BarbellCalculator.calculate(
      targetWeight:target,barWeight:bar,availablePlates:_plates,inventory:_limited?_stock:null);
    final counts=<double,int>{};
    for(final plate in result?.platesPerSide??const <Plate>[]){counts.update(plate.weight,(n)=>n+1,ifAbsent:()=>1);}
    return Container(
      decoration:BoxDecoration(color:colors.surfaceHigh,borderRadius:const BorderRadius.vertical(top:Radius.circular(24))),
      padding:const EdgeInsets.fromLTRB(16,8,16,12),
      child:Column(mainAxisSize:MainAxisSize.min,children:[
        Row(children:[
          Expanded(child:Text('Calculadora de discos',style:AppTypography.headlineMedium)),
          IconButton(key:const Key('barbell_calculator_close'),tooltip:'Cerrar calculadora',onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close)),
        ]),
        Flexible(child:SingleChildScrollView(
          keyboardDismissBehavior:ScrollViewKeyboardDismissBehavior.onDrag,
          child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            if(widget.contextLabel!=null) Text(widget.contextLabel!,style:AppTypography.bodySmall),
            const SizedBox(height:12),
            TextField(controller:_weightCtrl,keyboardType:const TextInputType.numberWithOptions(decimal:true),
              decoration:InputDecoration(labelText:'Peso objetivo total (${_unit.label})'),onChanged:(_)=>setState((){})),
            const SizedBox(height:10),
            TextField(controller:_barCtrl,keyboardType:const TextInputType.numberWithOptions(decimal:true),
              decoration:InputDecoration(labelText:'Peso de la barra (${_unit.label})'),onChanged:(_)=>setState((){})),
            Wrap(spacing:8,children:[
              for(final weight in (_unit==WeightUnit.lb?const [15.0,35.0,45.0]:const [10.0,15.0,20.0]))
                ChoiceChip(label:Text('${_fmt(weight)} ${_unit.label}'),selected:bar==weight,
                  onSelected:(_)=>setState(()=>_barCtrl.text=_fmt(weight))),
            ]),
            const SizedBox(height:12),
            if(result==null)const Text('Introduce un peso de barra y objetivo válidos (hasta 2000).')
            else if(result.belowBar)
              Text('No es posible: la barra sola pesa ${_fmt(result.barWeight)} ${_unit.label}.',style:AppTypography.bodyMedium.copyWith(color:colors.warning))
            else ...[
              Text('Peso alcanzable',style:AppTypography.bodySmall),
              Text('${_fmt(result.actualTotalWeight)} ${_unit.label}',style:AppTypography.headlineLarge),
              Text(result.exact?'Peso exacto':'Faltan ${_fmt(result.remainder)} ${_unit.label} para el objetivo',
                style:AppTypography.bodyMedium.copyWith(color:result.exact?colors.success:colors.warning)),
              const SizedBox(height:12),
              if(counts.isNotEmpty)
                Semantics(label:'Distribución simétrica, mismos discos en ambos lados',child:ExcludeSemantics(
                  child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[
                    for(final plate in counts.entries) _plate(context,plate.key,plate.value),
                    Container(width:64,height:10,color:colors.textSecondary),
                    for(final plate in counts.entries.toList().reversed) _plate(context,plate.key,plate.value),
                  ])))),
              Text('Por cada lado · ${_fmt(result.weightPerSide)} ${_unit.label}',style:AppTypography.headlineSmall),
              if(counts.isEmpty)const Text('Solo la barra vacía.')
              else for(final plate in counts.entries)
                Text('${plate.value} × ${_fmt(plate.key)} ${_unit.label}'),
            ],
            const SizedBox(height:12),
            ExpansionTile(tilePadding:EdgeInsets.zero,title:const Text('Configurar discos disponibles'),children:[
              SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Limitar al inventario real'),
                subtitle:const Text('Número total de discos de cada peso (ambos lados).'),
                value:_limited,onChanged:(v)=>setState(()=>_limited=v)),
              if(_limited)for(final weight in _plates)
                Row(children:[
                  Expanded(child:Text('${_fmt(weight)} ${_unit.label}')),
                  IconButton(tooltip:'Quitar disco de ${_fmt(weight)}',onPressed:_stock[weight]==0?null:()=>setState(()=>_stock[weight]=_stock[weight]!-1),icon:const Icon(Icons.remove)),
                  Text('${_stock[weight]}'),
                  IconButton(tooltip:'Añadir disco de ${_fmt(weight)}',onPressed:_stock[weight]==200?null:()=>setState(()=>_stock[weight]=_stock[weight]!+1),icon:const Icon(Icons.add)),
                ]),
            ]),
            FilledButton.tonalIcon(key:const ValueKey('plates_save_configuration'),
              onPressed:_saving||bar==null?null:()=>_saveConfiguration(),
              icon:const Icon(Icons.save_outlined),label:const Text('Guardar barra y discos')),
            TextButton(onPressed:_saving?null:()=>_saveConfiguration(reset:true),
              child:const Text('Restablecer configuración')),
            const Text('Se guarda en este dispositivo por unidad kg/lb. No se guarda el peso objetivo.'),
            const Text('Referencia de carga, no modifica la serie. Comprueba el peso real del equipo.'),
            const SizedBox(height:16),
          ]),
        )),
      ]),
    );
  }
  Widget _plate(BuildContext context,double weight,int count){
    final colors=AppColors.of(context);
    return Container(
      margin:const EdgeInsets.symmetric(horizontal:2),
      width:28,height:42+weight/_plates.first*46,
      decoration:BoxDecoration(color:colors.primaryFaded,border:Border.all(color:colors.primary),borderRadius:BorderRadius.circular(4)),
      alignment:Alignment.center,child:RotatedBox(quarterTurns:3,
        child:Text('${count}×${_fmt(weight)}',style:AppTypography.labelSmall,maxLines:1)),
    );
  }
}
