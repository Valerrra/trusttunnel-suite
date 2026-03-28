import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:trusty/models/server_config.dart';
import 'package:trusty/services/trusttunnel_deep_link_service.dart';

void main() {
  group('TrustTunnelDeepLinkService', () {
    final service = TrustTunnelDeepLinkService();

    test('parses deep link with required and optional fields', () {
      final deepLink = _buildDeepLink({
        0x01: ['vpn.example.com'],
        0x02: ['198.51.100.10:8443'],
        0x03: ['edge.example.com'],
        0x04: [Uint8List.fromList([0x00])],
        0x05: ['premium-user'],
        0x06: ['secret-pass'],
        0x07: [Uint8List.fromList([0x01])],
        0x09: [Uint8List.fromList([0x02])],
        0x0A: [Uint8List.fromList([0x01])],
        0x0B: ['abcd1234/ffff0000'],
      });

      final config = service.parse(deepLink);

      expect(config.hostname, 'vpn.example.com');
      expect(config.address, '198.51.100.10');
      expect(config.port, 8443);
      expect(config.customSni, 'edge.example.com');
      expect(config.hasIpv6, isFalse);
      expect(config.username, 'premium-user');
      expect(config.password, 'secret-pass');
      expect(config.skipVerification, isTrue);
      expect(config.upstreamProtocol, 'http3');
      expect(config.antiDpi, isTrue);
      expect(config.clientRandomPrefix, 'abcd1234/ffff0000');
    });

    test('preserves unrelated base config fields on import', () {
      final baseConfig = ServerConfig.defaultConfig().copyWith(
        dns: '1.1.1.1',
        logLevel: 'debug',
        vpnMode: VpnMode.selective,
        splitTunnelDomains: const ['example.org'],
        splitTunnelApps: const ['telegram.exe'],
      );

      final deepLink = _buildDeepLink({
        0x01: ['vpn.example.com'],
        0x02: ['[2001:db8::10]:443'],
        0x05: ['user-a'],
        0x06: ['pass-a'],
      });

      final config = service.parse(deepLink, baseConfig: baseConfig);

      expect(config.address, '2001:db8::10');
      expect(config.port, 443);
      expect(config.dns, '1.1.1.1');
      expect(config.logLevel, 'debug');
      expect(config.vpnMode, VpnMode.selective);
      expect(config.splitTunnelDomains, ['example.org']);
      expect(config.splitTunnelApps, ['telegram.exe']);
    });

    test('rejects invalid scheme', () {
      expect(
        () => service.parse('https://example.com'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

String _buildDeepLink(Map<int, List<Object>> fields) {
  final bytes = BytesBuilder();
  for (final entry in fields.entries) {
    for (final value in entry.value) {
      final rawValue = switch (value) {
        String text => Uint8List.fromList(utf8.encode(text)),
        Uint8List data => data,
        _ => throw ArgumentError('Unsupported value type: ${value.runtimeType}'),
      };

      bytes.add(_encodeVarint(entry.key));
      bytes.add(_encodeVarint(rawValue.length));
      bytes.add(rawValue);
    }
  }

  final payload = base64Url.encode(bytes.takeBytes()).replaceAll('=', '');
  return 'tt://?$payload';
}

Uint8List _encodeVarint(int value) {
  if (value < 0) {
    throw ArgumentError('Varint value must be non-negative');
  }

  if (value <= 63) {
    return Uint8List.fromList([value]);
  }
  if (value <= 16383) {
    return Uint8List.fromList([
      0x40 | ((value >> 8) & 0x3f),
      value & 0xff,
    ]);
  }
  if (value <= 1073741823) {
    return Uint8List.fromList([
      0x80 | ((value >> 24) & 0x3f),
      (value >> 16) & 0xff,
      (value >> 8) & 0xff,
      value & 0xff,
    ]);
  }

  throw ArgumentError('Varint value is too large for this test helper');
}
