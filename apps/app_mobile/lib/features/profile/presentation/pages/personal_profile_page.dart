import 'dart:convert';

import 'package:core/domain/models/user_experience_profile.dart';
import 'package:core/domain/models/nutrition_intelligence.dart';
import 'package:gym_tracker/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:core/features/profile/application/providers/user_experience_profile_provider.dart';
import 'package:core/features/profile/application/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:core/features/programs/application/youth_training_guidance.dart';
import 'package:gym_tracker/core/theme/app_ui_styles.dart';
import 'package:gym_tracker/core/theme/components/premium_card.dart';
import 'package:core/features/profile/application/profile_edit_policy.dart';
import 'package:gym_tracker/features/profile/presentation/pages/stk_mobile_privacy_page.dart';

/// Personal identity stays local. Coach access is managed separately through
/// explicit relationship permissions; editing this page does not share data.
class PersonalProfilePage extends ConsumerStatefulWidget {
  const PersonalProfilePage({super.key, this.openTraining = false});

  /// Legacy follow-up opens the same editor with training expanded.
  final bool openTraining;

  @override
  ConsumerState<PersonalProfilePage> createState() => _PersonalProfilePageState();
}

class _PersonalProfilePageState extends ConsumerState<PersonalProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _trainingAnchor = GlobalKey();
  bool _trainingFocused = false;
  UserExperienceProfile? _draft;
  UserExperienceProfile? _original;
  bool _saving = false;
  bool _pickingPhoto = false;
  bool _allowPop = false;
  bool? _verseDraft;

  static const _avatars = <String>['💪', '🌱', '🏋️', '🏃', '⭐', '🧘', '🔥', '🦁'];

  Future<void> _selectPhoto() async {
    if (_pickingPhoto || _saving) return;
    setState(() => _pickingPhoto = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1440,
        maxHeight: 1440,
        imageQuality: 82,
        requestFullMetadata: false,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      // Keep backups and local profile writes small, even for unusual images.
      if (bytes.length < 8 || bytes.length > 1024 * 1024) {
        throw const FormatException('La foto debe pesar menos de 1 MB.');
      }
      final jpeg = bytes[0] == 0xFF && bytes[1] == 0xD8;
      final png = bytes[0] == 0x89 && bytes[1] == 0x50 &&
          bytes[2] == 0x4E && bytes[3] == 0x47;
      final webp = bytes.length >= 12 && bytes[0] == 0x52 && bytes[1] == 0x49 &&
          bytes[2] == 0x46 && bytes[3] == 0x46 &&
          bytes[8] == 0x57 && bytes[9] == 0x45 &&
          bytes[10] == 0x42 && bytes[11] == 0x50;
      if (!jpeg && !png && !webp) {
        throw const FormatException('Selecciona una foto JPG, PNG o WebP.');
      }
      if (!mounted || _draft == null) return;
      setState(() => _draft = _draft!.copyWith(
        avatarPhotoBase64: base64Encode(bytes),
        clearAvatar: true,
      ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(
            'No se pudo usar esa foto. Prueba con otra imagen más pequeña.',
          )),
        );
      }
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  bool get _hasUnsavedChanges {
    final draft = _draft, original = _original;
    if (draft == null || original == null) return false;
    return _verseDraft != null || _name.text.trim() != original.displayName ||
        jsonEncode(draft.toJson()) != jsonEncode(original.toJson());
  }

  Future<bool> _authorizeDemographics() async {
    if (_draft!.optionalDemographicsConsented) return true;
    final confirmed = await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Autorizar datos demográficos opcionales'),
      content:const Text('Se guardan en tu dispositivo. Si exportas o subes una copia de seguridad, pueden incluirse. No verifican tu edad ni se comparten automáticamente con entrenadores. Puedes retirar el permiso en Legal y privacidad.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancelar')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Autorizar'))]));
    if(confirmed!=true || !mounted)return false;
    setState(()=>_draft=ProfileEditPolicy.withDemographicConsent(_draft!,true,DateTime.now()));
    return true;
  }

  Future<void> _openPrivacy() async {
    if (_hasUnsavedChanges) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Guarda o descarta los cambios antes de gestionar la privacidad.')));
      return;
    }
    await Navigator.of(context).push<void>(MaterialPageRoute(builder:(_)=>const StkMobilePrivacyPage()));
    if (!mounted) return;
    final latest=ref.read(userExperienceProfileProvider).value;
    if(latest!=null) setState((){_draft=latest;_original=latest;_name.text=latest.displayName;});
  }

  Future<void> _requestDiscard(bool didPop) async {
    if (didPop || _allowPop || !_hasUnsavedChanges || _saving || _pickingPhoto) return;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descartar cambios'),
        content: const Text('Hay cambios sin guardar. ¿Quieres salir sin guardarlos?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Seguir editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) return;
    setState(() {
      _draft = _original;
      _verseDraft = null;
      _name.text = _original?.displayName ?? '';
      _allowPop = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  String _dateLabel(DateTime? date) => date==null?'Sin indicar':
      '${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}';

  String _genderLabel(GenderIdentity value) => switch(value){
    GenderIdentity.woman=>'Mujer',GenderIdentity.man=>'Hombre',
    GenderIdentity.nonBinary=>'No binario / otra identidad',
    GenderIdentity.preferNotToSay=>'Prefiero no decirlo',
  };
  String _energyLabel(EnergyEquationSex value) => switch(value){
    EnergyEquationSex.female=>'Referencia femenina',EnergyEquationSex.male=>'Referencia masculina',
  };

  Future<void> _editBirthDate() async {
    if (!await _authorizeDemographics() || !mounted)return;
    final current=_draft!;
    final now=DateTime.now();
    final birth=current.dateOfBirth;
    final initial=birth!=null&&!birth.isBefore(DateTime(1900))&&!birth.isAfter(now)?birth:DateTime(now.year-18);
    final picked=await showDatePicker(context:context,initialDate:initial,firstDate:DateTime(1900),lastDate:now);
    if(picked!=null&&mounted)setState(()=>_draft=_draft!.copyWith(dateOfBirth:picked));
  }

  List<Widget> _buildDemographicFields(UserExperienceProfile draft) => [
    _editRow(key:const ValueKey('profile_birth_date'),icon:Icons.calendar_month_outlined,
      label:'Fecha de nacimiento',value:draft.optionalDemographicsConsented?_dateLabel(draft.dateOfBirth):'Sin autorizar',
      onTap:_editBirthDate),
    if(draft.optionalDemographicsConsented&&draft.dateOfBirth!=null)
      Align(alignment:Alignment.centerLeft,child:TextButton(onPressed:()=>setState(()=>_draft=_draft!.copyWith(clearDateOfBirth:true)),
        child:const Text('Quitar fecha'))),
    _editRow(icon:Icons.person_outline,label:'Género',
      value:!draft.optionalDemographicsConsented?'Sin autorizar':draft.genderIdentity==null?'Sin indicar':_genderLabel(draft.genderIdentity!),
      onTap:()async{
        if(!await _authorizeDemographics()||!mounted)return;
        await _selectOption<GenderIdentity>(label:'Género',value:_draft!.genderIdentity,
          values:GenderIdentity.values,labelFor:_genderLabel,onChanged:(value)=>setState(()=>_draft=_draft!.copyWith(genderIdentity:value,clearGenderIdentity:value==null)));
      }),
    _editRow(icon:Icons.local_fire_department_outlined,label:'Cálculo energético',
      value:!draft.optionalDemographicsConsented?'Sin autorizar':draft.equationSexForEnergy==null?'Sin indicar':_energyLabel(draft.equationSexForEnergy!),
      onTap:()async{
        if(!await _authorizeDemographics()||!mounted)return;
        await _selectOption<EnergyEquationSex>(label:'Cálculo energético',value:_draft!.equationSexForEnergy,
          values:EnergyEquationSex.values,labelFor:_energyLabel,description:'La referencia de la ecuación es independiente de tu género.',
          onChanged:(value)=>setState(()=>_draft=_draft!.copyWith(equationSexForEnergy:value,clearEquationSexForEnergy:value==null)));
      }),
  ];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userExperienceProfileProvider);
    return PopScope(
      canPop: _allowPop || (!_hasUnsavedChanges && !_saving && !_pickingPhoto),
      onPopInvokedWithResult: (didPop, _) => _requestDiscard(didPop),
      child: Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('No se pudo cargar el perfil: $error')),
        data: (saved) {
          if (_draft == null) {
            _draft = saved;
            _original = saved;
            _name.text = saved.displayName;
          }
          final draft = _draft!;
          if(widget.openTraining&&!_trainingFocused){
            _trainingFocused=true;
            WidgetsBinding.instance.addPostFrameCallback((_){
              final anchor=_trainingAnchor.currentContext;
              if(mounted&&anchor!=null)Scrollable.ensureVisible(anchor);
            });
          }
          return Form(
            key: _formKey,
            child: Column(children:[Expanded(child: AbsorbPointer(absorbing:_saving,child: SingleChildScrollView(
              key: const ValueKey('profile_editor_scroll'),
              padding: EdgeInsets.fromLTRB(AppUiTokens.of(context).pageHorizontalPadding, 8,
                AppUiTokens.of(context).pageHorizontalPadding, 24),
              child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children: [
                Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  ProfileAvatar(profile: draft, radius: 44, previewEnabled: true),
                  const SizedBox(height: 6),
                  TextButton(key: const ValueKey('profile_change_avatar'),
                    onPressed: _saving || _pickingPhoto ? null : _chooseAvatar,
                    child: const Text('Cambiar foto o avatar')),
                ])),
                const SizedBox(height: 12),
                Text('Nombre o apodo',style:Theme.of(context).textTheme.titleMedium),
                const SizedBox(height:8),
                TextFormField(
                  controller: _name,
                  onChanged: (_) => setState(() {}),
                  maxLength: 40,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: '¿Cómo quieres que te llamemos?',
                  ),
                  validator: (text) {
                    if ((text ?? '').trim().length > 40) return 'Máximo 40 caracteres.';
                    if ((text ?? '').contains(RegExp(r'[\x00-\x1F]'))) {
                      return 'El nombre contiene caracteres no permitidos.';
                    }
                    return null; // El nombre es opcional.
                  },
                ),
                const SizedBox(height: 12),
                _section(context,key:'profile_personal_section',title:'Datos personales',
                  children:_buildDemographicFields(draft)),
                Align(alignment:Alignment.centerLeft,child:TextButton(
                  key:const ValueKey('profile_manage_privacy'),onPressed:_saving?null:_openPrivacy,
                  child:const Text('Gestionar privacidad'))),
                KeyedSubtree(key:_trainingAnchor,child:_section(context,key:'profile_training_section',title:'Preferencias de entrenamiento',
                  children:_trainingFields(draft))),
                _section(context,key:'profile_mode_section',title:'Modo de uso',
                  children:_modeFields(draft)),
                _section(context,key:'profile_faith_section',title:'Contenido de Fe',
                  children:_faithFields(draft)),
                _section(context,key:'profile_home_section',title:'Bienestar en Inicio',children:[
                  SwitchListTile.adaptive(contentPadding:EdgeInsets.zero,
                    title:const Text('Mostrar sueño'),value:draft.showSleepOnHome,
                    onChanged:(v)=>setState(()=>_draft=_draft!.copyWith(showSleepOnHome:v))),
                  SwitchListTile.adaptive(contentPadding:EdgeInsets.zero,
                    title:const Text('Mostrar Mis hábitos'),value:draft.habitsEnabled,
                    subtitle:const Text('Ocultar no elimina tus registros.'),
                    onChanged:(v)=>setState(()=>_draft=_draft!.copyWith(habitsEnabled:v))),
                ]),
              ]),
            ))),
            SafeArea(top:false,child:Padding(padding:EdgeInsets.fromLTRB(AppUiTokens.of(context).pageHorizontalPadding,8,AppUiTokens.of(context).pageHorizontalPadding,8),child:SizedBox(width:double.infinity,child:FilledButton.icon(
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Guardando…' : 'Guardar perfil'),
                  onPressed: _saving || _pickingPhoto ? null : () async {
                    if (!_formKey.currentState!.validate()) return;
                    setState(() => _saving = true);
                    try {
                      final updated = await ref.read(userExperienceProfileProvider.notifier)
                          .saveProfileEdit(original: _original!, draft: _draft!.copyWith(displayName: _name.text.trim()),
                            showDailyVerse: _verseDraft);
                      if (!mounted) return;
                      setState(() {
                        _draft = updated;
                        _original = updated;
                        _verseDraft = null;
                        _saving = false;
                        _allowPop = true;
                      });
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) Navigator.of(context).pop();
                      });
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No se pudo guardar el perfil. Inténtalo de nuevo.')),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _saving = false);
                    }
                  },
                )))),
            ]),
          );
        },
      ),
      ),
    );
  }

  Widget _section(BuildContext context,{required String key,required String title,required List<Widget> children}) =>
    Padding(padding:EdgeInsets.only(bottom:AppUiTokens.of(context).sectionGap),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(title,key:ValueKey(key),style:Theme.of(context).textTheme.titleMedium),
        const SizedBox(height:8),
        PremiumCard(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,
          children:[for(var i=0;i<children.length;i++) ...[
            if(i>0)const Divider(height:16),
            children[i],
          ]])),
      ]));

  Widget _editRow({Key? key,IconData? icon,required String label,required String value,required VoidCallback onTap}) =>
    ListTile(key:key,contentPadding:EdgeInsets.zero,
      leading:icon==null?null:Icon(icon,color:Theme.of(context).colorScheme.primary),
      title:Text(label,style:Theme.of(context).textTheme.bodyMedium),
      subtitle:Text(value,style:Theme.of(context).textTheme.bodySmall),
      trailing:const Icon(Icons.chevron_right_rounded),onTap:_saving?null:onTap);

  Future<void> _selectOption<T>({required String label,required T? value,
    required List<T> values,required String Function(T) labelFor,
    required ValueChanged<T?> onChanged,bool allowNull=true,String? description,String emptyLabel='Sin indicar'}) async {
    final selected=await showModalBottomSheet<(T?,)> (context:context,useSafeArea:true,
      isScrollControlled:true,showDragHandle:true,builder:(ctx)=>ConstrainedBox(
        constraints:BoxConstraints(maxHeight:MediaQuery.sizeOf(ctx).height*.75),
        child:ListView(shrinkWrap:true,padding:EdgeInsets.all(AppUiTokens.of(ctx).cardPadding),children:[
          Text(label,style:Theme.of(ctx).textTheme.titleLarge),
          if(description!=null)Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Text(description)),
          for(final item in values)ListTile(title:Text(labelFor(item)),
            trailing:value==item?Icon(Icons.check,color:Theme.of(ctx).colorScheme.primary):null,
            onTap:()=>Navigator.pop(ctx,(item,))),
          if(allowNull)ListTile(title:Text(emptyLabel),
            trailing:value==null?Icon(Icons.check,color:Theme.of(ctx).colorScheme.primary):null,
            onTap:()=>Navigator.pop(ctx,(null,))),
        ])));
    if(selected!=null&&mounted)onChanged(selected.$1);
  }

  Future<void> _chooseAvatar() async {
    final draft = _draft!;
    final result = await showModalBottomSheet<String>(context: context, useSafeArea: true,
      isScrollControlled: true, showDragHandle: true, builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16), child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Foto o avatar', style: Theme.of(ctx).textTheme.titleLarge),
            ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Elegir foto'),
              onTap: () => Navigator.pop(ctx, 'photo')),
            if (draft.avatarPhotoBase64 != null || draft.avatarEmoji != null)
              ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Quitar foto o avatar'),
                onTap: () => Navigator.pop(ctx, 'clear')),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final avatar in _avatars)
                ChoiceChip(label: Text(avatar, style: const TextStyle(fontSize: 24)),
                  selected: draft.avatarEmoji == avatar,
                  onSelected: (_) => Navigator.pop(ctx, avatar)),
            ]),
          ],
        )),
      ));
    if (!mounted || result == null) return;
    if (result == 'photo') { await _selectPhoto(); return; }
    setState(() => _draft = result == 'clear'
      ? _draft!.copyWith(clearAvatar: true, clearAvatarPhoto: true)
      : _draft!.copyWith(avatarEmoji: result, clearAvatarPhoto: true));
  }

  List<Widget> _trainingFields(UserExperienceProfile draft) => [
              _dropdown<TrainingGoal>(
                label: 'Objetivo principal',
                value: draft.trainingGoal,
                values: TrainingGoal.values,
                labelFor: _goalLabel,
                onChanged: (value) =>
                    setState(() => _draft = draft.copyWith(
                          trainingGoal: value,
                          clearTrainingGoal: value == null,
                        )),
              ),
              _dropdown<TrainingExperience>(
                label: 'Experiencia',
                value: draft.trainingExperience,
                values: TrainingExperience.values,
                labelFor: _experienceLabel,
                onChanged: (value) =>
                    setState(() => _draft = draft.copyWith(
                          trainingExperience: value,
                          clearTrainingExperience: value == null,
                        )),
              ),
              _daysSelector(draft),
              if(YouthTrainingGuidance.forProfile(draft,DateTime.now())
                  case final guidance?) ...[
                const SizedBox(height:8),
                Text(guidance,
                  key:const ValueKey('experience_youth_rest_guidance'),
                  style:Theme.of(context).textTheme.bodySmall),
              ],
              _dropdown<SessionDurationPreference>(
                label: 'Duración habitual',
                value: draft.sessionDuration,
                values: SessionDurationPreference.values,
                labelFor: _durationLabel,
                allowNull: false,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _draft = draft.copyWith(
                        sessionDuration: value,
                      ));
                },
              ),
              _dropdown<TrainingEnvironment>(
                label: 'Lugar / equipamiento',
                value: draft.trainingEnvironment,
                values: TrainingEnvironment.values,
                labelFor: _environmentLabel,
                onChanged: (value) =>
                    setState(() => _draft = draft.copyWith(
                          trainingEnvironment: value,
                          clearTrainingEnvironment: value == null,
                        )),
              ),
              _dropdown<PlanningPreference>(
                label: 'Preferencia de rutinas',
                value: draft.planningPreference,
                values: PlanningPreference.values,
                labelFor: _planningLabel,
                allowNull: false,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _draft = draft.copyWith(
                        planningPreference: value,
                      ));
                },
              ),

  ];

  List<Widget> _modeFields(UserExperienceProfile draft) => [
              Text(
                'Puedes usar STK Haven para ti, como entrenador, o en ambos modos. '
                'El modo entrenador no da acceso a ningún cliente por sí solo.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Atleta'),
                    selected:
                        draft.capabilities.contains(UserCapability.athlete),
                    onSelected: (selected) => _toggleCapability(
                      draft,
                      UserCapability.athlete,
                      selected,
                    ),
                  ),
                  FilterChip(
                    label: const Text('Entrenador'),
                    selected:
                        draft.capabilities.contains(UserCapability.coach),
                    onSelected: (selected) => _toggleCapability(
                      draft,
                      UserCapability.coach,
                      selected,
                    ),
                  ),
                ],
              ),

  ];

  List<Widget> _faithFields(UserExperienceProfile draft) => [
    SwitchListTile.adaptive(key:const ValueKey('profile_faith_master'),contentPadding:EdgeInsets.zero,
      title:const Text('Activar contenido de Fe'),subtitle:const Text('Biblia, Haven Faith y estudio.'),
      value:draft.faithEnabled,onChanged:(enabled)=>setState(()=>_draft=_draft!.copyWith(
        faithPreference:enabled?FaithContentPreference.enabled:FaithContentPreference.disabled))),
    if (draft.faithEnabled)
      Consumer(builder: (context, ref, _) {
        final saved = ref.watch(settingsProvider.select((s) => s.showDailyVerse));
        return SwitchListTile.adaptive(
          key: const ValueKey('profile_show_verse'), contentPadding: EdgeInsets.zero,
          title: const Text('Versículo en Inicio'),
          value: _verseDraft ?? saved,
          onChanged: (value) => setState(() => _verseDraft = value == saved ? null : value),
        );
      }),
    if (draft.faithEnabled)
      SwitchListTile.adaptive(contentPadding: EdgeInsets.zero,
        title: const Text('Reflexiones al terminar de entrenar'),
        value: draft.showWorkoutReflections,
        onChanged: (value) => setState(() => _draft = _draft!.copyWith(showWorkoutReflections: value))),
  ];

  void _toggleCapability(
    UserExperienceProfile draft,
    UserCapability capability,
    bool selected,
  ) {
    final next = Set<UserCapability>.from(draft.capabilities);
    if (selected) {
      next.add(capability);
    } else {
      next.remove(capability);
    }
    if (next.isEmpty) {
      next.add(UserCapability.athlete);
    }
    setState(() => _draft = draft.copyWith(capabilities: next));
  }


  Widget _daysSelector(UserExperienceProfile draft) => _editRow(
    label:'Frecuencia preferida',value:draft.trainingDaysPerWeek==null?'Variable':'${draft.trainingDaysPerWeek} días',
    onTap:()=>_selectOption<int>(label:'Frecuencia preferida',value:draft.trainingDaysPerWeek,
      values:const [1,2,3,4,5,6,7],labelFor:(d)=>'$d ${d==1?'día':'días'}',
      description:'El plan activo se edita en Entrenar.',emptyLabel:'Variable',
      onChanged:(v)=>setState(()=>_draft=_draft!.copyWith(trainingDaysPerWeek:v,clearTrainingDays:v==null))));

  Widget _dropdown<T>({required String label,required T? value,required List<T> values,
    required String Function(T) labelFor,required ValueChanged<T?> onChanged,bool allowNull=true}) =>
    _editRow(label:label,value:value==null?'Sin indicar':labelFor(value),
      onTap:()=>_selectOption<T>(label:label,value:value,values:values,labelFor:labelFor,onChanged:onChanged,allowNull:allowNull));

  String _goalLabel(TrainingGoal value) => switch (value) {
        TrainingGoal.hypertrophy => 'Ganar masa muscular',
        TrainingGoal.strength => 'Ganar fuerza',
        TrainingGoal.activeLifestyle => 'Mantenerme activo',
        TrainingGoal.conditioning => 'Mejorar condición física',
        TrainingGoal.selfDirected => 'Crear mis propias rutinas',
      };

  String _experienceLabel(TrainingExperience value) => switch (value) {
        TrainingExperience.beginner => 'Principiante',
        TrainingExperience.intermediate => 'Intermedio',
        TrainingExperience.advanced => 'Avanzado',
      };

  String _durationLabel(SessionDurationPreference value) => switch (value) {
        SessionDurationPreference.minutes30 => '30 min',
        SessionDurationPreference.minutes45 => '45 min',
        SessionDurationPreference.minutes60 => '60 min',
        SessionDurationPreference.minutes75Plus => '75+ min',
        SessionDurationPreference.variable => 'Variable',
      };

  String _environmentLabel(TrainingEnvironment value) => switch (value) {
        TrainingEnvironment.fullGym => 'Gimnasio completo',
        TrainingEnvironment.homeWeights => 'Casa con pesas',
        TrainingEnvironment.minimalEquipment => 'Equipamiento mínimo',
        TrainingEnvironment.mixed => 'Mixto',
      };

  String _planningLabel(PlanningPreference value) => switch (value) {
        PlanningPreference.recommendation => 'Quiero una recomendación',
        PlanningPreference.selfDirected => 'Crear mis propias rutinas',
        PlanningPreference.decideLater => 'Decidir después',
      };

}
