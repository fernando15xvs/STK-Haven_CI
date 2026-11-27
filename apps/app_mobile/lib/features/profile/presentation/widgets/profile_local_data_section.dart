import 'package:core/domain/models/user_experience_profile.dart';
import 'package:core/domain/models/nutrition_intelligence.dart';
import 'package:core/features/profile/application/providers/user_experience_profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/core/theme/components/premium_card.dart';

/// Local demographic permission is not a legal receipt or age verification.
/// The same core merge used by the profile editor protects concurrent changes.
class ProfileLocalDataSection extends ConsumerStatefulWidget {
  const ProfileLocalDataSection({super.key});

  @override
  ConsumerState<ProfileLocalDataSection> createState()=>_ProfileLocalDataSectionState();
}

class _ProfileLocalDataSectionState extends ConsumerState<ProfileLocalDataSection> {
  bool _busy=false;

  String _date(DateTime? date)=>date==null?'Sin registrar':
    '${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}';

  String _gender(GenderIdentity? value)=>switch(value){
    GenderIdentity.woman=>'Mujer', GenderIdentity.man=>'Hombre',
    GenderIdentity.nonBinary=>'No binario / otra identidad',
    GenderIdentity.preferNotToSay=>'Prefiero no decirlo',null=>'Sin indicar',
  };

  String _energy(EnergyEquationSex? value)=>switch(value){
    EnergyEquationSex.female=>'Referencia femenina',
    EnergyEquationSex.male=>'Referencia masculina',null=>'Sin indicar',
  };

  Future<void> _showData(UserExperienceProfile profile) async {
    final rows=<(String,String)>[
      ('Fecha de nacimiento',_date(profile.dateOfBirth)),
      ('Género',_gender(profile.genderIdentity)),
      ('Parámetro energético',_energy(profile.equationSexForEnergy)),
      ('Consentimiento',profile.optionalDemographicsConsented?'Autorizado':'No autorizado'),
      ('Fecha de autorización',_date(profile.optionalDemographicsConsentedAt)),
      ('Última actualización',_date(profile.optionalDemographicsUpdatedAt)),
    ];
    await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Mis datos opcionales'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,
        crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          const Text('Datos demográficos locales. Mantén privada cualquier copia que decidas realizar.'),
          const SizedBox(height:12),
          for(final (index,row) in rows.indexed)...[
            if(index>0)const Divider(height:20),
            Text(row.$1,style:Theme.of(ctx).textTheme.bodySmall),
            SelectableText(row.$2,style:Theme.of(ctx).textTheme.bodyMedium),
          ],
        ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cerrar'))],
    ));
  }

  Future<void> _change(bool enabled) async {
    if(_busy)return;
    final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(enabled?'Autorizar datos demográficos opcionales':'Quitar datos demográficos'),
      content:Text(enabled
        ?'Se guardan en tu dispositivo. Si exportas o subes una copia de seguridad, pueden incluirse. No verifican tu edad ni se comparten automáticamente con entrenadores.'
        :'Se retirará la autorización y se quitarán la fecha de nacimiento, género y parámetro energético locales. Tus rutinas, medidas, historial y elegibilidad no cambian. Las copias anteriores no se modifican.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancelar')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(enabled?'Autorizar':'Quitar datos'))]));
    if(confirmed!=true||!mounted||_busy)return;
    setState(()=>_busy=true);
    try{
      await ref.read(userExperienceProfileProvider.notifier).setOptionalDemographicConsent(enabled);
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(
        enabled?'Permiso autorizado. Puedes editar tus datos en Perfil.':'Datos opcionales retirados.')));
    }catch(_){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('No se pudo guardar el cambio. Inténtalo de nuevo.')));
    }finally{
      if(mounted)setState(()=>_busy=false);
    }
  }

  @override
  Widget build(BuildContext context){
    final profile=ref.watch(userExperienceProfileProvider);
    final colors=AppColors.of(context);
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Text('Mis datos',style:AppTypography.headlineMedium),
      const SizedBox(height:AppSpacing.sm),
      profile.when(
        loading:()=>const Center(child:CircularProgressIndicator()),
        error:(_,__)=>const Text('No se pudieron cargar los datos personales.'),
        data:(p)=>PremiumCard(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          ListTile(key:const ValueKey('profile_view_optional_data'),contentPadding:EdgeInsets.zero,
            leading:const Icon(Icons.person_outline),title:const Text('Consultar mis datos opcionales'),
            trailing:const Icon(Icons.chevron_right_rounded),onTap:()=>_showData(p)),
          const Divider(),
          SwitchListTile.adaptive(key:const ValueKey('profile_optional_demographics_consent'),contentPadding:EdgeInsets.zero,
            title:const Text('Autorizar datos demográficos opcionales'),
            subtitle:const Text('Fecha de nacimiento, género y cálculo energético.'),
            value:p.optionalDemographicsConsented,onChanged:_busy?null:_change),
          const Divider(),
          ListTile(key:const ValueKey('profile_clear_optional_data'),contentPadding:EdgeInsets.zero,
            leading:Icon(Icons.delete_outline,color:colors.error),
            title:Text('Quitar datos demográficos',style:TextStyle(color:colors.error)),
            onTap:_busy?null:()=>_change(false)),
          Text('Los permisos de entrenador se administran en Mi Coach. Las copias anteriores pueden contener estos datos.',
            style:AppTypography.bodySmall.copyWith(color:colors.textSecondary)),
        ])),
      ),
    ]);
  }
}
