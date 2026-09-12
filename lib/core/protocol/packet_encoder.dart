import 'dart:typed_data';
import 'package:msgpack_dart/msgpack_dart.dart' as msgpack;
import 'crc32.dart';

enum PacketMode {
  semanticMode1,
  rawTextMode2,
  rawAudioMode3, // Raw WAV audio bytes — real PTT voice
}

enum PacketPriority {
  normal(0),
  high(1),
  emergency(2),
  sosCritical(3);

  final int value;
  const PacketPriority(this.value);

  static PacketPriority fromValue(int val) {
    return PacketPriority.values.firstWhere(
      (p) => p.value == val,
      orElse: () => PacketPriority.normal,
    );
  }
}

class TransceiverPacket {
  final PacketMode mode;
  final int langId;
  final int intentId; // 12-bit (0-4095) for Mode 1
  final PacketPriority priority;
  final int sequence; // 6-bit (0-63)
  final String text; // For Mode 2
  final int timestamp;

  TransceiverPacket.mode1({
    required this.langId,
    required this.intentId,
    required this.priority,
    this.sequence = 0,
    int? timestamp,
  })  : mode = PacketMode.semanticMode1,
        text = '',
        timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  TransceiverPacket.mode2({
    required this.langId,
    required this.text,
    required this.priority,
    this.sequence = 0,
    int? timestamp,
  })  : mode = PacketMode.rawTextMode2,
        intentId = -1,
        timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  TransceiverPacket({
    required this.mode,
    required this.langId,
    required this.intentId,
    required this.priority,
    required this.sequence,
    required this.text,
    required this.timestamp,
  });

  bool get isEmergency =>
      priority == PacketPriority.emergency || priority == PacketPriority.sosCritical;

  @override
  String toString() {
    return 'TransceiverPacket(mode: $mode, langId: $langId, intentId: $intentId, priority: $priority, seq: $sequence, text: "$text", isEmergency: $isEmergency)';
  }
}

class PacketEncoder {
  static const int headerMode1 = 0x01; // 8-bit Header for Mode 1
  static const int headerMode2 = 0x02; // 8-bit Header for Mode 2

  /// Mode 1 (Semantic): Encodes Header (8-bit), Lang ID (4-bit), Intent ID (12-bit), Priority (2-bit), Seq (6-bit)
  /// Result is strictly a 32-bit (4-byte) Payload!
  static Uint8List encodeMode1({
    required int langId,
    required int intentId,
    required PacketPriority priority,
    int sequence = 0,
  }) {
    // Validate field ranges
    final safeLangId = langId & 0x0F; // 4-bit (0-15)
    final safeIntentId = intentId & 0x0FFF; // 12-bit (0-4095)
    final safePriority = priority.value & 0x03; // 2-bit (0-3)
    final safeSeq = sequence & 0x3F; // 6-bit (0-63)

    // Byte 0: Header (0x01)
    // Byte 1: [Lang ID: 4 bits][Intent ID high: 4 bits]
    // Byte 2: [Intent ID low: 8 bits]
    // Byte 3: [Priority: 2 bits][Sequence: 6 bits]
    final b0 = headerMode1 & 0xFF;
    final b1 = ((safeLangId << 4) | ((safeIntentId >> 8) & 0x0F)) & 0xFF;
    final b2 = safeIntentId & 0xFF;
    final b3 = ((safePriority << 6) | safeSeq) & 0xFF;

    return Uint8List.fromList([b0, b1, b2, b3]);
  }

  /// Decode 32-bit (4-byte) Mode 1 Payload
  static TransceiverPacket decodeMode1(Uint8List bytes) {
    if (bytes.length < 4) {
      throw FormatException('Mode 1 packet must be at least 4 bytes, got ${bytes.length}');
    }
    final b0 = bytes[0];
    if (b0 != headerMode1) {
      throw FormatException('Invalid Mode 1 header byte: 0x${b0.toRadixString(16)}');
    }

    final b1 = bytes[1];
    final b2 = bytes[2];
    final b3 = bytes[3];

    final langId = (b1 >> 4) & 0x0F;
    final intentId = ((b1 & 0x0F) << 8) | b2;
    final priorityVal = (b3 >> 6) & 0x03;
    final sequence = b3 & 0x3F;

    return TransceiverPacket.mode1(
      langId: langId,
      intentId: intentId,
      priority: PacketPriority.fromValue(priorityVal),
      sequence: sequence,
    );
  }

