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
      expect(res1.value, greaterThanOrEqualTo(0.70));
      expect(IntentClassifier.getPriorityForIntent(0), equals(PacketPriority.emergency));

      final res2 = IntentClassifier.classify('Fire outbreak in sector 4 evacuate now');
      expect(res2.key, equals(1)); // Fire Outbreak
      expect(res2.value, greaterThanOrEqualTo(0.70));

      final res3 = IntentClassifier.classify('Enemy shooter hostile threat take cover');
      expect(res3.key, equals(2)); // Hostile Threat

      final res4 = IntentClassifier.classify('Search and rescue team needed at my coordinates');
      expect(res4.key, equals(3)); // Search and Rescue
    });

    test('WAV Header generator produces valid RIFF WAVE buffer', () {
      final dummyPcm = Uint8List(1000);
      final wav = createWavBytes(dummyPcm, 22050, 1);
      
      expect(wav.length, equals(1044)); // 44 bytes header + 1000 bytes PCM
      expect(String.fromCharCodes(wav.sublist(0, 4)), equals('RIFF'));
      expect(String.fromCharCodes(wav.sublist(8, 12)), equals('WAVE'));
      expect(String.fromCharCodes(wav.sublist(12, 16)), equals('fmt '));
      expect(String.fromCharCodes(wav.sublist(36, 40)), equals('data'));
    });

    test('SherpaAiIsolateManager spawns isolate and completes full inference cycle', () async {
      final manager = SherpaAiIsolateManager();
      await manager.initialize({
        'vad': 'assets/models/vad/silero_vad.onnx',
        'stt': 'assets/models/stt/encoder.int8.onnx',
      });

      expect(manager.isReady, isTrue);

      final pcmCompleter = Completer<SpeechProcessedResultEvent>();
      final ttsCompleter = Completer<SpeechSynthesizedResultEvent>();

      final sub = manager.events.listen((event) {
        if (event is SpeechProcessedResultEvent) {
          if (!pcmCompleter.isCompleted) pcmCompleter.complete(event);
        } else if (event is SpeechSynthesizedResultEvent) {
          if (!ttsCompleter.isCompleted) ttsCompleter.complete(event);
        }
      });

      // Send simulated PCM audio (16kHz 16-bit, 0.5s = 8000 samples)
      final dummySamples = Int16List(8000);
      for (int i = 0; i < dummySamples.length; i++) {
        dummySamples[i] = (15000 * (i % 2 == 0 ? 1 : -1)).toInt();
      }

      manager.processAudioPcm(
        pcmData: dummySamples,
        langId: 1, // Hindi
        sequence: 1,
        forcedIntentId: 0,
      );

      final processedResult = await pcmCompleter.future.timeout(const Duration(seconds: 5));
      expect(processedResult.packet, isNotNull);
      expect(processedResult.intentId, equals(0)); // Medical intent
      expect(processedResult.packet.mode, equals(PacketMode.semanticMode1));
      expect(processedResult.totalLatencyMs, greaterThan(0));

      // Synthesize TTS
      manager.synthesizeSpeech(
        text: 'Medical Emergency assistance needed',
        langCode: 'en',
        requestId: 99,
      );

      final ttsResult = await ttsCompleter.future.timeout(const Duration(seconds: 5));
      expect(ttsResult.requestId, equals(99));
      expect(ttsResult.audioWavBytes.length, greaterThan(100));
      expect(ttsResult.synthesisLatencyMs, greaterThan(0));

      await sub.cancel();
      manager.dispose();
    });
  });
}
