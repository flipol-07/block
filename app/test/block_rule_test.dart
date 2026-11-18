import 'package:block/features/rules/block_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normaliza apps', () {
    expect(BlockRule.parse('app', 'WhatsApp')!.value, 'whatsapp.exe');
    expect(BlockRule.parse('app', r'C:\Apps\Discord.exe')!.value, 'discord.exe');
    expect(BlockRule.parse('app', '  '), isNull);
  });

  test('normaliza webs', () {
    expect(BlockRule.parse('site', 'https://www.YouTube.com/watch?v=1')!.value, 'youtube.com');
    expect(BlockRule.parse('site', 'reddit.com')!.value, 'reddit.com');
    expect(BlockRule.parse('site', 'no es web'), isNull);
  });
}
