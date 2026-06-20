import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'biometric_auth_provider.g.dart';

/// Single source of truth for biometric authentication state.
///
/// keepAlive: true prevents autoDispose from resetting isAuthenticated
/// during GoRouter navigation transitions (RESEARCH.md Pitfall 4).
/// App starts locked (build() => false). Call setAuthenticated(true)
/// after a successful local_auth authenticate() call.
@Riverpod(keepAlive: true)
class BiometricAuth extends _$BiometricAuth {
  @override
  bool build() => false; // locked on cold start

  void setAuthenticated(bool value) => state = value;
}
