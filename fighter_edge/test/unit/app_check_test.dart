import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/security/app_check.dart';

void main() {
  test('release builds attest with the store-backed providers', () {
    final providers = appCheckProviders(debug: false);
    expect(providers.android, isA<AndroidPlayIntegrityProvider>());
    expect(providers.apple, isA<AppleDeviceCheckProvider>());
  });

  test('debug builds use the debug providers', () {
    final providers = appCheckProviders(debug: true);
    expect(providers.android, isA<AndroidDebugProvider>());
    expect(providers.apple, isA<AppleDebugProvider>());
  });
}
