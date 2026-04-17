import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bamm/app/app.dart';

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: BammApp()));
    await tester.pump();

    expect(find.text('BAMM'), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
  });
}
