import 'package:core/features/identity/domain/auth_form_validation.dart';
import 'package:core/features/sync/application/cloud_sync_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum CloudAuthMode { signIn, signUp }

/// Shared responsive entry for web, Android and iOS.
class CloudAuthPage extends ConsumerStatefulWidget {
  final CloudAuthMode initialMode;
  const CloudAuthPage({super.key, this.initialMode = CloudAuthMode.signIn});

  @override
  ConsumerState<CloudAuthPage> createState() => _CloudAuthPageState();
}

class _CloudAuthPageState extends ConsumerState<CloudAuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  late CloudAuthMode _mode = widget.initialMode;
  bool _showPassword = false;
  bool _busy = false;
  bool _feedbackError = false;
  String? _feedback;

  bool get _signUp => _mode == CloudAuthMode.signUp;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _switch(CloudAuthMode mode) {
    if (_busy || _mode == mode) return;
    setState(() {
      _mode = mode;
      _showPassword = false;
      _feedback = null;
      _password.clear();
      _confirm.clear();
      _formKey.currentState?.reset();
    });
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _feedback = null;
    });
    FocusScope.of(context).unfocus();
    try {
      final notifier = ref.read(cloudSyncProvider.notifier);
      final email = AuthFormValidation.normalizeEmail(_email.text);
      if (_signUp) {
        await notifier.signUp(email: email, password: _password.text);
      } else {
        await notifier.signIn(email: email, password: _password.text);
      }
      if (!mounted) return;
      final result = ref.read(cloudSyncProvider);
      if (result.signedIn) {
        Navigator.of(context).pop(true);
        return;
      }
      if (_signUp && !result.isError) {
        _switch(CloudAuthMode.signIn);
      }
      setState(() {
        _feedbackError = result.isError;
        _feedback = result.message ??
            (result.isError ? 'No se pudo completar la solicitud.'
                : 'Revisa tu correo antes de iniciar sesión.');
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _feedbackError = true;
          _feedback = 'No pudimos conectar. Comprueba internet e inténtalo otra vez.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recoverPassword() async {
    if (_busy) return;
    final emailError = AuthFormValidation.email(_email.text);
    if (emailError != null) {
      setState(() {
        _feedbackError = true;
        _feedback = emailError;
      });
      return;
    }
    setState(() {
      _busy = true;
      _feedback = null;
    });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        AuthFormValidation.normalizeEmail(_email.text),
      );
      if (!mounted) return;
      setState(() {
        _feedbackError = false;
        _feedback = 'Si ese correo tiene una cuenta, recibirás '
            'instrucciones para recuperar tu contraseña. Revisa también spam.';
      });
    } on AuthException {
      if (mounted) {
        setState(() {
          _feedbackError = true;
          _feedback = 'No se pudo enviar el correo de recuperación. '
              'Inténtalo más tarde.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _feedbackError = true;
          _feedback = 'Sin conexión. Comprueba internet e inténtalo otra vez.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clearFeedback(String _) {
    if (_feedback != null) setState(() => _feedback = null);
    if (_signUp) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cloud = ref.watch(cloudSyncProvider);
    final busy = _busy || cloud.busy;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tu cuenta STK Haven'),
        backgroundColor: colors.surface,
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 820;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.primaryContainer.withValues(alpha: 0.42),
                colors.surface, colors.secondaryContainer.withValues(alpha: 0.32)],
            ),
          ),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: wide ? 32 : 18,
                    vertical: wide ? 64 : 22,
                  ),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: _hero(context, compact: false)),
                            const SizedBox(width: 52),
                            Expanded(child: _form(context, busy)),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _hero(context, compact: true),
                            const SizedBox(height: 22),
                            _form(context, busy),
                          ],
                        ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _hero(BuildContext context, {required bool compact}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Icon(Icons.fitness_center_rounded,
              size: compact ? 28 : 38, color: colors.onPrimary),
        ),
        SizedBox(height: compact ? 16 : 30),
        Text('Tu progreso, a tu manera.',
          style: (compact ? theme.textTheme.headlineMedium
              : theme.textTheme.displaySmall)?.copyWith(
            fontWeight: FontWeight.w900, letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: 12),
        Text('Una cuenta para seguir tus objetivos y acceder a '
            'tus herramientas de entrenamiento.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colors.onSurfaceVariant, height: 1.5,
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 32),
          const _FeatureLine(icon: Icons.verified_user_outlined,
            title: 'Tu espacio personal',
            description: 'Inicio de sesión protegido con correo y contraseña.'),
          const SizedBox(height: 18),
          const _FeatureLine(icon: Icons.cloud_outlined,
            title: 'Tú decides qué sincronizar',
            description: 'Tus copias en la nube siguen siendo manuales.'),
          const SizedBox(height: 18),
          const _FeatureLine(icon: Icons.phone_android_outlined,
            title: 'Sin perder tu modo local',
            description: 'Puedes usar STK Haven sin crear una cuenta.'),
        ],
      ],
    );
  }

  Widget _form(BuildContext context, bool busy) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final criteria = AuthFormValidation.passwordCriteria(_password.text);
    final strength = criteria.where((passed) => passed).length;
    return Card(
      elevation: 3,
      shadowColor: colors.shadow.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(23, 26, 23, 24),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_signUp ? 'Crea tu cuenta' : 'Bienvenido de nuevo',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(_signUp
                ? 'Empieza con un correo y una contraseña segura.'
                : 'Ingresa tus datos para continuar.',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 22),
              Row(children: [
                Expanded(child: _modeButton(CloudAuthMode.signIn,
                    'Iniciar sesión', busy)),
                const SizedBox(width: 8),
                Expanded(child: _modeButton(CloudAuthMode.signUp,
                    'Registrarme', busy)),
              ]),
              const SizedBox(height: 22),
              TextFormField(
                controller: _email,
                enabled: !busy,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textCapitalization: TextCapitalization.none,
                textInputAction: TextInputAction.next,
                maxLength: 254,
                onChanged: _clearFeedback,
                validator: AuthFormValidation.email,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  hintText: 'nombre@correo.com',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                enabled: !busy,
                obscureText: !_showPassword,
                autofillHints: [_signUp
                  ? AutofillHints.newPassword : AutofillHints.password],
                textInputAction: _signUp
                  ? TextInputAction.next : TextInputAction.done,
                onFieldSubmitted: (_) { if (!_signUp) _submit(); },
                onChanged: _clearFeedback,
                validator: _signUp
                  ? AuthFormValidation.signUpPassword
                  : AuthFormValidation.signInPassword,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: _showPassword
                        ? 'Ocultar contraseña' : 'Mostrar contraseña',
                    onPressed: () => setState(
                        () => _showPassword = !_showPassword),
                    icon: Icon(_showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                  ),
                ),
              ),
              if (_signUp) ...[
                const SizedBox(height: 12),
                Row(children: [
                  for (var i = 0; i < 4; i++) ...[
                    Expanded(child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: i < strength ? colors.primary
                            : colors.outlineVariant,
                      ),
                    )),
                    if (i < 3) const SizedBox(width: 5),
                  ],
                ]),
                const SizedBox(height: 8),
                Text('Seguridad: ' + (strength <= 1 ? 'Inicial'
                    : strength == 2 ? 'Media' : strength == 3
                    ? 'Buena' : 'Fuerte'),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Text('Usa 10–72 caracteres, mayúsculas, minúsculas '
                    'y números. Un símbolo añade más seguridad.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirm,
                  enabled: !busy,
                  obscureText: !_showPassword,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  onChanged: _clearFeedback,
                  validator: (value) => AuthFormValidation.confirmPassword(
                    value, _password.text),
                  decoration: const InputDecoration(
                    labelText: 'Confirmar contraseña',
                    prefixIcon: Icon(Icons.verified_user_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              if (!_signUp) ...[
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: TextButton(
                  onPressed: busy ? null : _recoverPassword,
                  child: const Text('¿Olvidaste tu contraseña?'),
                )),
              ],
              if (_feedback != null) ...[
                const SizedBox(height: 14),
                Semantics(
                  liveRegion: true,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: _feedbackError
                        ? colors.errorContainer : colors.primaryContainer,
                    ),
                    child: Row(children: [
                      Icon(_feedbackError ? Icons.error_outline
                          : Icons.mark_email_read_outlined,
                        color: _feedbackError
                            ? colors.onErrorContainer : colors.onPrimaryContainer),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_feedback!,
                        style: TextStyle(color: _feedbackError
                            ? colors.onErrorContainer
                            : colors.onPrimaryContainer))),
                    ]),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              FilledButton(
                onPressed: busy ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: busy
                  ? const SizedBox(height: 22, width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_signUp ? 'Crear mi cuenta' : 'Entrar a STK Haven'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(context, false),
                child: const Text('Continuar sin cuenta'),
              ),
              const SizedBox(height: 8),
              Text('Tu historial local no se sube automáticamente. '
                  'Puedes gestionar las copias desde Datos y sincronización.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeButton(CloudAuthMode mode, String label, bool busy) {
    final selected = _mode == mode;
    return selected
      ? FilledButton.tonal(
          onPressed: busy ? null : () => _switch(mode),
          child: Text(label),)
      : OutlinedButton(
          onPressed: busy ? null : () => _switch(mode),
          child: Text(label),);
  }
}

class _FeatureLine extends StatelessWidget {
  final IconData icon;
  final String title, description;
  const _FeatureLine({required this.icon, required this.title,
      required this.description});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: colors.primary, size: 27),
      const SizedBox(width: 14),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(description, style: TextStyle(color: colors.onSurfaceVariant)),
        ],
      )),
    ]);
  }
}
