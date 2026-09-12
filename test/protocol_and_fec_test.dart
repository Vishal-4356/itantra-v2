import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:itantra_app/core/protocol/crc32.dart';
import 'package:itantra_app/core/protocol/packet_encoder.dart';
import 'package:itantra_app/core/protocol/xor_fec_engine.dart';

void main() {
  group('CRC32 Engine Tests', () {
    test('Standard CRC32 check on known string', () {
      final data = '123456789'.codeUnits;
      final crc = Crc32.compute(data);
      // Standard CRC32 of "123456789" is 0xCBF43926
      expect(crc, equals(0xCBF43926));
    });
  });

  group('PacketEncoder Tests', () {
    test('Mode 1 (Semantic 32-bit): Strictly 4 bytes roundtrip', () {
      // Encode an emergency medical intent (Intent 0, Lang 1 Hi, Emergency Priority 2, Seq 7)
      final encoded = PacketEncoder.encodeMode1(
        langId: 1, // Hindi
        intentId: 0, // Medical Emergency
        priority: PacketPriority.emergency,
        sequence: 7,
      );

      expect(encoded.length, equals(4)); // Strictly 32-bit (4-byte) Payload!
      expect(encoded[0], equals(0x01)); // Mode 1 Header

      final decoded = PacketEncoder.decode(encoded);
      expect(decoded.mode, equals(PacketMode.semanticMode1));
      expect(decoded.langId, equals(1));
      expect(decoded.intentId, equals(0));
      expect(decoded.priority, equals(PacketPriority.emergency));
      expect(decoded.sequence, equals(7));
      expect(decoded.isEmergency, isTrue);
    });

    test('Mode 1 boundary values: Max Intent ID 4095, Lang ID 15', () {
      final encoded = PacketEncoder.encodeMode1(
        langId: 15,
        intentId: 4095,
        priority: PacketPriority.sosCritical,
        sequence: 63,
      );

      expect(encoded.length, equals(4));
      final decoded = PacketEncoder.decode(encoded);
      expect(decoded.langId, equals(15));
      expect(decoded.intentId, equals(4095));
      expect(decoded.priority, equals(PacketPriority.sosCritical));
      expect(decoded.sequence, equals(63));
    });

    test('Mode 2 (Raw Text MessagePack): Roundtrip with CRC32 verification', () {
      const customText = 'Critical alert: Bridge collapsed at waypoint Alpha!';
      final encoded = PacketEncoder.encodeMode2(
        langId: 0,
        text: customText,
        priority: PacketPriority.high,
        sequence: 12,
      );

      expect(encoded[0], equals(0x02)); // Mode 2 Header

      final decoded = PacketEncoder.decode(encoded);
      expect(decoded.mode, equals(PacketMode.rawTextMode2));
      expect(decoded.langId, equals(0));
      expect(decoded.text, equals(customText));
      expect(decoded.priority, equals(PacketPriority.high));
      expect(decoded.sequence, equals(12));
    });

    test('Mode 2 corrupt CRC detection', () {
      final encoded = PacketEncoder.encodeMode2(
        langId: 0,
        text: 'Hello world',
        priority: PacketPriority.normal,
      );

      // Corrupt payload byte
      encoded[5] ^= 0xFF;

      expect(() => PacketEncoder.decode(encoded), throwsA(isA<FormatException>()));
    });
  });

  group('XorFecEngine Tests', () {
    test('Systematic block encoding generates K data frames + 1 parity frame', () {
      final engine = XorFecEngine(k: 4);

      final p0 = PacketEncoder.encodeMode1(langId: 0, intentId: 1, priority: PacketPriority.normal);
      final p1 = PacketEncoder.encodeMode1(langId: 0, intentId: 2, priority: PacketPriority.normal);
      final p2 = PacketEncoder.encodeMode1(langId: 0, intentId: 3, priority: PacketPriority.high);
      final p3 = PacketEncoder.encodeMode1(langId: 0, intentId: 9, priority: PacketPriority.sosCritical);

      final frames = engine.encodeBlock([p0, p1, p2, p3]);
      expect(frames.length, equals(5)); // 4 data + 1 parity
      expect(frames.last.isParity, isTrue);
      expect(frames.last.index, equals(4));
    });

    test('Zero loss: Perfect reconstruction without using parity', () {
      final engine = XorFecEngine(k: 3);
      final p0 = Uint8List.fromList([10, 20, 30, 40]);
      final p1 = Uint8List.fromList([11, 21, 31, 41]);
      final p2 = Uint8List.fromList([12, 22, 32, 42]);

      final frames = engine.encodeBlock([p0, p1, p2]);
      final receivedFrames = [frames[0], frames[1], frames[2]]; // No parity needed

      final reconstructed = XorFecEngine.tryReconstructBlock(
        k: 3,
        receivedFrames: receivedFrames,
      );

      expect(reconstructed, isNotNull);
      expect(reconstructed![0], equals(p0));
      expect(reconstructed[1], equals(p1));
      expect(reconstructed[2], equals(p2));
    });

    test('Packet Erasure Recovery: Single lost packet is 100% mathematically recovered via parity', () {
      final engine = XorFecEngine(k: 4);

      final d0 = Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]);
      final d1 = Uint8List.fromList([0xCA, 0xFE, 0xBA, 0xBE]);
      final d2 = Uint8List.fromList([0x01, 0x02, 0x03, 0x04]);
      final d3 = Uint8List.fromList([0x55, 0xAA, 0x55, 0xAA]);

      final frames = engine.encodeBlock([d0, d1, d2, d3]);
      final parityFrame = frames[4];

      // Simulate network dropping packet d1 (index 1)
      final receivedFrames = [frames[0], frames[2], frames[3], parityFrame];

      final reconstructed = XorFecEngine.tryReconstructBlock(
        k: 4,
        receivedFrames: receivedFrames,
      );

      expect(reconstructed, isNotNull);
      expect(reconstructed!.containsKey(1), isTrue);
      expect(reconstructed[1], equals(d1)); // d1 reconstructed with 0 retransmissions!
      expect(reconstructed[0], equals(d0));
      expect(reconstructed[2], equals(d2));
      expect(reconstructed[3], equals(d3));
    });

    test('FEC Frame binary serialization roundtrip', () {
      final frame = FecFrame(
        blockId: 42,
        index: 2,
        isParity: false,
        k: 4,
        payload: Uint8List.fromList([1, 2, 3, 4, 5]),
      );

      final bytes = frame.toBytes();
      final decodedFrame = FecFrame.fromBytes(bytes);

      expect(decodedFrame.blockId, equals(42));
      expect(decodedFrame.index, equals(2));
      expect(decodedFrame.isParity, isFalse);
      expect(decodedFrame.k, equals(4));
      expect(decodedFrame.payload, equals(Uint8List.fromList([1, 2, 3, 4, 5])));
    });
  });
}
