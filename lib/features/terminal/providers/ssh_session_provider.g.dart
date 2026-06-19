// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ssh_session_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// SSH terminal session provider.
///
/// Manages the full lifecycle of one SSH connection:
///   - SSHClient (transport) and SSHSession (PTY shell)
///   - xterm Terminal model (ANSI rendering state)
///   - Crash-safe transport error handling (T-03-03)
///   - Graceful cleanup on dispose (T-03-06)
///
/// Usage: `ref.watch(sshSessionProvider(machineId))`
/// Returns `AsyncValue<Terminal>` — loading while connecting, error on failure.

@ProviderFor(SshSession)
final sshSessionProvider = SshSessionFamily._();

/// SSH terminal session provider.
///
/// Manages the full lifecycle of one SSH connection:
///   - SSHClient (transport) and SSHSession (PTY shell)
///   - xterm Terminal model (ANSI rendering state)
///   - Crash-safe transport error handling (T-03-03)
///   - Graceful cleanup on dispose (T-03-06)
///
/// Usage: `ref.watch(sshSessionProvider(machineId))`
/// Returns `AsyncValue<Terminal>` — loading while connecting, error on failure.
final class SshSessionProvider
    extends $AsyncNotifierProvider<SshSession, Terminal> {
  /// SSH terminal session provider.
  ///
  /// Manages the full lifecycle of one SSH connection:
  ///   - SSHClient (transport) and SSHSession (PTY shell)
  ///   - xterm Terminal model (ANSI rendering state)
  ///   - Crash-safe transport error handling (T-03-03)
  ///   - Graceful cleanup on dispose (T-03-06)
  ///
  /// Usage: `ref.watch(sshSessionProvider(machineId))`
  /// Returns `AsyncValue<Terminal>` — loading while connecting, error on failure.
  SshSessionProvider._({
    required SshSessionFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'sshSessionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$sshSessionHash();

  @override
  String toString() {
    return r'sshSessionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SshSession create() => SshSession();

  @override
  bool operator ==(Object other) {
    return other is SshSessionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sshSessionHash() => r'3ba65a89f3f686c019a3b1250b68451f4744d96e';

/// SSH terminal session provider.
///
/// Manages the full lifecycle of one SSH connection:
///   - SSHClient (transport) and SSHSession (PTY shell)
///   - xterm Terminal model (ANSI rendering state)
///   - Crash-safe transport error handling (T-03-03)
///   - Graceful cleanup on dispose (T-03-06)
///
/// Usage: `ref.watch(sshSessionProvider(machineId))`
/// Returns `AsyncValue<Terminal>` — loading while connecting, error on failure.

final class SshSessionFamily extends $Family
    with
        $ClassFamilyOverride<
          SshSession,
          AsyncValue<Terminal>,
          Terminal,
          FutureOr<Terminal>,
          String
        > {
  SshSessionFamily._()
    : super(
        retry: null,
        name: r'sshSessionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// SSH terminal session provider.
  ///
  /// Manages the full lifecycle of one SSH connection:
  ///   - SSHClient (transport) and SSHSession (PTY shell)
  ///   - xterm Terminal model (ANSI rendering state)
  ///   - Crash-safe transport error handling (T-03-03)
  ///   - Graceful cleanup on dispose (T-03-06)
  ///
  /// Usage: `ref.watch(sshSessionProvider(machineId))`
  /// Returns `AsyncValue<Terminal>` — loading while connecting, error on failure.

  SshSessionProvider call(String machineId) =>
      SshSessionProvider._(argument: machineId, from: this);

  @override
  String toString() => r'sshSessionProvider';
}

/// SSH terminal session provider.
///
/// Manages the full lifecycle of one SSH connection:
///   - SSHClient (transport) and SSHSession (PTY shell)
///   - xterm Terminal model (ANSI rendering state)
///   - Crash-safe transport error handling (T-03-03)
///   - Graceful cleanup on dispose (T-03-06)
///
/// Usage: `ref.watch(sshSessionProvider(machineId))`
/// Returns `AsyncValue<Terminal>` — loading while connecting, error on failure.

abstract class _$SshSession extends $AsyncNotifier<Terminal> {
  late final _$args = ref.$arg as String;
  String get machineId => _$args;

  FutureOr<Terminal> build(String machineId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Terminal>, Terminal>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Terminal>, Terminal>,
              AsyncValue<Terminal>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
