import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'features/machines/screens/machine_list_screen.dart';
import 'features/machines/screens/add_edit_machine_screen.dart';
import 'features/terminal/screens/terminal_screen.dart';
import 'core/theme/app_theme.dart';

final _router = GoRouter(
  initialLocation: '/machines',
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
        GoRoute(
          path: ':id/terminal',
          builder: (context, state) => TerminalScreen(
            machineId: state.pathParameters['id']!,
          ),
        ),
      ],
    ),
  ],
);

class ClaudePilotApp extends StatelessWidget {
  const ClaudePilotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Claude Pilot',
      theme: AppTheme.darkTheme,
      routerConfig: _router,
    );
  }
}
