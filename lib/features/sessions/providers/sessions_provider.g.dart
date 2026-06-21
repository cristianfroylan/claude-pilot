// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sessions_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(Sessions)
final sessionsProvider = SessionsProvider._();

final class SessionsProvider
    extends $NotifierProvider<Sessions, SessionsState> {
  SessionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionsHash();

  @$internal
  @override
  Sessions create() => Sessions();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionsState>(value),
    );
  }
}

String _$sessionsHash() => r'c120d7f9eaebe590bb6d3f64543f10fc9d43e7e1';

abstract class _$Sessions extends $Notifier<SessionsState> {
  SessionsState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<SessionsState, SessionsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SessionsState, SessionsState>,
              SessionsState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
