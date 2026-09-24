import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Which attestation each platform uses: the store-backed providers in
/// release builds, and the debug providers while developing (register the
/// debug token printed in the device log in Firebase App Check).
({
  AndroidAppCheckProvider android,
  AppleAppCheckProvider apple
}) appCheckProviders({required bool debug}) => debug
    ? (android: const AndroidDebugProvider(), apple: const AppleDebugProvider())
    : (
        android: const AndroidPlayIntegrityProvider(),
        // DeviceCheck needs no extra entitlement. App Attest is stronger;
        // switch once the App Attest capability is added in Xcode.
        apple: const AppleDeviceCheckProvider(),
      );

/// Lets the backend check that requests come from this app, not a script
/// (audit S-4). The server only refuses requests without a token once
/// `ENFORCE_APP_CHECK` is on, so a failure here never blocks the app today;
/// it is reported in debug builds only.
Future<void> activateAppCheck({bool debug = kDebugMode}) async {
  // No web attestation provider is configured; the stores are the targets.
  if (kIsWeb) return;
  final providers = appCheckProviders(debug: debug);
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: providers.android,
      providerApple: providers.apple,
    );
  } catch (error) {
    if (kDebugMode) debugPrint('[app-check] activation failed: $error');
  }
}
