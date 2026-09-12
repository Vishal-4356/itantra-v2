import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:itantra_app/core/ai/sherpa_ai_isolate_manager.dart';
import 'package:itantra_app/core/network/ad_hoc_network_manager.dart';
import 'package:itantra_app/core/protocol/packet_encoder.dart';
import 'package:itantra_app/core/protocol/xor_fec_engine.dart';
import 'package:itantra_app/core/receiver/receiver_pipeline.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('iTantra End-to-End Multilingual Transceiver Tests', () {
    late SherpaAiIsolateManager aiManager;
    late AdHocNetworkManager networkManager;
    late ReceiverPipeline receiverPipeline;

    setUp(() async {
      aiManager = SherpaAiIsolateManager();
      await aiManager.initialize({});

      networkManager = AdHocNetworkManager();
      receiverPipeline = ReceiverPipeline(aiManager: aiManager);
      await receiverPipeline.initialize();
    });

    tearDown(() {
      networkManager.dispose();
      receiverPipeline.dispose();
      aiManager.dispose();
    });

    test('Full Transceiver Loop: Speech PCM -> AI Isolate -> 32-bit Mode 1 Packet -> FEC Recovery -> Hindi Synthesis (<800ms)', () async {
      final tStart = DateTime.now().millisecondsSinceEpoch;

      // 1. Phone B sets target language to Hindi
      await receiverPipeline.setTargetLanguage('hi');

      final speechProcessedCompleter = Completer<SpeechProcessedResultEvent>();
      final subAi = aiManager.events.listen((event) {
        if (event is SpeechProcessedResultEvent) {
          if (!speechProcessedCompleter.isCompleted) {
            speechProcessedCompleter.complete(event);
          }
        }
      });

      // 2. User A speaks (Simulate PCM 16kHz mono, 0.5s audio)
      final dummyPcm = Int16List(8000);
      for (int i = 0; i < dummyPcm.length; i++) {
        dummyPcm[i] = (16000 * (i % 2 == 0 ? 1 : -1)).toInt();
      }

      aiManager.processAudioPcm(
        pcmData: dummyPcm,
        langId: 0, // User A is speaking in English
        sequence: 42,
        forcedIntentId: 0,
      );

      final processed = await speechProcessedCompleter.future.timeout(const Duration(seconds: 5));
      expect(processed.packet.mode, equals(PacketMode.semanticMode1));
      expect(processed.intentId, equals(0)); // Medical Emergency Intent
      expect(processed.packet.isEmergency, isTrue);

      // 3. User A encodes into 32-bit Mode 1 binary payload and generates XOR-FEC block
      final rawMode1Bytes = PacketEncoder.encodeMode1(
        langId: processed.packet.langId,
        intentId: processed.packet.intentId,
        priority: processed.packet.priority,
        sequence: processed.packet.sequence,
      );
      expect(rawMode1Bytes.length, equals(4)); // Exactly 4 bytes (32-bit payload)

      final fecEngine = XorFecEngine(k: 1);
      final fecFrames = fecEngine.encodeBlock([rawMode1Bytes]);
      expect(fecFrames.length, equals(2)); // 1 data + 1 parity

      // 4. Simulate air transmission with packet loss:
      // Drop data frame and provide only parity frame to Phone B!
      final parityOnlyFrames = [fecFrames[1]]; // Data frame lost in transit
      final recoveredBlock = XorFecEngine.tryReconstructBlock(
        k: 1,
        receivedFrames: parityOnlyFrames,
      );
      expect(recoveredBlock, isNotNull);
      expect(recoveredBlock![0], equals(rawMode1Bytes)); // Reconstructed!

      // 5. Phone B decodes packet and executes synthesis in Hindi
      final decodedPacket = PacketEncoder.decode(recoveredBlock[0]!);
      expect(decodedPacket.intentId, equals(0));

      final receiveEvent = await receiverPipeline.processIncomingPacket(decodedPacket);
      final tEnd = DateTime.now().millisecondsSinceEpoch;
      final totalE2eLatency = tEnd - tStart;

      expect(receiveEvent.targetLang, equals('hi'));
      expect(receiveEvent.isEmergency, isTrue);
      expect(receiveEvent.localizedText, contains('चिकित्सा'));
      expect(receiveEvent.endToEndLatencyMs, lessThan(800)); // Strict constraint < 800ms!
      expect(totalE2eLatency, lessThan(800));

      await subAi.cancel();
    });
  });
}
