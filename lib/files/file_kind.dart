import 'package:re_highlight/languages/bash.dart';
import 'package:re_highlight/languages/c.dart';
import 'package:re_highlight/languages/cpp.dart';
import 'package:re_highlight/languages/css.dart';
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/languages/diff.dart';
import 'package:re_highlight/languages/dockerfile.dart';
import 'package:re_highlight/languages/dos.dart';
import 'package:re_highlight/languages/go.dart';
import 'package:re_highlight/languages/ini.dart';
import 'package:re_highlight/languages/java.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/kotlin.dart';
import 'package:re_highlight/languages/makefile.dart';
import 'package:re_highlight/languages/plaintext.dart';
import 'package:re_highlight/languages/powershell.dart';
import 'package:re_highlight/languages/python.dart';
import 'package:re_highlight/languages/rust.dart';
import 'package:re_highlight/languages/scss.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:re_highlight/languages/typescript.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/languages/yaml.dart';
import 'package:re_highlight/re_highlight.dart';

/// Pure-Dart file-kind classification for workspace previews: the ONE
/// extension/basename parser behind every preview surface (push
/// previews, docked panel, produced-file cards) and the highlight-mode
/// map the code viewer keys off. No Flutter imports — safe from both
/// file_preview.dart and code_viewer.dart without dependency drag.

/// Lowercased extension of a file NAME ('' when none). Directory
/// segments are stripped first — a dotted directory ('.github/',
/// 'conf.d/') must not leak into the extension (split('.').last on the
/// full path yields 'workflows/build'-style garbage that matches no
/// set).
String workspaceFileExt(String name) {
  final base = _baseName(name);
  return base.contains('.') ? base.split('.').last.toLowerCase() : '';
}

String _baseName(String name) => name.split('/').last.toLowerCase();

const imgExts = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'svg'};

/// Markdown renders through the transcript renderer; every other text
/// family file goes to the read-only code viewer (literal indentation,
/// no markup interpretation — python comments are comments).
const _markdownExts = {'md', 'markdown'};

const _textExts = {
  // Docs & data
  'txt', 'md', 'markdown', 'json', 'csv', 'tsv', 'log', 'yaml', 'yml',
  'xml', 'toml', 'ini', 'conf', 'cfg', 'env', 'properties', 'sql',
  // Scripts
  'sh', 'bash', 'zsh', 'bat', 'cmd', 'ps1', 'pl', 'pm', 'tcl',
  // Web
  'css', 'scss', 'less', 'vue', 'svelte', 'graphql', 'gql', 'proto',
  // General languages
  'dart', 'py', 'js', 'mjs', 'cjs', 'ts', 'tsx', 'jsx', 'go', 'rs',
  'java', 'kt', 'kts', 'scala', 'cs', 'rb', 'php', 'swift', 'lua', 'r',
  'clj', 'ex', 'exs', 'erl', 'hs', 'c', 'cpp', 'h', 'hpp', 'cc', 'hh',
  'm', 'mm', 'cmake', 'mk', 'gradle', 'diff', 'patch',
  'makefile', 'dockerfile',
};

/// Dot-files and extension-less files that are still plain text —
/// workspaceFileExt('.gitignore') is 'gitignore'; Makefile has none.
const _dotExts = {'gitignore', 'gitattributes', 'editorconfig', 'npmrc', 'prettierrc'};
const _textBaseNames = {'makefile', 'dockerfile', 'license', 'changelog', 'notice', 'readme'};

/// Image files by extension (file rows' icon choice, inline preview
/// routing).
bool isImageFileName(String name) => imgExts.contains(workspaceFileExt(name));

/// True when the file should render through the markdown transcript
/// renderer rather than the code viewer.
bool isMarkdownFileName(String name) =>
    _markdownExts.contains(workspaceFileExt(name));

/// Extensions + well-known names the viewer can render as text/code.
bool isTextFileName(String name) {
  final ext = workspaceFileExt(name);
  if (_textExts.contains(ext) || _dotExts.contains(ext)) return true;
  return _textBaseNames.contains(_baseName(name));
}

/// Extensions the docked workspace panel renders INLINE (image / text /
/// pdf). Everything else (html → WebView, audio/video → player) still
/// routes to the full-screen push previews.
bool canInlinePreview(String name) {
  final ext = workspaceFileExt(name);
  return imgExts.contains(ext) || isTextFileName(name) || ext == 'pdf';
}

/// Extension (or lowercased basename for extension-less files) →
/// highlight.js mode. Keys mirror [workspaceFileExt] output plus the
/// well-known base names ('Dockerfile' has no extension — the basename
/// fallback below resolves it). Anything outside the map renders as
/// plaintext — correct, just unlit.
/// Highlight mode for one file (name, not extension — extension-less
/// well-known files like Makefile resolve through their basename).
/// The map keeps ~20 common languages (the syntax tables can't be
/// tree-shaken — every import lands in the APK, swift/ruby/... alone
/// were ~700KB of source for rarely-hit modes); everything unknown →
/// plaintext, correct just unlit.
final Map<String, Mode> _extModes = {
  'py': langPython,
  'js': langJavascript, 'mjs': langJavascript, 'cjs': langJavascript,
  'jsx': langJavascript,
  'ts': langTypescript, 'tsx': langTypescript,
  'dart': langDart, 'go': langGo, 'rs': langRust,
  'java': langJava, 'kt': langKotlin, 'kts': langKotlin,
  'c': langC, 'cpp': langCpp, 'h': langCpp, 'hpp': langCpp, 'cc': langCpp,
  'hh': langCpp,
  'sh': langBash, 'bash': langBash, 'zsh': langBash,
  'bat': langDos, 'cmd': langDos, 'ps1': langPowershell,
  'css': langCss, 'scss': langScss,
  'xml': langXml,
  'json': langJson, 'yaml': langYaml, 'yml': langYaml,
  'toml': langIni, 'ini': langIni, 'conf': langIni, 'cfg': langIni,
  'makefile': langMakefile, 'dockerfile': langDockerfile,
  'sql': langSql,
  'diff': langDiff, 'patch': langDiff,
};

/// Highlight mode for one file (name, not extension — extension-less
/// well-known files like Makefile resolve through their basename).
/// Everything unknown → plaintext.
Mode highlightModeFor(String name) {
  final ext = workspaceFileExt(name);
  return _extModes[ext] ?? _extModes[_baseName(name)] ?? langPlaintext;
}
