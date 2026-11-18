import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/providers.dart';
import '../../shared/ui/theme.dart';
import '../../shared/ui/glass.dart';

/// Login con email y contrasena. La misma cuenta en el PC y en el movil es
/// lo que los vincula.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;
  bool _busy = false;
  String? _message;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void initState() {
    super.initState();
    // Un aviso viejo ("necesita 8 caracteres") confunde si ya se corrigio.
    void clear() {
      if (_message != null) setState(() => _message = null);
    }
    _email.addListener(clear);
    _password.addListener(clear);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _validate() {
    if (!_emailPattern.hasMatch(_email.text.trim())) return 'Email no válido.';
    if (_password.text.length < 8) return 'La contraseña necesita 8 caracteres.';
    return null;
  }

  Future<void> _submit() async {
    final invalid = _validate();
    if (invalid != null) return setState(() => _message = invalid);
    setState(() {
      _busy = true;
      _message = null;
    });
    final auth = ref.read(supabaseProvider)!.auth;
    try {
      if (_signUp) {
        final res = await auth.signUp(email: _email.text.trim(), password: _password.text);
        if (res.session == null) {
          _message = 'Te hemos enviado un correo para confirmar la cuenta.';
        }
      } else {
        await auth.signInWithPassword(email: _email.text.trim(), password: _password.text);
      }
    } on AuthException catch (e) {
      _message = e.message;
    } catch (e) {
      _message = 'Error de conexión: $e';
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                Image.asset('assets/icon/app_icon.png', width: 72, height: 72,
                    errorBuilder: (_, _, _) => const SizedBox.shrink()),
                const SizedBox(height: 16),
                const Text(
                  'Block',
                  style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: -1.5),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Usa la misma cuenta en el PC y en el móvil para que se bloqueen juntos.',
                  style: TextStyle(color: BlockColors.muted),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                  onSubmitted: (_) => _submit(),
                ),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_message!, style: const TextStyle(color: BlockColors.accent)),
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_signUp ? 'Crear cuenta' : 'Entrar'),
                ),
                TextButton(
                  onPressed: () => setState(() => _signUp = !_signUp),
                  child: Text(_signUp ? 'Ya tengo cuenta' : 'Crear una cuenta'),
                ),
                const Divider(height: 32),
                TextButton(
                  onPressed: () => ref.read(localModeProvider.notifier).set(true),
                  child: const Text(
                    'Usar sin cuenta (solo este dispositivo)',
                    style: TextStyle(color: BlockColors.muted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
