// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'permission_detector_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// StreamNotifier that scans terminal stdout for Claude Code permission prompts.
///
/// Emits the matched permission line (truncated to 80 chars) when a prompt is
/// detected, or null when no permission prompt is present. The null emission
/// drives the AnimatedSwitcher to hide the PermissionCard.
///
/// Detection is gated on session state — emits Stream.empty() while the initial
/// connection is in progress (SshConnecting, loading, error). For all states that
/// carry an active Terminal (SshConnected, SshReconnecting, SshFailed), the
/// permission stream remains live so permission prompts still surface from the
/// scrollback even during a mid-session drop.
///
/// Note: the SSH provider emits AsyncData on every countdown tick (1 Hz), so this
/// provider rebuilds on each tick. Re-subscription is lightweight; .select() is not
/// supported on generated provider types in Riverpod 3.x / riverpod_generator 4.x.

@ProviderFor(PermissionDetector)
final permissionDetectorProvider = PermissionDetectorFamily._();

/// StreamNotifier that scans terminal stdout for Claude Code permission prompts.
///
/// Emits the matched permission line (truncated to 80 chars) when a prompt is
/// detected, or null when no permission prompt is present. The null emission
/// drives the AnimatedSwitcher to hide the PermissionCard.
///
/// Detection is gated on session state — emits Stream.empty() while the initial
/// connection is in progress (SshConnecting, loading, error). For all states that
/// carry an active Terminal (SshConnected, SshReconnecting, SshFailed), the
/// permission stream remains live so permission prompts still surface from the
/// scrollback even during a mid-session drop.
///
/// Note: the SSH provider emits AsyncData on every countdown tick (1 Hz), so this
/// provider rebuilds on each tick. Re-subscription is lightweight; .select() is not
/// supported on generated provider types in Riverpod 3.x / riverpod_generator 4.x.
final class PermissionDetectorProvider
    extends $StreamNotifierProvider<PermissionDetector, String?> {
  /// StreamNotifier that scans terminal stdout for Claude Code permission prompts.
  ///
  /// Emits the matched permission line (truncated to 80 chars) when a prompt is
  /// detected, or null when no permission prompt is present. The null emission
  /// drives the AnimatedSwitcher to hide the PermissionCard.
  ///
  /// Detection is gated on session state — emits Stream.empty() while the initial
  /// connection is in progress (SshConnecting, loading, error). For all states that
  /// carry an active Terminal (SshConnected, SshReconnecting, SshFailed), the
  /// permission stream remains live so permission prompts still surface from the
  /// scrollback even during a mid-session drop.
  ///
  /// Note: the SSH provider emits AsyncData on every countdown tick (1 Hz), so this
  /// provider rebuilds on each tick. Re-subscription is lightweight; .select() is not
  /// supported on generated provider types in Riverpod 3.x / riverpod_generator 4.x.
  PermissionDetectorProvider._({
    required PermissionDetectorFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'permissionDetectorProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$permissionDetectorHash();

  @override
  String toString() {
    return r'permissionDetectorProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  PermissionDetector create() => PermissionDetector();

  @override
  bool operator ==(Object other) {
    return other is PermissionDetectorProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$permissionDetectorHash() =>
    r'5981e0b5ff2c14b0fcba1f90fe131201a9d6be78';

/// StreamNotifier that scans terminal stdout for Claude Code permission prompts.
///
/// Emits the matched permission line (truncated to 80 chars) when a prompt is
/// detected, or null when no permission prompt is present. The null emission
/// drives the AnimatedSwitcher to hide the PermissionCard.
///
/// Detection is gated on session state — emits Stream.empty() while the initial
/// connection is in progress (SshConnecting, loading, error). For all states that
/// carry an active Terminal (SshConnected, SshReconnecting, SshFailed), the
/// permission stream remains live so permission prompts still surface from the
/// scrollback even during a mid-session drop.
///
/// Note: the SSH provider emits AsyncData on every countdown tick (1 Hz), so this
/// provider rebuilds on each tick. Re-subscription is lightweight; .select() is not
/// supported on generated provider types in Riverpod 3.x / riverpod_generator 4.x.

final class PermissionDetectorFamily extends $Family
    with
        $ClassFamilyOverride<
          PermissionDetector,
          AsyncValue<String?>,
          String?,
          Stream<String?>,
          String
        > {
  PermissionDetectorFamily._()
    : super(
        retry: null,
        name: r'permissionDetectorProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// StreamNotifier that scans terminal stdout for Claude Code permission prompts.
  ///
  /// Emits the matched permission line (truncated to 80 chars) when a prompt is
  /// detected, or null when no permission prompt is present. The null emission
  /// drives the AnimatedSwitcher to hide the PermissionCard.
  ///
  /// Detection is gated on session state — emits Stream.empty() while the initial
  /// connection is in progress (SshConnecting, loading, error). For all states that
  /// carry an active Terminal (SshConnected, SshReconnecting, SshFailed), the
  /// permission stream remains live so permission prompts still surface from the
  /// scrollback even during a mid-session drop.
  ///
  /// Note: the SSH provider emits AsyncData on every countdown tick (1 Hz), so this
  /// provider rebuilds on each tick. Re-subscription is lightweight; .select() is not
  /// supported on generated provider types in Riverpod 3.x / riverpod_generator 4.x.

  PermissionDetectorProvider call(String machineId) =>
      PermissionDetectorProvider._(argument: machineId, from: this);

  @override
  String toString() => r'permissionDetectorProvider';
}

/// StreamNotifier that scans terminal stdout for Claude Code permission prompts.
///
/// Emits the matched permission line (truncated to 80 chars) when a prompt is
/// detected, or null when no permission prompt is present. The null emission
/// drives the AnimatedSwitcher to hide the PermissionCard.
///
/// Detection is gated on session state — emits Stream.empty() while the initial
/// connection is in progress (SshConnecting, loading, error). For all states that
/// carry an active Terminal (SshConnected, SshReconnecting, SshFailed), the
/// permission stream remains live so permission prompts still surface from the
/// scrollback even during a mid-session drop.
///
/// Note: the SSH provider emits AsyncData on every countdown tick (1 Hz), so this
/// provider rebuilds on each tick. Re-subscription is lightweight; .select() is not
/// supported on generated provider types in Riverpod 3.x / riverpod_generator 4.x.

abstract class _$PermissionDetector extends $StreamNotifier<String?> {
  late final _$args = ref.$arg as String;
  String get machineId => _$args;

  Stream<String?> build(String machineId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<String?>, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<String?>, String?>,
              AsyncValue<String?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
