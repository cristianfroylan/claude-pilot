import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../terminal/providers/ssh_session_provider.dart';
import '../models/session_tab.dart';

part 'sessions_provider.g.dart';

@Riverpod(keepAlive: true)
class Sessions extends _$Sessions {
  @override
  SessionsState build() => const SessionsState(tabs: [], activeIndex: 0);

  void openTab(String machineId) {
    final id = '${machineId}_${DateTime.now().microsecondsSinceEpoch}';
    final newTab = SessionTab(id: id, machineId: machineId);
    final tabs = [...state.tabs, newTab];
    state = SessionsState(tabs: tabs, activeIndex: tabs.length - 1);
  }

  void setActiveTab(int index) {
    state = state.copyWith(activeIndex: index);
  }

  void closeTab(int index) {
    if (index < 0 || index >= state.tabs.length) return;
    final tab = state.tabs[index];
    ref.read(sshSessionProvider(tab.machineId).notifier).closeAndDispose();
    final tabs = [...state.tabs]..removeAt(index);
    if (tabs.isEmpty) {
      state = const SessionsState(tabs: [], activeIndex: 0);
      return;
    }
    final newActive = (index > 0 ? index - 1 : 0).clamp(0, tabs.length - 1);
    state = SessionsState(tabs: tabs, activeIndex: newActive);
  }
}
