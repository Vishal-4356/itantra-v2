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
      networkManager = AdHocNetworkManager();
      receiverPipeline = ReceiverPipeline(aiManager: aiManager);
      await receiverPipeline.initialize();
    });

    tearDown(() {
      networkManager.dispose();
      receiverPipeline.dispose();
      aiManager.dispose();
    });

    test('Full Transceiver Loop: 32-bit Mode 1 Packet -> FEC Recovery -> Hindi Synthesis (<800ms)', () async {
      final tStart = DateTime.now().millisecondsSinceEpoch;

      // 1. Phone B sets target language to Hindi
      await receiverPipeline.setTargetLanguage('hi');

      // 2. Encode into 32-bit Mode 1 binary payload and generate XOR-FEC block
      final rawMode1Bytes = PacketEncoder.encodeMode1(
        langId: 0,
        intentId: 0,
        priority: PacketPriority.emergency,
        sequence: 42,
      );
      expect(rawMode1Bytes.length, equals(4)); // Exactly 4 bytes (32-bit payload)

      final fecEngine = XorFecEngine(k: 1);
      final fecFrames = fecEngine.encodeBlock([rawMode1Bytes]);
      expect(fecFrames.length, equals(2)); // 1 data + 1 parity

      // 3. Simulate air transmission with packet loss:
      final parityOnlyFrames = [fecFrames[1]]; // Data frame lost in transit
      final recoveredBlock = XorFecEngine.tryReconstructBlock(
        k: 1,
        receivedFrames: parityOnlyFrames,
      );
      expect(recoveredBlock, isNotNull);
      expect(recoveredBlock![0], equals(rawMode1Bytes)); // Reconstructed!

      // 4. Phone B decodes packet and executes synthesis in Hindi
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
    });
  });
}