  /// Mode 2 (Raw Text): Compress custom text via MessagePack with CRC32 integrity
  static Uint8List encodeMode2({
    required int langId,
    required String text,
    required PacketPriority priority,
    int sequence = 0,
  }) {
    final payloadMap = {
      'lang': langId & 0x0F,
      'txt': text,
      'pri': priority.value,
      'seq': sequence & 0x3F,
      'ts': DateTime.now().millisecondsSinceEpoch,
    };

    final msgpackBytes = msgpack.serialize(payloadMap);
    final payloadLen = msgpackBytes.length;

    // Frame: [Header 1B][Length 2B (Big Endian)][Msgpack Payload NB][CRC32 4B]
    final buffer = BytesBuilder();
    buffer.addByte(headerMode2);
    buffer.addByte((payloadLen >> 8) & 0xFF);
    buffer.addByte(payloadLen & 0xFF);
    buffer.add(msgpackBytes);

    // Compute CRC32 over Header + Length + Payload
    final dataForCrc = buffer.toBytes();
    final crc = Crc32.compute(dataForCrc);

    buffer.addByte((crc >> 24) & 0xFF);
    buffer.addByte((crc >> 16) & 0xFF);
    buffer.addByte((crc >> 8) & 0xFF);
    buffer.addByte(crc & 0xFF);

    return buffer.toBytes();
  }

  /// Decode Mode 2 MessagePack Packet
  static TransceiverPacket decodeMode2(Uint8List bytes) {
    if (bytes.length < 7) {
      throw FormatException('Mode 2 packet too short: ${bytes.length} bytes');
    }
    if (bytes[0] != headerMode2) {
      throw FormatException('Invalid Mode 2 header: 0x${bytes[0].toRadixString(16)}');
    }

    final payloadLen = (bytes[1] << 8) | bytes[2];
    if (bytes.length < 3 + payloadLen + 4) {
      throw FormatException('Mode 2 packet truncated: expected ${3 + payloadLen + 4}, got ${bytes.length}');
    }

    // Verify CRC32
    final dataForCrc = bytes.sublist(0, 3 + payloadLen);
    final expectedCrc = Crc32.compute(dataForCrc);
    final crcOffset = 3 + payloadLen;
    final actualCrc = (bytes[crcOffset] << 24) |
        (bytes[crcOffset + 1] << 16) |
        (bytes[crcOffset + 2] << 8) |
        bytes[crcOffset + 3];

    if (expectedCrc != actualCrc) {
      throw FormatException('CRC32 mismatch in Mode 2 packet: expected $expectedCrc, got $actualCrc');
    }

    final msgpackData = bytes.sublist(3, 3 + payloadLen);
    final deserialized = msgpack.deserialize(msgpackData) as Map;

    return TransceiverPacket(
      mode: PacketMode.rawTextMode2,
      langId: deserialized['lang'] as int? ?? 0,
      intentId: -1,
      priority: PacketPriority.fromValue(deserialized['pri'] as int? ?? 0),
      sequence: deserialized['seq'] as int? ?? 0,
      text: deserialized['txt'] as String? ?? '',
      timestamp: deserialized['ts'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Universal Packet Decoder: Automatically detects Mode 1 (32-bit) or Mode 2 (MessagePack)
  static TransceiverPacket decode(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw FormatException('Cannot decode empty packet buffer');
    }
    final header = bytes[0];
    if (header == headerMode1) {
      return decodeMode1(bytes);
    } else if (header == headerMode2) {
      return decodeMode2(bytes);
    } else {
      throw FormatException('Unknown packet header: 0x${header.toRadixString(16)}');
    }
  }
}
