import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itantra_app/main.dart';

void main() {
  testWidgets('iTantra UI renders PTT button, language selector, and telemetry overlay', (WidgetTester tester) async {
    await tester.pumpWidget(const ITantraApp());
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Title & Badges
    expect(find.text('iTANTRA'), findsOneWidget);
    expect(find.text('EDGE TRANSCEIVER'), findsOneWidget);
    expect(find.text('RECEIVER TARGET:'), findsOneWidget);

    // Verify Language Dropdown
    expect(find.text('हिन्दी (Hindi)'), findsOneWidget);

    // Verify Telemetry Overlay
    expect(find.text('LIVE TELEMETRY OVERLAY'), findsOneWidget);
    expect(find.text('VAD'), findsOneWidget);
    expect(find.text('STT'), findsOneWidget);
    expect(find.text('NLU'), findsOneWidget);
    expect(find.text('AIR/FEC'), findsOneWidget);
    expect(find.text('TTS'), findsOneWidget);

    // Verify Push-To-Talk
    expect(find.text('HOLD TO TALK (PTT)'), findsOneWidget);
    expect(find.byIcon(Icons.mic_none), findsOneWidget);

    // Test PTT Touch down
    await tester.press(find.byType(GestureDetector).last);
    await tester.pump();

    // Test Emergency SOS button
    expect(find.text('SOS'), findsOneWidget);
    await tester.tap(find.text('SOS'));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Emergency message rendered in log
    expect(find.byIcon(Icons.warning_amber), findsWidgets);
    expect(find.text('ALARM 100% OVERRIDE'), findsWidgets);
  });
}
