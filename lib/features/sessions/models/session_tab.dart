/// Identifies one open tab entry in the sessions screen.
class SessionTab {
  final String id; // unique per tab-open event: '${machineId}_${microsecondsSinceEpoch}'
  final String machineId; // references Machine.id

  const SessionTab({required this.id, required this.machineId});
}

/// Full state owned by SessionsNotifier.
class SessionsState {
  final List<SessionTab> tabs;
  final int activeIndex;

  const SessionsState({required this.tabs, required this.activeIndex});

  SessionsState copyWith({List<SessionTab>? tabs, int? activeIndex}) =>
      SessionsState(
        tabs: tabs ?? this.tabs,
        activeIndex: activeIndex ?? this.activeIndex,
      );
}
