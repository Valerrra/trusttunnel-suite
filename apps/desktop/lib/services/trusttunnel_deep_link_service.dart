import 'dart:convert';
import 'dart:typed_data';

import '../models/server_config.dart';

class TrustTunnelDeepLinkService {
  static const String _schemePrefix = 'tt://?';

  static const int _tagHostname = 0x01;
  static const int _tagAddresses = 0x02;
  static const int _tagCustomSni = 0x03;
  static const int _tagHasIpv6 = 0x04;
  static const int _tagUsername = 0x05;
  static const int _tagPassword = 0x06;
  static const int _tagSkipVerification = 0x07;
  static const int _tagCertificate = 0x08;
  static const int _tagUpstreamProtocol = 0x09;
  static const int _tagAntiDpi = 0x0A;
  static const int _tagClientRandomPrefix = 0x0B;

  bool looksLikeDeepLink(String value) {
    return _normalizeInput(value).toLowerCase().startsWith(_schemePrefix);
  }

  ServerConfig parse(
    String value, {
    ServerConfig? baseConfig,
  }) {
    final normalized = _normalizeInput(value);
    if (!normalized.toLowerCase().startsWith(_schemePrefix)) {
      throw const FormatException('Expected TrustTunnel deep link starting with tt://?');
    }

    final payload = normalized
        .substring(_schemePrefix.length)
        .replaceAll(RegExp(r'\s+'), '');
    if (payload.isEmpty) {
      throw const FormatException('Deep link payload is empty');
    }

    final decoded = _decodePayload(payload);
    final fields = _parseFields(decoded);

    final hostname = _readUtf8(fields, _tagHostname);
    final addresses = _readUtf8List(fields, _tagAddresses);
    final username = _readUtf8(fields, _tagUsername);
    final password = _readUtf8(fields, _tagPassword);

    if (addresses.isEmpty) {
      throw const FormatException('Deep link does not contain endpoint addresses');
    }

    final endpointAddress = _parseAddressEntry(addresses.first);
    final base = baseConfig ?? ServerConfig.defaultConfig();

    return base.copyWith(
      hostname: hostname,
      address: endpointAddress.host,
      port: endpointAddress.port,
      hasIpv6: _readBool(fields, _tagHasIpv6, defaultValue: true),
      username: username,
      password: password,
      skipVerification:
          _readBool(fields, _tagSkipVerification, defaultValue: false),
      upstreamProtocol: _readUpstreamProtocol(fields),
      antiDpi: _readBool(fields, _tagAntiDpi, defaultValue: false),
      customSni: _readOptionalUtf8(fields, _tagCustomSni) ?? '',
      clientRandomPrefix:
          _readOptionalUtf8(fields, _tagClientRandomPrefix) ?? '',
      certificate: _readCertificatePem(fields),
    );
  }

  String _normalizeInput(String value) {
    var result = value.trim();
    if ((result.startsWith('"') && result.endsWith('"')) ||
        (result.startsWith("'") && result.endsWith("'"))) {
      result = result.substring(1, result.length - 1).trim();
    }
    return result;
  }

  Uint8List _decodePayload(String payload) {
    var normalized = payload.replaceAll('-', '+').replaceAll('_', '/');
    final padding = normalized.length % 4;
    if (padding != 0) {
      normalized = normalized.padRight(normalized.length + (4 - padding), '=');
    }

    try {
      return Uint8List.fromList(base64.decode(normalized));
    } catch (_) {
      throw const FormatException('Deep link payload is not valid base64url');
    }
  }

  Map<int, List<Uint8List>> _parseFields(Uint8List bytes) {
    final fields = <int, List<Uint8List>>{};
    var offset = 0;

    while (offset < bytes.length) {
      final tagValue = _readVarint(bytes, offset);
      offset += tagValue.byteLength;

      final lengthValue = _readVarint(bytes, offset);
      offset += lengthValue.byteLength;

      if (offset + lengthValue.value > bytes.length) {
        throw const FormatException('Deep link field length exceeds payload size');
      }

      final rawValue = Uint8List.fromList(
        bytes.sublist(offset, offset + lengthValue.value),
      );
      fields.putIfAbsent(tagValue.value, () => []).add(rawValue);
      offset += lengthValue.value;
    }

    return fields;
  }

  String _readUtf8(Map<int, List<Uint8List>> fields, int tag) {
    final value = _readOptionalUtf8(fields, tag);
    if (value == null || value.isEmpty) {
      throw FormatException('Deep link is missing required field 0x${tag.toRadixString(16)}');
    }
    return value;
  }

  String? _readOptionalUtf8(Map<int, List<Uint8List>> fields, int tag) {
    final entries = fields[tag];
    if (entries == null || entries.isEmpty) {
      return null;
    }
    return utf8.decode(entries.last);
  }

  List<String> _readUtf8List(Map<int, List<Uint8List>> fields, int tag) {
    final entries = fields[tag];
    if (entries == null || entries.isEmpty) {
      return const [];
    }
    return entries.map((entry) => utf8.decode(entry)).toList();
  }

