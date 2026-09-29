import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../util/open_url.dart';

final updateServiceProvider = Provider<UpdateService>((ref) => UpdateService());

/// In-app update check (ticket 12): compares the running version against
/// the latest GitHub Release (the same release the CI pipeline publishes
/// to) and hands the APK download to the system browser, whose package
/// installer completes the flow.
///
/// Uses its own bare Dio — the update host is a different trust domain
/// from the gateway: no session cookie should leak there, and its 401s
/// must not trigger the global re-login side effect.
class UpdateService {
  UpdateService();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'accept': 'application/vnd.github+json'},
  ));

  /// Default: GitHub latest release API. Kept in one place alongside the
  /// CI workflow's publish target; change here when the repo moves.
  static const checkUrl =
      'https://api.github.com/repos/moon/fluctio-android/releases/latest';

  Future<UpdateInfo?> check() async {
    final res = await _dio.get(checkUrl);
    final data = res.data;
    if (data is! Map) return null;
    final tag = '${data['tag_name'] ?? ''}';
    if (!tag.startsWith('v')) return null;
    final remote = tag.substring(1);
    final info = await PackageInfo.fromPlatform();
    if (_versionCompare(remote, info.version) <= 0) return null;
    // First .apk asset is the CI artifact (fluctio.apk).
    String? apkUrl;
    final assets = data['assets'];
    if (assets is List) {
      for (final a in assets) {
        if (a is Map && '${a['name']}'.endsWith('.apk')) {
          apkUrl = '${a['browser_download_url']}';
          break;
        }
      }
    }
    return UpdateInfo(tag: tag, current: info.version, apkUrl: apkUrl, notes: '${data['body'] ?? ''}');
  }

  /// Opens the browser download (system package installer takes over) —
  /// avoids FileProvider/READ_EXTERNAL complexity for the v1 flow.
  Future<void> openDownload(String url) => openExternalUrl(url);

  int _versionCompare(String a, String b) {
    final pa = a.split('.').map(int.tryParse).toList();
    final pb = b.split('.').map(int.tryParse).toList();
    for (var i = 0; i < 3; i++) {
      final da = i < pa.length ? (pa[i] ?? 0) : 0;
      final db = i < pb.length ? (pb[i] ?? 0) : 0;
      if (da != db) return da.compareTo(db);
    }
    return 0;
  }
}

class UpdateInfo {
  const UpdateInfo({required this.tag, required this.current, this.apkUrl, this.notes = ''});

  final String tag;
  final String current;
  final String? apkUrl;
  final String notes;
}
