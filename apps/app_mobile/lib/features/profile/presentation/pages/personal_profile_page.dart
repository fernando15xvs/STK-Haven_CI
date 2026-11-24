import 'dart:convert';

import 'package:core/domain/models/user_experience_profile.dart';
import 'package:core/domain/models/nutrition_intelligence.dart';
import 'package:gym_tracker/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:core/features/profile/application/providers/user_experience_profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Personal identity stays local. Coach access is managed separately through
/// explicit relationship permissions; editing this page does not share data.
class PersonalProfilePage extends ConsumerStatefulWidget {
  const PersonalProfilePage({super.key, this.mobileCompactLayout = false});

  /// Keeps the shared web page unchanged; only mobile enables disclosure UX.
  final bool mobileCompactLayout;

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
    return _name.text.trim() != original.displayName ||
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
    if (didPop || !_hasUnsavedChanges || _saving) return;
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
      _name.text = _original?.displayName ?? '';
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
      canPop: !_hasUnsavedChanges && !_saving && !_pickingPhoto,
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
              padding: const EdgeInsets.all(20),
              children: [
                Text(widget.mobileCompactLayout ? 'Datos personales' : 'Cómo quieres aparecer',
                  style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  onChanged: (_) => setState(() {}),
                  maxLength: 40,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre o apodo',
                    hintText: '¿Cómo quieres que te llamemos?',
                    border: OutlineInputBorder(),
                  ),
                  validator: (text) {
                    if ((text ?? '').trim().length > 40) return 'Máximo 40 caracteres.';
                    if ((text ?? '').contains(RegExp(r'[\x00-\x1F]'))) {
                      return 'El nombre contiene caracteres no permitidos.';
                    }
                    return null; // El nombre es opcional.
                  },
                ),
                const SizedBox(height: 14),
                Text('Foto de perfil (opcional)', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ProfileAvatar(profile: draft, radius: 27),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickingPhoto ? null : _selectPhoto,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(_pickingPhoto ? 'Abriendo fotos...' : 'Elegir foto'),
                      ),
                    ),
                    if (draft.avatarPhotoBase64 != null)
                      IconButton(
                        tooltip: 'Quitar foto',
                        onPressed: () => setState(
                          () => _draft = draft.copyWith(clearAvatarPhoto: true),
                        ),
                        icon: const Icon(Icons.delete_outline),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('O elige un avatar', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Sin avatar'),
                      selected: draft.avatarEmoji == null && draft.avatarPhotoBase64 == null,
                      onSelected: (_) => setState(() => _draft = draft.copyWith(clearAvatar: true, clearAvatarPhoto: true)),
                    ),
                    for (final avatar in _avatars)
                      ChoiceChip(
                        label: Text(avatar, style: const TextStyle(fontSize: 24)),
                        selected: draft.avatarEmoji == avatar,
                        onSelected: (_) => setState(() => _draft = draft.copyWith(avatarEmoji: avatar, clearAvatarPhoto: true)),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(widget.mobileCompactLayout
                    ? 'Información opcional para cálculos'
                    : 'Datos personales opcionales',
                  style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  widget.mobileCompactLayout
                      ? 'Tu fecha y preferencias son opcionales. No verifican la edad.'
                      : 'Sirven para adaptar la experiencia y la calculadora adulta. '
                        'Una fecha declarada no sustituye la verificación de edad.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  key:const ValueKey('profile_optional_demographics_consent'),
                  contentPadding:EdgeInsets.zero,
                  title:const Text('Autorizar datos demográficos opcionales'),
                  subtitle:widget.mobileCompactLayout
                    ? const Text('Solo con tu permiso. Puedes retirarlo.')
                    : const Text('Se guardan en tu dispositivo '
                        'para adaptar la experiencia y cálculos adultos '
                        'opcionales. Si exportas o subes una copia de seguridad, '
                        'estos datos pueden incluirse en ella. '
                        'No verifican tu edad ni se comparten automáticamente '
                        'con un entrenador. Puedes verlos o borrarlos aquí.'),
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
                if(widget.mobileCompactLayout)
                  const ExpansionTile(
                    key:ValueKey('profile_optional_consent_information'),
                    title:Text('Más información sobre tus datos'),
                    tilePadding:EdgeInsets.zero,
                    childrenPadding:EdgeInsets.only(bottom:12),
                    children:[Text('Se guardan en el dispositivo; una copia de '
                      'seguridad puede incluirlos. Nunca verifican tu edad '
                      'ni se comparten automáticamente con entrenadores. '
                      'Puedes consultar, retirar o borrar estos datos aquí.')],
                  ),
                if(!draft.optionalDemographicsConsented &&
                   (draft.dateOfBirth!=null ||
                    draft.genderIdentity!=null ||
                    draft.equationSexForEnergy!=null))
                  Text('Los datos anteriores se conservaron sin '
                    'suponer tu autorización. Puedes revisarlos o '
                    'quitarlos, o autorizarlos expresamente.',
                    style:Theme.of(context).textTheme.bodySmall),
                if(widget.mobileCompactLayout)
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
                  )
                else ..._buildDemographicFields(draft),
                if(widget.mobileCompactLayout) ...[
                  const SizedBox(height:18),
                  Text('Privacidad y mis datos',
                    style:Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height:4),
                  Text('Consulta o quita tus datos opcionales en cualquier momento.',
                    style:Theme.of(context).textTheme.bodySmall),
                ],
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
                const SizedBox(height: 24),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Reflexiones al terminar de entrenar'),
                  subtitle: const Text('Aparecen solo en el resumen final si activaste el contenido de Fe. Puedes desactivarlas aquí.'),
                  value: draft.showWorkoutReflections,
                  onChanged: (value) => setState(() => _draft = draft.copyWith(showWorkoutReflections: value)),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.mobileCompactLayout
                    ? 'Tu nombre y avatar permanecen personales. Los permisos '
                      'para entrenadores se administran en Mis entrenadores.'
                    : 'Privacidad: el nombre y avatar son personales y no se comparten automáticamente con el entrenador. '
                      'Los permisos de entrenamientos, progreso y medidas se eligen en Mis entrenadores.',
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_outlined),
                  label: const Text('Guardar perfil'),
                  onPressed: _saving ? null : () async {
                    if (!_formKey.currentState!.validate()) return;
                    setState(() => _saving = true);
                    try {
                      final draft=_draft!;
                      final prior=_original!;
                      final changedDemographics=
                        draft.dateOfBirth!=prior.dateOfBirth ||
                        draft.genderIdentity!=prior.genderIdentity ||
                        draft.equationSexForEnergy!=prior.equationSexForEnergy;
                      final hasOptionalData=draft.dateOfBirth!=null ||
                        draft.genderIdentity!=null ||
                        draft.equationSexForEnergy!=null;
                      if(changedDemographics && hasOptionalData &&
                         !draft.optionalDemographicsConsented){
                        throw const FormatException(
                          'Autoriza los datos opcionales antes de guardarlos.');
                      }
                      final updated = draft.copyWith(
                        displayName: _name.text.trim(),
                        optionalDemographicsUpdatedAt:changedDemographics
                          ?DateTime.now():null,
                      );
                      await ref.read(userExperienceProfileProvider.notifier)
                          .updateProfile(updated);
                      if (!mounted) return;
                      setState(() {
                        _draft = updated;
                        _original = updated;
                        _saving = false;
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
}
