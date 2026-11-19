import 'package:flutter_test/flutter_test.dart';
import 'package:re_highlight/languages/dockerfile.dart';
import 'package:re_highlight/languages/makefile.dart';
import 'package:re_highlight/languages/plaintext.dart';
import 'package:re_highlight/languages/python.dart';

import 'package:fluctio_android/files/file_kind.dart';

void main() {
  group('workspaceFileExt', () {
    test('lowercases and takes the last segment', () {
      expect(workspaceFileExt('A.MD'), 'md');
      expect(workspaceFileExt('a/b/c.py'), 'py');
      expect(workspaceFileExt('noext'), '');
    });

    test('directory segments are stripped before splitting on dots', () {
      // A dotted directory must not leak into the extension.
      expect(workspaceFileExt('conf.d/app.conf'), 'conf');
      expect(workspaceFileExt('.github/workflows/build'), '');
      expect(workspaceFileExt('v1.2/notes.md'), 'md');
    });
  });

  group('isMarkdownFileName', () {
    test('md/markdown true, code false', () {
      expect(isMarkdownFileName('notes.md'), isTrue);
      expect(isMarkdownFileName('notes.markdown'), isTrue);
      expect(isMarkdownFileName('script.py'), isFalse);
      expect(isMarkdownFileName('data.json'), isFalse);
    });
  });

  group('isTextFileName', () {
    test('covers the expanded code/config whitelist', () {
      for (final n in ['script.py', 'style.css', 'app.tsx', 'main.go',
          'container.dockerfile', 'docker-compose.yml', '.gitignore', 'app.properties']) {
        expect(isTextFileName(n), isTrue, reason: n);
      }
    });

    test('extension-less well-known names, at any depth', () {
      for (final n in ['Makefile', 'Dockerfile', 'LICENSE', 'CHANGELOG',
          'README', 'sub/Makefile', 'docs/LICENSE']) {
        expect(isTextFileName(n), isTrue, reason: n);
      }
    });

    test('rejects images, media, unknown binaries', () {
      for (final n in ['photo.png', 'clip.mp4', 'archive.zip', 'data.bin']) {
        expect(isTextFileName(n), isFalse, reason: n);
      }
    });
  });

  group('canInlinePreview', () {
    test('text family + images + pdf inline; html/media stay push', () {
      expect(canInlinePreview('script.py'), isTrue);
      expect(canInlinePreview('style.css'), isTrue);
      expect(canInlinePreview('notes.md'), isTrue);
      expect(canInlinePreview('doc.pdf'), isTrue);
      expect(canInlinePreview('img.jpg'), isTrue);
      expect(canInlinePreview('page.html'), isFalse);
      expect(canInlinePreview('song.mp3'), isFalse);
    });
  });

  group('highlightModeFor', () {
    test('resolves known extensions to their language mode', () {
      expect(identical(highlightModeFor('script.py'), langPython), isTrue);
      expect(
          identical(highlightModeFor('deploy.dockerfile'), langDockerfile),
          isTrue);
    });

    test('extension-less well-known names resolve via basename', () {
      expect(identical(highlightModeFor('Dockerfile'), langDockerfile), isTrue);
      expect(identical(highlightModeFor('sub/Makefile'), langMakefile), isTrue);
    });

    test('unknown falls back to plaintext', () {
      expect(identical(highlightModeFor('data.zzz'), langPlaintext), isTrue);
      expect(identical(highlightModeFor('LICENSE'), langPlaintext), isTrue);
    });
  });
}
