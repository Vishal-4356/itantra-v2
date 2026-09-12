import 'dart:math';
import 'dart:typed_data';

class FecFrame {
  final int blockId; // 8-bit Block Identifier
  final int index; // 0..K-1 for data, or K for parity
  final bool isParity;
  final int k; // Number of data packets in this block
  final Uint8List payload;

  FecFrame({
    required this.blockId,
    required this.index,
    required this.isParity,
    required this.k,
    required this.payload,
  });

  /// Serializes FEC frame into binary buffer:
  /// [Magic 0xFC][BlockId 1B][Index 1B][Flags: isParity (1 bit) + K (7 bits)][Length 2B][Payload NB]
  Uint8List toBytes() {
    final buffer = BytesBuilder();
    buffer.addByte(0xFC); // FEC frame magic byte
    buffer.addByte(blockId & 0xFF);
    buffer.addByte(index & 0xFF);
    final flags = ((isParity ? 1 : 0) << 7) | (k & 0x7F);
    buffer.addByte(flags & 0xFF);
    final len = payload.length;
    buffer.addByte((len >> 8) & 0xFF);
    buffer.addByte(len & 0xFF);
    buffer.add(payload);
    return buffer.toBytes();
  }

  /// Deserializes binary buffer into FEC frame
  static FecFrame fromBytes(Uint8List bytes) {
    if (bytes.length < 6) {
      throw FormatException('FEC frame too short: ${bytes.length} bytes');
    }
    if (bytes[0] != 0xFC) {
      throw FormatException('Invalid FEC magic byte: 0x${bytes[0].toRadixString(16)}');
    }
    final blockId = bytes[1];
    final index = bytes[2];
    final flags = bytes[3];
    final isParity = ((flags >> 7) & 0x01) == 1;
    final k = flags & 0x7F;
    final len = (bytes[4] << 8) | bytes[5];
    if (bytes.length < 6 + len) {
      throw FormatException('FEC frame truncated: expected ${6 + len}, got ${bytes.length}');
    }
    final payload = bytes.sublist(6, 6 + len);

    return FecFrame(
      blockId: blockId,
      index: index,
      isParity: isParity,
      k: k,
      payload: payload,
    );
  }
}

class XorFecEngine {
  final int k; // Default block size (e.g. 4 data packets + 1 parity)
  int _currentBlockId = 0;

  XorFecEngine({this.k = 4});

  /// Encodes a list of data packets into K data frames + 1 parity frame
  List<FecFrame> encodeBlock(List<Uint8List> dataPackets) {
    if (dataPackets.isEmpty) return [];

    final blockId = _currentBlockId;
    _currentBlockId = (_currentBlockId + 1) & 0xFF;

    final actualK = dataPackets.length;
    int maxLen = 0;
    for (final p in dataPackets) {
      maxLen = max(maxLen, p.length);
    }

    // Parity accumulator
    final parityBytes = Uint8List(maxLen);
    final frames = <FecFrame>[];

    for (int i = 0; i < actualK; i++) {
      final packet = dataPackets[i];
      frames.add(FecFrame(
        blockId: blockId,
        index: i,
        isParity: false,
        k: actualK,
        payload: packet,
      ));

      // Byte-wise XOR
      for (int b = 0; b < packet.length; b++) {
        parityBytes[b] ^= packet[b];
      }
    }

    // Add Parity Frame (index = actualK)
    frames.add(FecFrame(
      blockId: blockId,
      index: actualK,
      isParity: true,
      k: actualK,
      payload: parityBytes,
    ));

    return frames;
  }

  /// Attempts to reconstruct any single lost packet in a received block
  /// Returns a map of index -> data packet payload
  static Map<int, Uint8List>? tryReconstructBlock({
    required int k,
    required List<FecFrame> receivedFrames,
  }) {
    if (receivedFrames.isEmpty) return null;

    final dataFrames = <int, Uint8List>{};
    FecFrame? parityFrame;

    for (final frame in receivedFrames) {
      if (frame.isParity) {
        parityFrame = frame;
      } else {
        dataFrames[frame.index] = frame.payload;
      }
    }

    // Case 1: All K data packets were received without any packet loss!
    if (dataFrames.length == k) {
      return dataFrames;
    }

    // Case 2: Exactly 1 data packet was lost, and parity frame is available!
    if (dataFrames.length == k - 1 && parityFrame != null) {
      // Find missing index
      int missingIndex = -1;
      for (int i = 0; i < k; i++) {
        if (!dataFrames.containsKey(i)) {
          missingIndex = i;
          break;
        }
      }

      if (missingIndex != -1) {
        // Find max length across parity and all existing frames
        int maxLen = parityFrame.payload.length;
        for (final p in dataFrames.values) {
          maxLen = max(maxLen, p.length);
        }

        final recovered = Uint8List(maxLen);

        // Start with parity bytes: recovered = P
        for (int b = 0; b < parityFrame.payload.length; b++) {
          recovered[b] = parityFrame.payload[b];
        }

        // XOR with every available data packet: recovered = P ^ (D_0 ^ D_1 ...)
        for (final entry in dataFrames.entries) {
          final p = entry.value;
          for (int b = 0; b < p.length; b++) {
            recovered[b] ^= p[b];
          }
        }

        // Trim trailing zeroes if necessary or keep raw length based on frame length
        dataFrames[missingIndex] = recovered;
        return dataFrames;
      }
    }

    // Case 3: More than 1 packet lost or no parity frame -> cannot recover
    return dataFrames;
  }
}
