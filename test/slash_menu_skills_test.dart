import 'package:flutter_test/flutter_test.dart';
import 'package:fluctio_android/chat/models.dart';
import 'package:fluctio_android/chat/slash_commands.dart';

void main() {
  test('bare slash lists commands then skills', () {
    final items = matchSlashCommands('/', skills: const [SkillInfo(name: 'pdf', description: 'Parse PDF files')]);
    expect(items.first.name, 'new');
    expect(items.last.isSkill, isTrue);
    expect(items.last.name, 'pdf');
  });

  test('fuzzy match hits name and description (a couple letters)', () {
    final skills = const [
      SkillInfo(name: 'pdf-tool', description: 'Parse PDF files'),
      SkillInfo(name: 'weather', description: 'Fetch weather forecasts'),
    ];
    // Substring mid-name.
    expect(matchSlashCommands('/tool', skills: skills).map((s) => s.name), contains('pdf-tool'));
    // Description substring.
    expect(matchSlashCommands('/forecast', skills: skills).map((s) => s.name), contains('weather'));
    // Command matched by description too.
    expect(matchSlashCommands('/billing', skills: skills).map((s) => s.name), contains('usage'));
    // Non-matching query drops both kinds.
    expect(matchSlashCommands('/zzz', skills: skills), isEmpty);
  });

  test('built-in commands keep exact prefix behavior and no skills flag', () {
    final items = matchSlashCommands('/ins');
    expect(items.map((c) => c.name), contains('insights'));
    expect(items.every((c) => !c.isSkill), isTrue);
  });
}
