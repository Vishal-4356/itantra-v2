import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itantra_app/main.dart';

void main() {
  testWidgets('iTantra Neumorphic UI renders title, language selector, PTT button, and intent chips', (WidgetTester tester) async {
    await tester.pumpWidget(const ITantraApp());
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Title & SOS
    expect(find.text('iTANTRA'), findsOneWidget);
    expect(find.text('SOS'), findsOneWidget);

    // Verify Language Dropdown
    expect(find.text('हिन्दी (Hindi)'), findsOneWidget);

    // Verify Push-To-Talk Hero Button
    expect(find.text('HOLD TO TALK'), findsOneWidget);
    expect(find.byIcon(Icons.mic_none_outlined), findsOneWidget);

    // Verify Neumorphic Action Chips
    expect(find.text('Auto'), findsOneWidget);
    expect(find.text('Medic'), findsOneWidget);
    expect(find.text('Fire'), findsOneWidget);

    // Test Emergency SOS button tap
    await tester.tap(find.text('SOS'));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Emergency message rendered in sunken feed slot
    expect(find.text('⚠️ SOS DISTRESS SENT'), findsWidgets);
  });
}
