// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'biometric_auth_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Single source of truth for biometric authentication state.
///
/// keepAlive: true prevents autoDispose from resetting isAuthenticated
/// during GoRouter navigation transitions (RESEARCH.md Pitfall 4).
/// App starts locked (build() => false). Call setAuthenticated(true)
/// after a successful local_auth authenticate() call.

@ProviderFor(BiometricAuth)
final biometricAuthProvider = BiometricAuthProvider._();

/// Single source of truth for biometric authentication state.
///
/// keepAlive: true prevents autoDispose from resetting isAuthenticated
/// during GoRouter navigation transitions (RESEARCH.md Pitfall 4).
/// App starts locked (build() => false). Call setAuthenticated(true)
/// after a successful local_auth authenticate() call.
final class BiometricAuthProvider
    extends $NotifierProvider<BiometricAuth, bool> {
  /// Single source of truth for biometric authentication state.
  ///
  /// keepAlive: true prevents autoDispose from resetting isAuthenticated
  /// during GoRouter navigation transitions (RESEARCH.md Pitfall 4).
  /// App starts locked (build() => false). Call setAuthenticated(true)
  /// after a successful local_auth authenticate() call.
  BiometricAuthProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'biometricAuthProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$biometricAuthHash();

  @$internal
  @override
  BiometricAuth create() => BiometricAuth();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$biometricAuthHash() => r'bca5b70d0473e537b79aa032e01feb571be5ed2b';

/// Single source of truth for biometric authentication state.
///
/// keepAlive: true prevents autoDispose from resetting isAuthenticated
/// during GoRouter navigation transitions (RESEARCH.md Pitfall 4).
/// App starts locked (build() => false). Call setAuthenticated(true)
/// after a successful local_auth authenticate() call.

abstract class _$BiometricAuth extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
