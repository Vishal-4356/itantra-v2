import 'dart:typed_data';

/// High-performance CRC32 calculator using IEEE 802.3 polynomial (0xEDB88320)
class Crc32 {
  static final Uint32List _table = _generateTable();

  static Uint32List _generateTable() {
    final table = Uint32List(256);
    const polynomial = 0xEDB88320;
    for (int i = 0; i < 256; i++) {
      int c = i;
      for (int j = 0; j < 8; j++) {
        if ((c & 1) != 0) {
          c = polynomial ^ ((c >> 1) & 0x7FFFFFFF);
        } else {
          c = (c >> 1) & 0x7FFFFFFF;
        }
      }
      table[i] = c;
    }
    return table;
  }

  /// Calculates CRC32 checksum over the provided byte buffer
  static int compute(List<int> bytes, [int offset = 0, int? length]) {
    final len = length ?? (bytes.length - offset);
    int crc = 0xFFFFFFFF;
    for (int i = offset; i < offset + len; i++) {
      final index = (crc ^ bytes[i]) & 0xFF;
      crc = _table[index] ^ ((crc >> 8) & 0x00FFFFFF);
    }
    return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }
}