  bool _readBool(
    Map<int, List<Uint8List>> fields,
    int tag, {
    required bool defaultValue,
  }) {
    final entries = fields[tag];
    if (entries == null || entries.isEmpty) {
      return defaultValue;
    }
    final raw = entries.last;
    if (raw.isEmpty) {
      return defaultValue;
    }
    return raw.first != 0;
  }

  String _readUpstreamProtocol(Map<int, List<Uint8List>> fields) {
    final entries = fields[_tagUpstreamProtocol];
    if (entries == null || entries.isEmpty || entries.last.isEmpty) {
      return 'http2';
    }

    switch (entries.last.first) {
      case 0x01:
        return 'http2';
      case 0x02:
        return 'http3';
      default:
        throw const FormatException('Unsupported upstream protocol in deep link');
    }
  }

  String _readCertificatePem(Map<int, List<Uint8List>> fields) {
    final entries = fields[_tagCertificate];
    if (entries == null || entries.isEmpty || entries.last.isEmpty) {
      return '';
    }

    final certificates = _splitDerCertificates(entries.last);
    return certificates.map(_derCertificateToPem).join('\n');
  }

  List<Uint8List> _splitDerCertificates(Uint8List chain) {
    final certificates = <Uint8List>[];
    var offset = 0;

    while (offset < chain.length) {
      if (chain[offset] != 0x30) {
        throw const FormatException('Invalid DER certificate chain in deep link');
      }

      final objectLength = _readAsn1ObjectLength(chain, offset);
      if (offset + objectLength > chain.length) {
        throw const FormatException('DER certificate extends beyond payload size');
      }

      certificates.add(Uint8List.fromList(
        chain.sublist(offset, offset + objectLength),
      ));
      offset += objectLength;
    }

    return certificates;
  }

  int _readAsn1ObjectLength(Uint8List bytes, int offset) {
    if (offset + 2 > bytes.length) {
      throw const FormatException('Truncated DER certificate data');
    }

    final firstLengthByte = bytes[offset + 1];
    if ((firstLengthByte & 0x80) == 0) {
      return 2 + firstLengthByte;
    }

    final lengthByteCount = firstLengthByte & 0x7f;
    if (lengthByteCount == 0) {
      throw const FormatException('Indefinite DER lengths are not supported');
    }
    if (offset + 2 + lengthByteCount > bytes.length) {
      throw const FormatException('Truncated DER certificate length');
    }

    var contentLength = 0;
    for (var i = 0; i < lengthByteCount; i++) {
      contentLength = (contentLength << 8) | bytes[offset + 2 + i];
    }

    return 2 + lengthByteCount + contentLength;
  }

  String _derCertificateToPem(Uint8List certificate) {
    final encoded = base64.encode(certificate);
    final lines = <String>[];
    for (var i = 0; i < encoded.length; i += 64) {
      lines.add(encoded.substring(i, i + 64 > encoded.length ? encoded.length : i + 64));
    }
    return [
      '-----BEGIN CERTIFICATE-----',
      ...lines,
      '-----END CERTIFICATE-----',
    ].join('\n');
  }

  _AddressEntry _parseAddressEntry(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Endpoint address is empty');
    }

    if (trimmed.startsWith('[')) {
      final closingIndex = trimmed.indexOf(']');
      if (closingIndex <= 1 || closingIndex + 2 >= trimmed.length) {
        throw FormatException('Unsupported endpoint address: $trimmed');
      }

      final host = trimmed.substring(1, closingIndex);
      final port = int.tryParse(trimmed.substring(closingIndex + 2));
      if (port == null) {
        throw FormatException('Invalid port in endpoint address: $trimmed');
      }
      return _AddressEntry(host: host, port: port);
    }

    final separatorIndex = trimmed.lastIndexOf(':');
    if (separatorIndex <= 0 || separatorIndex == trimmed.length - 1) {
      throw FormatException('Endpoint address must be in host:port format: $trimmed');
    }

    final host = trimmed.substring(0, separatorIndex);
    final port = int.tryParse(trimmed.substring(separatorIndex + 1));
    if (port == null) {
      throw FormatException('Invalid port in endpoint address: $trimmed');
    }

    return _AddressEntry(host: host, port: port);
  }

  _VarintValue _readVarint(Uint8List bytes, int offset) {
    if (offset >= bytes.length) {
      throw const FormatException('Unexpected end of deep link payload');
    }

    final first = bytes[offset];
    final prefix = first >> 6;
    final byteLength = switch (prefix) {
      0 => 1,
      1 => 2,
      2 => 4,
      _ => 8,
    };

    if (offset + byteLength > bytes.length) {
      throw const FormatException('Truncated varint in deep link payload');
    }

    var value = first & 0x3f;
    for (var i = 1; i < byteLength; i++) {
      value = (value << 8) | bytes[offset + i];
    }

    return _VarintValue(value: value, byteLength: byteLength);
  }
}

class _VarintValue {
  final int value;
  final int byteLength;

  const _VarintValue({
    required this.value,
    required this.byteLength,
  });
}

class _AddressEntry {
  final String host;
  final int port;

  const _AddressEntry({
    required this.host,
    required this.port,
  });
}
