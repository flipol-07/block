import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'block_rule.dart';

/// Listas de bloqueo. Siempre hay copia local (para bloquear sin conexion);
/// con cuenta, la nube manda y la copia local se refresca desde ella.
class RulesRepository {
  RulesRepository(this._prefs, [this._client]);

  final SharedPreferences _prefs;
  final SupabaseClient? _client;
  static const _key = 'block_rules';

  List<BlockRule> cached() {
    final raw = _prefs.getString(_key);
    if (raw == null) return List.of(defaultRules);
    return (jsonDecode(raw) as List)
        .map((e) => BlockRule.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> _cache(List<BlockRule> rules) => _prefs.setString(
      _key, jsonEncode(rules.map((r) => r.toJson()).toList()));

  /// Descarga las reglas de la nube. La primera vez sube las de por defecto.
  Future<List<BlockRule>> refresh() async {
    final client = _client;
    if (client == null) return cached();
    final rows = await client.from('block_rules').select('kind, value, enabled');
    if (rows.isEmpty) {
      await _upsert(client, cached());
      return cached();
    }
    final rules = rows.map(BlockRule.fromJson).toList();
    await _cache(rules);
    return rules;
  }

  Future<void> save(BlockRule rule) async {
    final rules = cached()..removeWhere((r) => _same(r, rule));
    rules.add(rule);
    await _cache(rules);
    final client = _client;
    if (client != null) await _upsert(client, [rule]);
  }

  Future<void> remove(BlockRule rule) async {
    await _cache(cached()..removeWhere((r) => _same(r, rule)));
    final client = _client;
    if (client != null) {
      await client
          .from('block_rules')
          .delete()
          .eq('kind', rule.kind)
          .eq('value', rule.value);
    }
  }

  Future<void> _upsert(SupabaseClient client, List<BlockRule> rules) =>
      client.from('block_rules').upsert(
            rules
                .map((r) => {
                      'user_id': client.auth.currentUser!.id,
                      'platform': r.platform,
                      ...r.toJson(),
                    })
                .toList(),
            onConflict: 'user_id,platform,kind,value',
          );

  bool _same(BlockRule a, BlockRule b) => a.kind == b.kind && a.value == b.value;
}
