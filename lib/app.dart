import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/auth/providers/biometric_auth_provider.dart';
import 'features/auth/screens/lock_screen.dart';
import 'features/machines/screens/machine_list_screen.dart';
import 'features/machines/screens/add_edit_machine_screen.dart';
import 'features/sessions/screens/sessions_screen.dart';
import 'core/theme/app_theme.dart';

final _router = GoRouter(
  initialLocation: '/sessions',
  routes: [
    GoRoute(
      path: '/machines',
      builder: (context, state) => const MachineListScreen(),
      routes: [
        GoRoute(
          path: 'add',
          builder: (context, state) => const AddEditMachineScreen(),
        ),
        GoRoute(
          path: ':id/edit',
          builder: (context, state) => AddEditMachineScreen(
            machineId: state.pathParameters['id'],
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/sessions',
      builder: (context, state) {
        final newMachineId = state.uri.queryParameters['newMachineId'];
        return SessionsScreen(initialMachineId: newMachineId);
      },
    ),
  ],
);

const kLockTimeout = Duration(minutes: 10);

class ClaudePilotApp extends ConsumerStatefulWidget {
  const ClaudePilotApp({super.key});

  @override
  ConsumerState<ClaudePilotApp> createState() => _ClaudePilotAppState();
}

class _ClaudePilotAppState extends ConsumerState<ClaudePilotApp> {
  late final AppLifecycleListener _lifecycleListener;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onPause: () => _pausedAt = DateTime.now(),
      onResume: () {
        final paused = _pausedAt;
        if (paused != null &&
            DateTime.now().difference(paused) > kLockTimeout) {
          ref.read(biometricAuthProvider.notifier).setAuthenticated(false);
        }
        _pausedAt = null;
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ref.watch(biometricAuthProvider);
    return isAuthenticated
        ? MaterialApp.router(
            title: 'Claude Pilot',
            theme: AppTheme.darkTheme,
            routerConfig: _router,
          )
        : MaterialApp(
            title: 'Claude Pilot',
            theme: AppTheme.darkTheme,
            home: const LockScreen(),
          );
  }
}
