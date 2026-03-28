import 'package:flutter_test/flutter_test.dart';

import 'package:trusty_android/main.dart';

void main() {
  test('creates app widget shell', () {
    expect(const TrustyAndroidApp(), isNotNull);
    expect(const TrustyAndroidApp(), isA<TrustyAndroidApp>());
  });
}
