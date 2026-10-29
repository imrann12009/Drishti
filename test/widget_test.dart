import 'package:flutter_test/flutter_test.dart';

import 'package:drishti/app.dart';

void main() {
  testWidgets('shows onboarding safety message', (tester) async {
    await tester.pumpWidget(const DrishtiApp());

    expect(find.text('DRISHTI আপনার পকেট ন্যাভিগেটর'), findsOneWidget);
    expect(find.text('পরবর্তী'), findsOneWidget);

    await tester.tap(find.text('পরবর্তী'));
    await tester.pumpAndSettle();
    expect(find.text('ডেমো মোডে আগে অনুশীলন করুন'), findsOneWidget);

    await tester.tap(find.text('পরবর্তী'));
    await tester.pumpAndSettle();
    expect(find.text('আপনার নিরাপত্তাই প্রথম'), findsOneWidget);
  });
}
