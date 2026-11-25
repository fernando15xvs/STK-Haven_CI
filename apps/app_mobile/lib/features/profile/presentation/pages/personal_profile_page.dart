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
        maxWidth: 360,
        maxHeight: 360,
        imageQuality: 70,
        requestFullMetadata: false,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      // Keep backups and local profile writes small, even for unusual images.
      if (bytes.length < 8 || bytes.length > 220 * 1024) {
        throw const FormatException('La foto debe pesar menos de 220 KB.');
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

  /// Explicit local data access. Nothing is sent to a remote service or
  /// copied to the clipboard automatically; the user can select the text.
  Future<void> _showOptionalProfileData(UserExperienceProfile draft) async {
    final data=const JsonEncoder.withIndent('  ').convert({
      'dateOfBirth':draft.dateOfBirth?.toIso8601String(),
      'genderIdentity':draft.genderIdentity?.name,
      'equationSexForEnergy':draft.equationSexForEnergy?.name,
      'optionalDemographicsConsented':draft.optionalDemographicsConsented,
      'optionalDemographicsConsentedAt':
        draft.optionalDemographicsConsentedAt?.toIso8601String(),
      'optionalDemographicsUpdatedAt':
        draft.optionalDemographicsUpdatedAt?.toIso8601String(),
    });
    await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Mis datos opcionales'),
      content:SingleChildScrollView(child:Column(
        mainAxisSize:MainAxisSize.min,
        crossAxisAlignment:CrossAxisAlignment.start,
        children:[
          const Text('Esta vista solo muestra los datos demográficos locales. '
            'Mantén privada cualquier copia que decidas realizar.'),
          const SizedBox(height:12),
          SelectableText(data),
        ],
      )),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),
        child:const Text('Cerrar'))],
    ));
  }

  Future<void> _clearOptionalProfileData(UserExperienceProfile draft) async {
    final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>
      AlertDialog(
        title:const Text('Quitar datos demográficos'),
        content:const Text('Se quitarán la fecha de nacimiento, el género '
          'y el parámetro de ecuación del borrador. Tus rutinas, medidas '
          'e historial no cambian. Se aplicará al pulsar Guardar perfil.'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),
            child:const Text('Cancelar')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),
            child:const Text('Quitar datos')),
        ],
      ));
    if(confirmed!=true || !mounted)return;
    setState(()=>_draft=draft.copyWith(
      clearDateOfBirth:true,
      clearGenderIdentity:true,
      clearEquationSexForEnergy:true,
      optionalDemographicsConsented:false,
      clearOptionalDemographicsConsentAt:true,
    ));
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

  List<Widget> _buildDemographicFields(UserExperienceProfile draft) {
    return [
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  key:const ValueKey('profile_birth_date'),
                  icon:const Icon(Icons.calendar_month_outlined),
                  label:Text(draft.dateOfBirth==null
                    ? 'Indicar fecha de nacimiento'
                    : '${draft.dateOfBirth!.day.toString().padLeft(2,'0')}/'
                      '${draft.dateOfBirth!.month.toString().padLeft(2,'0')}/'
                      '${draft.dateOfBirth!.year}'),
                  onPressed:!draft.optionalDemographicsConsented?null:()async{
                    final now=DateTime.now();
                    final picked=await showDatePicker(
                      context:context,
                      initialDate:draft.dateOfBirth??DateTime(now.year-18),
                      firstDate:DateTime(1900),lastDate:now);
                    if(picked!=null && mounted){
                      setState(()=>_draft=draft.copyWith(dateOfBirth:picked));
                    }
                  },
                ),
                if(draft.dateOfBirth!=null)
                  TextButton(onPressed:()=>setState(()=>
                    _draft=draft.copyWith(clearDateOfBirth:true)),
                    child:const Text('Quitar fecha')),
                const SizedBox(height: 12),
                DropdownButtonFormField<GenderIdentity>(
                  key:ValueKey(draft.genderIdentity?.name??'gender_none'),
                  initialValue:draft.genderIdentity,
                  isExpanded:true,
                  decoration:const InputDecoration(labelText:'Género (opcional)'),
                  items:const [
                    DropdownMenuItem(value:GenderIdentity.woman,
                      child:Text('Mujer')),
                    DropdownMenuItem(value:GenderIdentity.man,
                      child:Text('Hombre')),
                    DropdownMenuItem(value:GenderIdentity.nonBinary,
                      child:Text('No binario / otra identidad')),
                    DropdownMenuItem(value:GenderIdentity.preferNotToSay,
                      child:Text('Prefiero no decirlo')),
                  ],
                  onChanged:!draft.optionalDemographicsConsented?null:
                    (value)=>setState(()=>_draft=value==null
                      ?draft.copyWith(clearGenderIdentity:true)
                      :draft.copyWith(genderIdentity:value)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<EnergyEquationSex>(
                  key:ValueKey(draft.equationSexForEnergy?.name??'equation_none'),
                  initialValue:draft.equationSexForEnergy,
                  isExpanded:true,
                  decoration:const InputDecoration(
                    labelText:'Parámetro de cálculo energético (opcional)',
                    helperText:'Es independiente de tu identidad de género.',
                  ),
                  items:const [
                    DropdownMenuItem(value:EnergyEquationSex.female,
                      child:Text('Referencia femenina')),
                    DropdownMenuItem(value:EnergyEquationSex.male,
                      child:Text('Referencia masculina')),
                  ],
                  onChanged:!draft.optionalDemographicsConsented?null:
                    (value)=>setState(()=>_draft=value==null
                      ?draft.copyWith(clearEquationSexForEnergy:true)
                      :draft.copyWith(equationSexForEnergy:value)),
                ),
    ];
  }

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
          return Form(
            key: _formKey,
            child: ListView(
              key: const ValueKey('profile_editor_scroll'),
              padding: EdgeInsets.fromLTRB(AppUiTokens.of(context).pageHorizontalPadding, 8,
                AppUiTokens.of(context).pageHorizontalPadding, 24),
              children: [
                Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  ProfileAvatar(profile: draft, radius: 44),
                  const SizedBox(height: 6),
                  TextButton(key: const ValueKey('profile_change_avatar'),
                    onPressed: _saving || _pickingPhoto ? null : _chooseAvatar,
                    child: const Text('Cambiar foto o avatar')),
                ])),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  onChanged: (_) => setState(() {}),
                  maxLength: 40,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre o apodo',
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
                _section(context, key: 'profile_personal_section', icon: Icons.person_outline,
                  title: 'Datos personales', subtitle: 'Nacimiento, género y cálculo energético',
                  children: [
                    const Text('Tu fecha y preferencias son opcionales. No verifican la edad.'),
                SwitchListTile.adaptive(
                  key:const ValueKey('profile_optional_demographics_consent'),
                  contentPadding:EdgeInsets.zero,
                  title:const Text('Autorizar datos demográficos opcionales'),
                  subtitle: const Text('Solo con tu permiso. Puedes retirarlo.'),
                  value:draft.optionalDemographicsConsented,
                  onChanged:(enabled)async{
                    if(!enabled &&
                       (draft.dateOfBirth!=null ||
                        draft.genderIdentity!=null ||
                        draft.equationSexForEnergy!=null)){
                      final confirmed=await showDialog<bool>(
                        context:context,builder:(ctx)=>AlertDialog(
                          title:const Text('Desactivar datos opcionales'),
                          content:const Text('Se quitarán fecha de nacimiento, '
                            'género y parámetro energético de tu borrador. '
                            'Se aplicará al guardar. Tus rutinas, '
                            'historial y preferencias no cambiarán.'),
                          actions:[
                            TextButton(onPressed:()=>Navigator.pop(ctx,false),
                              child:const Text('Cancelar')),
                            FilledButton(onPressed:()=>Navigator.pop(ctx,true),
                              child:const Text('Quitar del borrador')),
                          ],
                        ),
                      );
                      if(confirmed!=true || !mounted)return;
                    }
                    if(!mounted)return;
                    setState((){
                      _draft=enabled
                        ?draft.copyWith(
                          optionalDemographicsConsented:true,
                          optionalDemographicsConsentedAt:DateTime.now())
                        :draft.copyWith(
                          optionalDemographicsConsented:false,
                          clearOptionalDemographicsConsentAt:true,
                          clearDateOfBirth:true,
                          clearGenderIdentity:true,
                          clearEquationSexForEnergy:true);
                    });
                  },
                ),
                const ExpansionTile(
                    key:ValueKey('profile_optional_consent_information'),
                    title:Text('Más información sobre tus datos'),
                    tilePadding:EdgeInsets.zero,
                    childrenPadding:EdgeInsets.only(bottom:12),
                    children:[Text('Se guardan en tu dispositivo. Si exportas o subes una copia de seguridad, '
                      'estos datos pueden incluirse en ella. No verifican tu edad '
                      'ni se comparten automáticamente con entrenadores.')],
                  ),
                if(!draft.optionalDemographicsConsented &&
                   (draft.dateOfBirth!=null ||
                    draft.genderIdentity!=null ||
                    draft.equationSexForEnergy!=null))
                  Text('Los datos anteriores se conservaron sin '
                    'suponer tu autorización. Puedes revisarlos o '
                    'quitarlos, o autorizarlos expresamente.',
                    style:Theme.of(context).textTheme.bodySmall),
                ExpansionTile(
                    key:const ValueKey('profile_mobile_demographic_editor'),
                    tilePadding:EdgeInsets.zero,
                    title:const Text('Editar fecha, género y cálculo'),
                    subtitle:Text(draft.dateOfBirth == null
                      ? 'Fecha de nacimiento no indicada'
                      : 'Fecha: ${draft.dateOfBirth!.day.toString().padLeft(2,'0')}/'
                        '${draft.dateOfBirth!.month.toString().padLeft(2,'0')}/'
                        '${draft.dateOfBirth!.year}'),
                    children:_buildDemographicFields(draft),
                  ),

                  ]),
                _section(context, key: 'profile_training_section', icon: Icons.fitness_center_outlined,
                  title: 'Preferencias de entrenamiento', subtitle: 'Objetivo, experiencia y frecuencia',
                  initiallyExpanded: widget.openTraining, children: _trainingFields(draft)),
                _section(context, key: 'profile_mode_section', icon: Icons.group_outlined,
                  title: 'Modo de uso', subtitle: 'Atleta y entrenador',
                  children: _modeFields(draft)),
                _section(context, key: 'profile_faith_section', icon: Icons.menu_book_outlined,
                  title: 'Contenido de Fe', subtitle: 'Contenido y reflexiones',
                  children: _faithFields(draft)),
                _section(context, key: 'profile_home_section', icon: Icons.home_outlined,
                  title: 'Bienestar en Inicio', subtitle: 'Sueño y hábitos diarios', children: [
                    SwitchListTile.adaptive(contentPadding: EdgeInsets.zero,
                      title: const Text('Mostrar sueño'), value: draft.showSleepOnHome,
                      onChanged: (value) => setState(() => _draft = draft.copyWith(showSleepOnHome: value))),
                    SwitchListTile.adaptive(contentPadding: EdgeInsets.zero,
                      title: const Text('Mostrar Mis hábitos'), value: draft.habitsEnabled,
                      subtitle: const Text('Tus tareas diarias, sin borrar registros al ocultarlas.'),
                      onChanged: (value) => setState(() => _draft = draft.copyWith(habitsEnabled: value))),
                  ]),
                _section(context, key: 'profile_privacy_section', icon: Icons.shield_outlined,
                  title: 'Privacidad de tus datos', subtitle: 'Consultar o quitar datos personales',
                  children: [
                    const Text('Tu nombre y avatar permanecen personales. Los permisos para entrenadores se administran en Mi Coach.'),
                const SizedBox(height:12),
                Wrap(spacing:8,runSpacing:8,children:[
                  OutlinedButton.icon(
                    key:const ValueKey('profile_view_optional_data'),
                    onPressed:()=>_showOptionalProfileData(draft),
                    icon:const Icon(Icons.visibility_outlined),
                    label:const Text('Ver mis datos opcionales'),
                  ),
                  TextButton.icon(
                    key:const ValueKey('profile_clear_optional_data'),
                    onPressed:()=>_clearOptionalProfileData(draft),
                    icon:const Icon(Icons.delete_outline),
                    label:const Text('Quitar datos demográficos'),
                  ),
                ]),

                  ]),
                const SizedBox(height: 24),
                FilledButton.icon(
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
                ),
              ],
            ),
          );
        },
      ),
      ),
    );
  }

  Widget _section(BuildContext context, {required String key, required IconData icon,
      required String title, required String subtitle, required List<Widget> children,
      bool initiallyExpanded = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: PremiumCard(padding: EdgeInsets.zero, child: ExpansionTile(
      key: ValueKey(key), initiallyExpanded: initiallyExpanded, maintainState: true,
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title), subtitle: Text(subtitle),
      childrenPadding: EdgeInsets.fromLTRB(14, 0, 14, 14), children: children,
    )),
  );

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
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
              _daysSelector(draft),
              if(YouthTrainingGuidance.forProfile(draft,DateTime.now())
                  case final guidance?) ...[
                const SizedBox(height:8),
                Text(guidance,
                  key:const ValueKey('experience_youth_rest_guidance'),
                  style:Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
              _dropdown<PlanningPreference>(
                label: 'Planificación',
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
              _faithChoice(
                draft,
                FaithContentPreference.enabled,
                'Sí, incluirlo',
                'Biblia, versículo diario, Haven Faith y estudio.',
              ),
              _faithChoice(
                draft,
                FaithContentPreference.disabled,
                'No, mantenerlo oculto',
                'No se cargarán módulos de Fe.',
              ),
              _faithChoice(
                draft,
                FaithContentPreference.undecided,
                'Decidir después',
                'Se mantiene oculto hasta que elijas activarlo.',
              ),

    if (draft.faithEnabled)
      Consumer(builder: (context, ref, _) {
        final saved = ref.watch(settingsProvider.select((s) => s.showDailyVerse));
        return SwitchListTile.adaptive(
          key: const ValueKey('profile_show_verse'), contentPadding: EdgeInsets.zero,
          title: const Text('Versículo en Inicio'),
          subtitle: const Text('Mostrar el mensaje diario sin desactivar la Biblia.'),
          value: _verseDraft ?? saved,
          onChanged: (value) => setState(() => _verseDraft = value == saved ? null : value),
        );
      }),
    if (draft.faithEnabled)
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Reflexiones al terminar de entrenar'),
        subtitle: const Text('Mostrar en el resumen final.'),
        value: draft.showWorkoutReflections,
        onChanged: (value) => setState(() => _draft = draft.copyWith(showWorkoutReflections: value)),
      ),
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


  Widget _daysSelector(UserExperienceProfile draft) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Frecuencia preferida',
        helperText: 'El plan activo se edita en Entrenar.',
        helperMaxLines: 3,
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final day in [2, 3, 4, 5, 6])
            ChoiceChip(
              label: Text('$day'),
              selected: draft.trainingDaysPerWeek == day,
              onSelected: (_) => setState(
                () => _draft = draft.copyWith(trainingDaysPerWeek: day),
              ),
            ),
          ChoiceChip(
            label: const Text('No lo sé'),
            selected: draft.trainingDaysPerWeek == null,
            onSelected: (_) =>
                setState(() => _draft = draft.copyWith(clearTrainingDays: true)),
          ),
        ],
      ),
    );
  }

  Widget _faithChoice(
    UserExperienceProfile draft,
    FaithContentPreference value,
    String title,
    String subtitle,
  ) {
    return RadioListTile<FaithContentPreference>(
      contentPadding: EdgeInsets.zero,
      value: value,
      groupValue: draft.faithPreference,
      onChanged: (next) {
        if (next == null) return;
        setState(() => _draft = draft.copyWith(faithPreference: next));
      },
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<T> values,
    required String Function(T) labelFor,
    required ValueChanged<T?> onChanged,
    bool allowNull = true,
  }) {
    return DropdownButtonFormField<T?>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        if (allowNull)
          DropdownMenuItem<T?>(
            value: null,
            child: const Text('Por decidir'),
          ),
        ...values.map(
          (item) => DropdownMenuItem<T?>(
            value: item,
            child: Text(labelFor(item)),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }

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
