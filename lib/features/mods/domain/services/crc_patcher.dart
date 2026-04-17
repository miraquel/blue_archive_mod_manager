import 'dart:typed_data';

/// Result of a CRC patching operation.
class CrcPatchResult {
  final bool success;
  final List<int>? patchedData;
  final String? message;

  const CrcPatchResult({required this.success, this.patchedData, this.message});
}

/// Pure-Dart CRC32 patcher that appends 4 correction bytes to [modData]
/// so that its CRC32 matches that of [originalData].
///
/// The reflected CRC32 with init=0 and no final XOR is a linear function of
/// the input bits over GF(2).  For a 4-byte input (32 bits), this defines a
/// 32×32 matrix M such that CRC'(C) = M * C.  We precompute M⁻¹ and use it
/// to solve for the correction bytes in constant time:
///
///   delta = originalCrc XOR CRC32(modData || 0x00000000)
///   correctionWord = M⁻¹ * delta
///
/// The 4 correction bytes are then appended to modData.
class CrcPatcher {
  // ---------------------------------------------------------------------------
  // CRC32 table (standard ISO 3309 / zlib, reflected polynomial 0xEDB88320)
  // ---------------------------------------------------------------------------

  static final Uint32List _crc32Table = _generateCrc32Table();

  static Uint32List _generateCrc32Table() {
    final table = Uint32List(256);
    for (var i = 0; i < 256; i++) {
      var crc = i;
      for (var j = 0; j < 8; j++) {
        if (crc & 1 != 0) {
          crc = (crc >> 1) ^ 0xEDB88320;
        } else {
          crc >>= 1;
        }
      }
      table[i] = crc;
    }
    return table;
  }

  /// Compute CRC32 of [data] (standard zlib-compatible CRC32).
  static int computeCrc32(List<int> data) {
    var crc = 0xFFFFFFFF;
    for (final byte in data) {
      crc = _crc32Table[(crc ^ byte) & 0xFF] ^ (crc >> 8);
    }
    return crc ^ 0xFFFFFFFF;
  }

  // ---------------------------------------------------------------------------
  // Precomputed inverse matrix for CRC32 correction
  // ---------------------------------------------------------------------------

  // Column i is the 32-bit correction vector for bit i of the CRC difference.
  //
  // The forward matrix M has column j = CRC'(e_j), where CRC' is the
  // reflected CRC32 with init=0 / no final XOR and e_j is a 4-byte vector
  // with only bit j set.  This table is M⁻¹, computed via Gaussian
  // elimination, and is constant for all CRC32 computations (depends only
  // on the polynomial 0xEDB88320).
  static const List<int> _crcInverseMatrix = [
    0xdb710641, // bit 0
    0x6d930ac3, // bit 1
    0xdb261586, // bit 2
    0x6d3d2d4d, // bit 3
    0xda7a5a9a, // bit 4
    0x6f85b375, // bit 5
    0xdf0b66ea, // bit 6
    0x6567cb95, // bit 7
    0xcacf972a, // bit 8
    0x4eee2815, // bit 9
    0x9ddc502a, // bit 10
    0xe0c9a615, // bit 11
    0x1ae24a6b, // bit 12
    0x35c494d6, // bit 13
    0x6b8929ac, // bit 14
    0xd7125358, // bit 15
    0x7555a0f1, // bit 16
    0xeaab41e2, // bit 17
    0x0e278585, // bit 18
    0x1c4f0b0a, // bit 19
    0x389e1614, // bit 20
    0x713c2c28, // bit 21
    0xe2785850, // bit 22
    0x1f81b6e1, // bit 23
    0x3f036dc2, // bit 24
    0x7e06db84, // bit 25
    0xfc0db708, // bit 26
    0x236a6851, // bit 27
    0x46d4d0a2, // bit 28
    0x8da9a144, // bit 29
    0xc02244c9, // bit 30
    0x5b358fd3, // bit 31
  ];

  // ---------------------------------------------------------------------------
  // Main entry point
  // ---------------------------------------------------------------------------

  /// Patch [modData] so that its CRC32 equals that of [originalData].
  ///
  /// Returns a [CrcPatchResult] containing the (possibly modified) data.
  /// If the CRCs already match, [modData] is returned unmodified.
  static CrcPatchResult manipulateCrc({
    required List<int> originalData,
    required List<int> modData,
  }) {
    final originalCrc = computeCrc32(originalData);
    final modCrc = computeCrc32(modData);

    if (modCrc == originalCrc) {
      return CrcPatchResult(
        success: true,
        patchedData: List<int>.from(modData),
        message: 'CRC already matches, no correction needed.',
      );
    }

    // CRC of modData with 4 zero bytes appended.  The XOR with the target
    // CRC gives the "difference" the correction bytes must produce through
    // the linear CRC map.
    final modCrcPadded = _continueCrc32WithZeros(modCrc);
    final delta = originalCrc ^ modCrcPadded;

    // Multiply delta by the precomputed inverse matrix over GF(2).
    final correctionWord = _matVecMulGF2(delta);
    final correctionBytes = [
      correctionWord & 0xFF,
      (correctionWord >> 8) & 0xFF,
      (correctionWord >> 16) & 0xFF,
      (correctionWord >> 24) & 0xFF,
    ];

    final finalData = List<int>.from(modData)..addAll(correctionBytes);
    final finalCrc = computeCrc32(finalData);

    if (finalCrc == originalCrc) {
      return CrcPatchResult(
        success: true,
        patchedData: finalData,
        message: 'CRC patched successfully.',
      );
    }

    return CrcPatchResult(
      success: false,
      message:
          'CRC correction failed. '
          'Expected 0x${originalCrc.toRadixString(16).padLeft(8, '0')}, '
          'got 0x${finalCrc.toRadixString(16).padLeft(8, '0')}.',
    );
  }

  /// Continue CRC32 from a known finalized CRC value by feeding 4 zero bytes.
  static int _continueCrc32WithZeros(int finalizedCrc) {
    var crc = finalizedCrc ^ 0xFFFFFFFF; // undo finalization
    for (var i = 0; i < 4; i++) {
      crc = _crc32Table[crc & 0xFF] ^ (crc >> 8);
    }
    return crc ^ 0xFFFFFFFF; // re-finalize
  }

  /// Multiply a 32-bit vector [delta] by [_crcInverseMatrix] over GF(2).
  static int _matVecMulGF2(int delta) {
    var result = 0;
    var d = delta;
    for (var i = 0; i < 32; i++) {
      if (d & 1 != 0) {
        result ^= _crcInverseMatrix[i];
      }
      d >>= 1;
    }
    return result;
  }
}
