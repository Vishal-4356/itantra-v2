import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:itantra_app/core/ai/sherpa_ai_isolate_manager.dart';
import 'package:itantra_app/core/protocol/packet_encoder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SherpaAiIsolateManager & NLU Tests', () {
    test('IntentClassifier correctly maps crisis keywords to Intent IDs', () {
      final res1 = IntentClassifier.classify('We have a critical medical emergency with severe bleeding');
      expect(res1.key, equals(0)); // Medical Emergency
      expect(res1.value, greaterThanOrEqualTo(0.65));
      expect(IntentClassifier.getPriorityForIntent(0), equals(PacketPriority.emergency));

      final res2 = IntentClassifier.classify('Fire outbreak in sector 4 evacuate now');
      expect(res2.key, equals(1)); // Fire Outbreak
      expect(res2.value, greaterThanOrEqualTo(0.65));

      final res3 = IntentClassifier.classify('Enemy shooter hostile threat take cover');
      expect(res3.key, equals(2)); // Hostile Threat

      final res4 = IntentClassifier.classify('Search and rescue team needed at my coordinates');
      expect(res4.key, equals(3)); // Search and Rescue
    });

    test('SherpaAiIsolateManager completes speech synthesis request', () async {
      final manager = SherpaAiIsolateManager();

      final ttsCompleter = Completer<SpeechSynthesizedResultEvent>();

      final sub = manager.events.listen((event) {
        if (event is SpeechSynthesizedResultEvent) {
          if (!ttsCompleter.isCompleted) ttsCompleter.complete(event);
        }
      });

      manager.synthesizeSpeech(
        text: 'Medical Emergency assistance needed',
        targetLang: 'en',
        requestId: 99,
      );

      final ttsResult = await ttsCompleter.future.timeout(const Duration(seconds: 5));
      expect(ttsResult.requestId, equals(99));
      expect(ttsResult.latencyMs, greaterThan(0));

      await sub.cancel();
      manager.dispose();
    });
  });
}
