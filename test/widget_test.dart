import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claude_pilot/app.dart';

void main() {
  testWidgets('App boots to Machine List screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: ClaudePilotApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Machines'), findsOneWidget);
    expect(find.text('No machines yet'), findsOneWidget);
  });
}
