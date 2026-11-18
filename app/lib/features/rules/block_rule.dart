/// Algo que Block bloquea durante una sesion: un ejecutable de Windows
/// (`kind: app`) o un dominio web (`kind: site`).
class BlockRule {
  const BlockRule({required this.kind, required this.value, this.enabled = true});

  final String kind;
  final String value;
  final bool enabled;

  String get platform => kind == 'app' ? 'windows' : 'web';

  BlockRule copyWith({bool? enabled}) =>
      BlockRule(kind: kind, value: value, enabled: enabled ?? this.enabled);

  factory BlockRule.fromJson(Map<String, dynamic> json) => BlockRule(
        kind: json['kind'] as String,
        value: json['value'] as String,
        enabled: json['enabled'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() =>
      {'kind': kind, 'value': value, 'enabled': enabled};

  /// Normaliza lo que escribe el usuario: `WhatsApp` -> `whatsapp.exe`,
  /// `https://www.youtube.com/x` -> `youtube.com`. Devuelve null si no vale.
  static BlockRule? parse(String kind, String input) {
    var v = input.trim().toLowerCase();
    if (v.isEmpty || v.length > 200) return null;
    if (kind == 'app') {
      v = v.split(RegExp(r'[\\/]')).last;
      if (!v.endsWith('.exe')) v = '$v.exe';
      return RegExp(r'^[\w .\-]+\.exe$').hasMatch(v)
          ? BlockRule(kind: kind, value: v)
          : null;
    }
    v = v.replaceFirst(RegExp(r'^[a-z]+://'), '').split('/').first;
    v = v.replaceFirst(RegExp(r'^www\.'), '');
    return RegExp(r'^[a-z0-9\-]+(\.[a-z0-9\-]+)+$').hasMatch(v)
        ? BlockRule(kind: kind, value: v)
        : null;
  }
}

const defaultRules = <BlockRule>[
  BlockRule(kind: 'app', value: 'whatsapp.exe'),
  BlockRule(kind: 'app', value: 'whatsapp.root.exe'),
  BlockRule(kind: 'app', value: 'discord.exe'),
  BlockRule(kind: 'app', value: 'telegram.exe'),
  BlockRule(kind: 'app', value: 'spotify.exe'),
  BlockRule(kind: 'app', value: 'steam.exe'),
  BlockRule(kind: 'site', value: 'youtube.com'),
  BlockRule(kind: 'site', value: 'instagram.com'),
  BlockRule(kind: 'site', value: 'tiktok.com'),
  BlockRule(kind: 'site', value: 'x.com'),
  BlockRule(kind: 'site', value: 'twitter.com'),
  BlockRule(kind: 'site', value: 'reddit.com'),
  BlockRule(kind: 'site', value: 'facebook.com'),
  BlockRule(kind: 'site', value: 'web.whatsapp.com'),
  BlockRule(kind: 'site', value: 'netflix.com'),
  BlockRule(kind: 'site', value: 'twitch.tv'),
];
