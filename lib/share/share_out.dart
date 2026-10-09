import 'dart:io';

import 'package:file_saver/file_saver.dart';
import 'package:share_plus/share_plus.dart';

/// Copies a local file into the shared Download/ folder via MediaStore —
/// no picker on Android 10+, no bytes through Dart memory (streams from
/// the staged file path). Returns the MediaStore content URI.
Future<String?> saveLocalFileToDownloads(File file) {
  final n = file.uri.pathSegments.last;
  return FileSaver.instance.saveToDownloads(
    name: n,
    filePath: file.path,
    // The staged name already carries its extension.
    includeExtension: false,
    mimeType: MimeType.custom,
    customMimeType: mimeTypeForFile(n),
  );
}

/// Shares a local file through the system share sheet with a best-effort
/// MIME type. Workspace files need the bytes, never a gateway link —
/// receivers can't pass the backend's cookie auth.
Future<ShareResult> shareLocalFile(File file) {
  final n = file.uri.pathSegments.last;
  return SharePlus.instance.share(ShareParams(files: [
    XFile(file.path, name: n, mimeType: mimeTypeForFile(n)),
  ]));
}

/// Small extension → MIME table for the share intent; unknown types fall
/// back to application/octet-stream so receivers still get the bytes.
String mimeTypeForFile(String name) {
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  const map = <String, String>{
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'bmp': 'image/bmp',
    'svg': 'image/svg+xml',
    'pdf': 'application/pdf',
    'txt': 'text/plain',
    'log': 'text/plain',
    'md': 'text/markdown',
    'markdown': 'text/markdown',
    'json': 'application/json',
    'csv': 'text/csv',
    'html': 'text/html',
    'htm': 'text/html',
    'yaml': 'application/yaml',
    'yml': 'application/yaml',
    'xml': 'text/xml',
    'zip': 'application/zip',
    'mp3': 'audio/mpeg',
    'wav': 'audio/wav',
    'm4a': 'audio/mp4',
    'aac': 'audio/aac',
    'ogg': 'audio/ogg',
    'flac': 'audio/flac',
    'mp4': 'video/mp4',
    'm4v': 'video/mp4',
    'mov': 'video/quicktime',
    'mkv': 'video/x-matroska',
    'webm': 'video/webm',
  };
  return map[ext] ?? 'application/octet-stream';
}
