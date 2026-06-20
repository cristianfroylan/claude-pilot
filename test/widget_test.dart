import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claude_pilot/app.dart';
import 'package:claude_pilot/core/models/machine.dart';
import 'package:claude_pilot/features/machines/providers/machines_provider.dart';

class _FakeMachineNotifier extends MachineNotifier {
  @override
  Future<List<Machine>> build() async => [];
}

void main() {
  testWidgets('App boots to Machine List screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          machineProvider.overrideWith(_FakeMachineNotifier.new),
        ],
        child: const ClaudePilotApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Machines'), findsOneWidget);
    expect(find.text('No machines yet'), findsOneWidget);
  });
}
