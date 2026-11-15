import 'package:flutter_test/flutter_test.dart';
import 'package:opensic/main.dart';

void main() {
  testWidgets('shows the Opensic home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const OpensicApp());
    expect(find.text('opensic'), findsOneWidget);
    await tester.tap(find.text('Discover'));
    await tester.pump();
    expect(find.text('Trending on Audius'), findsOneWidget);
    expect(find.text('Search songs or artists'), findsOneWidget);
  });
}
