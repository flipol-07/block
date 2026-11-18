/// Configuracion de compilacion.
///
/// La nube es opcional: sin `SUPABASE_URL`/`SUPABASE_KEY` Block funciona en
/// modo local (cada dispositivo por su cuenta). Se pasan con
/// `--dart-define-from-file=config.json` (fichero fuera de git).
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseKey = String.fromEnvironment('SUPABASE_KEY');

  static bool get cloudEnabled =>
      supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  /// Puerto del puente local que consulta la extension del navegador.
  static const bridgePort = 47613;

  /// Frase que hay que escribir para usar la salida de emergencia.
  static const exitPhrase = 'Abandono mi sesión de estudio';

  /// Segundos de espera obligatoria antes de poder abandonar.
  static const exitWaitSeconds = 60;
}
