// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'permission_detector_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// StreamNotifier that scans terminal stdout for Claude Code permission prompts.
///
/// Keyed by (machineId, tabId) so each tab has an independent detector instance
/// even when two tabs connect to the same machine (SESS-TAB-01).

@ProviderFor(PermissionDetector)
final permissionDetectorProvider = PermissionDetectorFamily._();

/// StreamNotifier that scans terminal stdout for Claude Code permission prompts.
///
/// Keyed by (machineId, tabId) so each tab has an independent detector instance
/// even when two tabs connect to the same machine (SESS-TAB-01).
final class PermissionDetectorProvider
    extends $StreamNotifierProvider<PermissionDetector, String?> {
  /// StreamNotifier that scans terminal stdout for Claude Code permission prompts.
  ///
  /// Keyed by (machineId, tabId) so each tab has an independent detector instance
  /// even when two tabs connect to the same machine (SESS-TAB-01).
  PermissionDetectorProvider._({
    required PermissionDetectorFamily super.from,
    required (String, String) super.argument,
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
        '$argument';
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
    r'494b3bab43af4567b27db52de66d2a26ff03cc25';

/// StreamNotifier that scans terminal stdout for Claude Code permission prompts.
///
/// Keyed by (machineId, tabId) so each tab has an independent detector instance
/// even when two tabs connect to the same machine (SESS-TAB-01).

final class PermissionDetectorFamily extends $Family
    with
        $ClassFamilyOverride<
          PermissionDetector,
          AsyncValue<String?>,
          String?,
          Stream<String?>,
          (String, String)
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
  /// Keyed by (machineId, tabId) so each tab has an independent detector instance
  /// even when two tabs connect to the same machine (SESS-TAB-01).

  PermissionDetectorProvider call(String machineId, String tabId) =>
      PermissionDetectorProvider._(argument: (machineId, tabId), from: this);

  @override
  String toString() => r'permissionDetectorProvider';
}

/// StreamNotifier that scans terminal stdout for Claude Code permission prompts.
///
/// Keyed by (machineId, tabId) so each tab has an independent detector instance
/// even when two tabs connect to the same machine (SESS-TAB-01).

abstract class _$PermissionDetector extends $StreamNotifier<String?> {
  late final _$args = ref.$arg as (String, String);
  String get machineId => _$args.$1;
  String get tabId => _$args.$2;

  Stream<String?> build(String machineId, String tabId);
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
    element.handleCreate(ref, () => build(_$args.$1, _$args.$2));
  }
}
