// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'machines_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Riverpod AsyncNotifier for Machine CRUD.
/// Generated provider name: machineNotifierProvider.
/// (Named MachineNotifier to avoid collision with MachineRepository class.)

@ProviderFor(MachineNotifier)
final machineProvider = MachineNotifierProvider._();

/// Riverpod AsyncNotifier for Machine CRUD.
/// Generated provider name: machineNotifierProvider.
/// (Named MachineNotifier to avoid collision with MachineRepository class.)
final class MachineNotifierProvider
    extends $AsyncNotifierProvider<MachineNotifier, List<Machine>> {
  /// Riverpod AsyncNotifier for Machine CRUD.
  /// Generated provider name: machineNotifierProvider.
  /// (Named MachineNotifier to avoid collision with MachineRepository class.)
  MachineNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'machineProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$machineNotifierHash();

  @$internal
  @override
  MachineNotifier create() => MachineNotifier();
}

String _$machineNotifierHash() => r'd6201e52ec4321575f1bef4169a6c07302b814bb';

/// Riverpod AsyncNotifier for Machine CRUD.
/// Generated provider name: machineNotifierProvider.
/// (Named MachineNotifier to avoid collision with MachineRepository class.)

abstract class _$MachineNotifier extends $AsyncNotifier<List<Machine>> {
  FutureOr<List<Machine>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Machine>>, List<Machine>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Machine>>, List<Machine>>,
              AsyncValue<List<Machine>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
