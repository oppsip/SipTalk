import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:siptalk/main.dart';
import 'package:siptalk/sip/sip_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('SipTalk home renders core controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SipTalkApp(controller: SipControllerStub()));

    expect(find.text('SipTalk'), findsOneWidget);
    expect(find.text('Destination'), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);
    expect(find.text('Call'), findsOneWidget);
    expect(find.text('Hang up'), findsOneWidget);
  });

  testWidgets('register button emits registration event', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SipTalkApp(controller: SipControllerStub()));

    await tester.tap(find.text('Register'));
    await tester.pump();

    expect(find.text('Account default: registering'), findsOneWidget);
  });
}
