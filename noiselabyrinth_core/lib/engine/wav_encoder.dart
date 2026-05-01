import 'dart:typed_data';

/// Utility class for encoding audio to WAV format.
class WavEncoder {
  /// Encodes stereo audio samples to PCM16 WAV format.
  ///
  /// Returns a [Uint8List] containing the complete WAV file bytes.
  /// Throws [ArgumentError] if left and right channels have different lengths.
  static Uint8List encodePcm16Stereo({
    required Float32List left,
    required Float32List right,
    required int sampleRate,
  }) {
    if (left.length != right.length) {
      throw ArgumentError('left and right channels must have equal length.');
    }

    final dataSize = left.length * 4;
    final buffer = ByteData(44 + dataSize);

    _writeAscii(buffer, 0, 'RIFF');
    buffer.setUint32(4, 36 + dataSize, Endian.little);
    _writeAscii(buffer, 8, 'WAVE');
    _writeAscii(buffer, 12, 'fmt ');
    buffer
      ..setUint32(16, 16, Endian.little) // PCM chunk size
      ..setUint16(20, 1, Endian.little) // PCM format
      ..setUint16(22, 2, Endian.little) // Stereo
      ..setUint32(24, sampleRate, Endian.little)
      ..setUint32(28, sampleRate * 4, Endian.little) // Byte rate
      ..setUint16(32, 4, Endian.little) // Block align
      ..setUint16(34, 16, Endian.little); // Bits per sample
    _writeAscii(buffer, 36, 'data');
    buffer.setUint32(40, dataSize, Endian.little);

    var offset = 44;
    for (var i = 0; i < left.length; i++) {
      final leftScaled = (left[i].clamp(-1.0, 1.0) * 32767.0).round();
      final rightScaled = (right[i].clamp(-1.0, 1.0) * 32767.0).round();
      buffer
        ..setInt16(offset, leftScaled, Endian.little)
        ..setInt16(offset + 2, rightScaled, Endian.little);
      offset += 4;
    }

    return buffer.buffer.asUint8List();
  }

  /// Writes an ASCII string to a ByteData buffer at the specified offset.
  static void _writeAscii(ByteData buffer, int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      buffer.setUint8(offset + i, text.codeUnitAt(i));
    }
  }
}
