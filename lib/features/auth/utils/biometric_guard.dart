import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// One-shot re-authentication guard for sensitive actions (BIO-02).
///
/// Calls the OS biometric/PIN prompt via local_auth 2.x.
/// Returns true when the user successfully authenticates.
/// Returns false on failure, cancellation, or PlatformException.
///
/// biometricOnly is NOT set (defaults to false) — PIN-only devices receive
/// the OS PIN dialog automatically (BIO-04). No extra code path needed.
///
/// Distinct from biometricAuthProvider: this is a one-shot challenge for
/// a sensitive action, not the app-level session lock state.
Future<bool> requireBiometric() async {
  final auth = LocalAuthentication();
  try {
    return await auth.authenticate(
      localizedReason: 'Autentícate para modificar las credenciales',
    );
  } on PlatformException {
    return false;
  }
}
