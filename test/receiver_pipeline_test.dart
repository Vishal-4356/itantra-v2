import 'package:flutter_test/flutter_test.dart';
import 'package:itantra_app/core/ai/sherpa_ai_isolate_manager.dart';
import 'package:itantra_app/core/protocol/packet_encoder.dart';
import 'package:itantra_app/core/receiver/receiver_pipeline.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReceiverPipeline Tests', () {
    late SherpaAiIsolateManager aiManager;
    late ReceiverPipeline receiver;

    setUp(() async {
      aiManager = SherpaAiIsolateManager();
      receiver = ReceiverPipeline(aiManager: aiManager);
      await receiver.initialize();
    });

    tearDown(() {
      receiver.dispose();
      aiManager.dispose();
    });

    test('Mode 1 Packet resolves localized Hindi template with sub-800ms latency', () async {
      await receiver.setTargetLanguage('hi');

      final packet = TransceiverPacket.mode1(
        langId: 0, // English speaker
        intentId: 0, // Medical Emergency
        priority: PacketPriority.emergency,
        sequence: 1,
      );

      final event = await receiver.processIncomingPacket(packet);

      expect(event.targetLang, equals('hi'));
      expect(event.isEmergency, isTrue);
      expect(event.localizedText, contains('चिकित्सा'));
      expect(event.endToEndLatencyMs, lessThan(800)); // Strict latency constraint!
    });

    test('Mode 2 Packet translates custom text and executes synthesis', () async {
      await receiver.setTargetLanguage('en');

      final packet = TransceiverPacket.mode2(
        langId: 0,
        text: 'Danger ahead stay in bunker',
        priority: PacketPriority.high,
        sequence: 2,
      );

      final event = await receiver.processIncomingPacket(packet);

      expect(event.targetLang, equals('en'));
      expect(event.localizedText, contains('Danger'));
      expect(event.endToEndLatencyMs, lessThan(800));
    });
  });
}
