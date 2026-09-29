import 'package:flutter_test/flutter_test.dart';

import 'package:fluctio_android/core/server_url.dart';

void main() {
  group('validateServerUrl', () {
    test('accepts https anywhere', () {
      expect(validateServerUrl('https://luna.example.com', allowSelfSigned: false), isNull);
      expect(validateServerUrl('https://192.168.1.5:8443/', allowSelfSigned: false), isNull);
    });

    test('rejects garbage', () {
      expect(validateServerUrl('', allowSelfSigned: false), ServerUrlError.invalidFormat);
      expect(validateServerUrl('not a url', allowSelfSigned: false), ServerUrlError.invalidFormat);
      expect(validateServerUrl('ftp://example.com', allowSelfSigned: false), ServerUrlError.invalidFormat);
    });

    test('public http is rejected even with trust enabled', () {
      expect(validateServerUrl('http://example.com', allowSelfSigned: true), ServerUrlError.httpsRequired);
    });

    test('loopback http requires the explicit opt-in', () {
      expect(validateServerUrl('http://127.0.0.1:18953', allowSelfSigned: false), ServerUrlError.lanNeedsTrust);
      expect(validateServerUrl('http://localhost:18953', allowSelfSigned: true), isNull);
    });

    test('RFC1918 http honors the opt-in', () {
      expect(validateServerUrl('http://10.0.0.4', allowSelfSigned: false), ServerUrlError.lanNeedsTrust);
      expect(validateServerUrl('http://192.168.31.2:8080', allowSelfSigned: true), isNull);
      expect(validateServerUrl('http://172.16.0.1', allowSelfSigned: true), isNull);
      // 172 outside the private 16–31 range is a public host.
      expect(validateServerUrl('http://172.32.0.1', allowSelfSigned: true), ServerUrlError.httpsRequired);
    });
  });

  test('normalizeServerUrl strips trailing slashes', () {
    expect(normalizeServerUrl('https://a.com/'), 'https://a.com');
    expect(normalizeServerUrl(' https://a.com/// '), 'https://a.com');
  });
}
