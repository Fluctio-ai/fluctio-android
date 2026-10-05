import 'package:flutter_test/flutter_test.dart';

import 'package:fluctio_android/files/agent_files.dart';

/// buildWsFileTree mirrors the web buildFileTree (chat-screen.tsx:4193):
/// prefix-stripped relative paths split on `/` into nested folders,
/// folders sorting ahead of files.
void main() {
  AgentFile file(String path, {List<String> prefixes = const ['sessions/s1/']}) =>
      AgentFile.forTest(path, prefixes);

  test('nests subdirectories and keeps leaves on the full path', () {
    final tree = buildWsFileTree([
      file('sessions/s1/a.md'),
      file('sessions/s1/sub/x.md'),
      file('sessions/s1/sub/deep/y.md'),
    ]);
    // Folders first, then files, each level by name.
    expect(tree.map((n) => '${n.isDir ? 'd' : 'f'}:${n.name}'),
        ['d:sub', 'f:a.md']);
    expect(tree[0].relPath, 'sub');
    final sub = tree[0].children;
    expect(sub.map((n) => '${n.isDir ? 'd' : 'f'}:${n.name}'),
        ['d:deep', 'f:x.md']);
    expect(sub[1].file!.path, 'sessions/s1/sub/x.md');
    expect(sub[0].children.single.file!.path, 'sessions/s1/sub/deep/y.md');
  });

  test('same-named folder and file coexist as distinct nodes', () {
    final tree = buildWsFileTree([
      file('sessions/s1/out/report.pdf'),
      file('sessions/s1/out'),
    ]);
    // Web parity: a bare "out" file next to an "out/" directory yields
    // two distinct top-level rows — the folder first.
    expect(tree, hasLength(2));
    expect(tree[0].isDir, isTrue);
    expect(tree[0].name, 'out');
    expect(tree[0].children.single.file!.path, 'sessions/s1/out/report.pdf');
    expect(tree[1].isDir, isFalse);
    expect(tree[1].file!.path, 'sessions/s1/out');
  });

  test('sorts folders before files, then by name', () {
    final tree = buildWsFileTree([
      file('sessions/s1/z.md'),
      file('sessions/s1/alpha/b.md'),
      file('sessions/s1/a.md'),
    ]);
    expect(tree.map((n) => '${n.isDir ? 'd' : 'f'}:${n.name}'),
        ['d:alpha', 'f:a.md', 'f:z.md']);
  });

  test('empty segments and blank relative paths are skipped', () {
    final tree = buildWsFileTree([
      file('sessions/s1/'), // strips to '' — dropped
      file('sessions/s1//double.md'), // empty segment filtered
    ]);
    expect(tree, hasLength(1));
    expect(tree.single.name, 'double.md');
  });
}
