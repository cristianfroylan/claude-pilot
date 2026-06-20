// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ssh_session_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// SSH terminal session provider.
///
/// Manages the full lifecycle of one SSH connection and its reconnection state
/// machine:
///   - SSHClient (transport) and SSHSession (PTY shell)
///   - xterm Terminal model (ANSI rendering state, promoted to instance field)
///   - Initial retry loop: 5 attempts, backoff 1/2/4/8/16 seconds (RECON-01)
///   - Mid-session retry loop: 3 attempts, backoff 2/4/8 seconds (RECON-02)
///   - Per-second countdown via Timer.periodic exposed on SshSessionState
///   - cancel() and reconnect() public methods (RECON-03, RECON-04)
///   - Terminal scrollback preserved across all reconnect attempts (RECON-05)
///   - Graceful cleanup on dispose
///
/// Usage: `ref.watch(sshSessionProvider(machineId))`
/// Returns `AsyncValue<SshSessionState>` — always AsyncData after first emit.

@ProviderFor(SshSession)
final sshSessionProvider = SshSessionFamily._();

/// SSH terminal session provider.
///
/// Manages the full lifecycle of one SSH connection and its reconnection state
/// machine:
///   - SSHClient (transport) and SSHSession (PTY shell)
///   - xterm Terminal model (ANSI rendering state, promoted to instance field)
///   - Initial retry loop: 5 attempts, backoff 1/2/4/8/16 seconds (RECON-01)
///   - Mid-session retry loop: 3 attempts, backoff 2/4/8 seconds (RECON-02)
///   - Per-second countdown via Timer.periodic exposed on SshSessionState
///   - cancel() and reconnect() public methods (RECON-03, RECON-04)
///   - Terminal scrollback preserved across all reconnect attempts (RECON-05)
///   - Graceful cleanup on dispose
///
/// Usage: `ref.watch(sshSessionProvider(machineId))`
/// Returns `AsyncValue<SshSessionState>` — always AsyncData after first emit.
final class SshSessionProvider
    extends $AsyncNotifierProvider<SshSession, SshSessionState> {
  /// SSH terminal session provider.
  ///
  /// Manages the full lifecycle of one SSH connection and its reconnection state
  /// machine:
  ///   - SSHClient (transport) and SSHSession (PTY shell)
  ///   - xterm Terminal model (ANSI rendering state, promoted to instance field)
  ///   - Initial retry loop: 5 attempts, backoff 1/2/4/8/16 seconds (RECON-01)
  ///   - Mid-session retry loop: 3 attempts, backoff 2/4/8 seconds (RECON-02)
  ///   - Per-second countdown via Timer.periodic exposed on SshSessionState
  ///   - cancel() and reconnect() public methods (RECON-03, RECON-04)
  ///   - Terminal scrollback preserved across all reconnect attempts (RECON-05)
  ///   - Graceful cleanup on dispose
  ///
  /// Usage: `ref.watch(sshSessionProvider(machineId))`
  /// Returns `AsyncValue<SshSessionState>` — always AsyncData after first emit.
  SshSessionProvider._({
    required SshSessionFamily super.from,
    required String super.argument,
  }) : super(
         retry: _noRetry,
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

String _$sshSessionHash() => r'a81e1e42d591f53ff6ab352dd1bff78c8309d789';

/// SSH terminal session provider.
///
/// Manages the full lifecycle of one SSH connection and its reconnection state
/// machine:
///   - SSHClient (transport) and SSHSession (PTY shell)
///   - xterm Terminal model (ANSI rendering state, promoted to instance field)
///   - Initial retry loop: 5 attempts, backoff 1/2/4/8/16 seconds (RECON-01)
///   - Mid-session retry loop: 3 attempts, backoff 2/4/8 seconds (RECON-02)
///   - Per-second countdown via Timer.periodic exposed on SshSessionState
///   - cancel() and reconnect() public methods (RECON-03, RECON-04)
///   - Terminal scrollback preserved across all reconnect attempts (RECON-05)
///   - Graceful cleanup on dispose
///
/// Usage: `ref.watch(sshSessionProvider(machineId))`
/// Returns `AsyncValue<SshSessionState>` — always AsyncData after first emit.

final class SshSessionFamily extends $Family
    with
        $ClassFamilyOverride<
          SshSession,
          AsyncValue<SshSessionState>,
          SshSessionState,
          FutureOr<SshSessionState>,
          String
        > {
  SshSessionFamily._()
    : super(
        retry: _noRetry,
        name: r'sshSessionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// SSH terminal session provider.
  ///
  /// Manages the full lifecycle of one SSH connection and its reconnection state
  /// machine:
  ///   - SSHClient (transport) and SSHSession (PTY shell)
  ///   - xterm Terminal model (ANSI rendering state, promoted to instance field)
  ///   - Initial retry loop: 5 attempts, backoff 1/2/4/8/16 seconds (RECON-01)
  ///   - Mid-session retry loop: 3 attempts, backoff 2/4/8 seconds (RECON-02)
  ///   - Per-second countdown via Timer.periodic exposed on SshSessionState
  ///   - cancel() and reconnect() public methods (RECON-03, RECON-04)
  ///   - Terminal scrollback preserved across all reconnect attempts (RECON-05)
  ///   - Graceful cleanup on dispose
  ///
  /// Usage: `ref.watch(sshSessionProvider(machineId))`
  /// Returns `AsyncValue<SshSessionState>` — always AsyncData after first emit.

  SshSessionProvider call(String machineId) =>
      SshSessionProvider._(argument: machineId, from: this);

  @override
  String toString() => r'sshSessionProvider';
}

/// SSH terminal session provider.
///
/// Manages the full lifecycle of one SSH connection and its reconnection state
/// machine:
///   - SSHClient (transport) and SSHSession (PTY shell)
///   - xterm Terminal model (ANSI rendering state, promoted to instance field)
///   - Initial retry loop: 5 attempts, backoff 1/2/4/8/16 seconds (RECON-01)
///   - Mid-session retry loop: 3 attempts, backoff 2/4/8 seconds (RECON-02)
///   - Per-second countdown via Timer.periodic exposed on SshSessionState
///   - cancel() and reconnect() public methods (RECON-03, RECON-04)
///   - Terminal scrollback preserved across all reconnect attempts (RECON-05)
///   - Graceful cleanup on dispose
///
/// Usage: `ref.watch(sshSessionProvider(machineId))`
/// Returns `AsyncValue<SshSessionState>` — always AsyncData after first emit.

abstract class _$SshSession extends $AsyncNotifier<SshSessionState> {
  late final _$args = ref.$arg as String;
  String get machineId => _$args;

  FutureOr<SshSessionState> build(String machineId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<SshSessionState>, SshSessionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<SshSessionState>, SshSessionState>,
              AsyncValue<SshSessionState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
