import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:noiselabyrinth_core/noiselabyrinth_core.dart';

/// JavaScript bindings for creating and using the lamejs MP3 encoder
@JS('window._createEncoder')
external JSObject _createEncoderJs(int sampleRate, int bitRate);

@JS('window._getLength')
external int _getArrayLengthJs(JSObject arr);

@JS('window._getElement')
external int _getArrayElementJs(JSObject arr, int index);

/// Call encode method on JS encoder object
@JS('(encoder, left, right) => encoder.encode(Array.from(left), Array.from(right))')
external JSObject _callEncode(JSObject encoder, JSObject left, JSObject right);

/// Call flush method on JS encoder object
@JS('(encoder) => encoder.flush()')
external JSObject _callFlush(JSObject encoder);

/// Wrapper for the JavaScript Mp3Encoder from lamejs
class _LameJsMp3Encoder {
  late final JSObject encoder;

  _LameJsMp3Encoder({required int sampleRate, required int bitRate}) {
    try {
      encoder = _createEncoderJs(sampleRate, bitRate);
    } catch (e) {
      throw Exception('Failed to create MP3 encoder: $e');
    }
  }

  /// Encode stereo PCM samples using the JS encoder
  Uint8List encode(Int16List left, Int16List right) {
    try {
      // Call the encode method on the JS encoder object
      final jsResult = _callEncode(encoder, left.toJS as JSObject, right.toJS as JSObject);
      return _jsArrayToUint8List(jsResult);
    } catch (e) {
      return Uint8List(0);
    }
  }

  /// Flush remaining MP3 data from the encoder
  Uint8List flush() {
    try {
      final jsResult = _callFlush(encoder);
      return _jsArrayToUint8List(jsResult);
    } catch (e) {
      return Uint8List(0);
    }
  }

  void close() {
    // No cleanup needed for JS encoder
  }
}

/// Convert JS array to Dart Uint8List
Uint8List _jsArrayToUint8List(JSObject jsArray) {
  try {
    final length = _getArrayLengthJs(jsArray);
    final result = Uint8List(length);
    for (int i = 0; i < length; i++) {
      final element = _getArrayElementJs(jsArray, i);
      if (element >= 0 && element <= 255) {
        result[i] = element;
      }
    }
    return result;
  } catch (e) {
    return Uint8List(0);
  }
}

class Mp3Renderer {
  const Mp3Renderer();

  /// Renders [config] to MP3 bytes by consuming stereo float PCM chunks.
  /// Uses lamejs (JavaScript MP3 encoder) via dart:js_interop on the web.
  Future<Uint8List> render(GenerationConfig config) async {
    final encoder = _LameJsMp3Encoder(sampleRate: config.render.sampleRate, bitRate: config.render.bitRate);
    final encoded = BytesBuilder(copy: false);

    try {
      await for (final chunk in Renderer.renderPcmChunks(config)) {
        final sampleCount = chunk.left.length;
        final left = Int16List(sampleCount);
        final right = Int16List(sampleCount);
        for (var i = 0; i < sampleCount; i++) {
          left[i] = _toPcm16(chunk.left[i]);
          right[i] = _toPcm16(chunk.right[i]);
        }
        encoded.add(encoder.encode(left, right));
      }

      encoded.add(encoder.flush());
      return encoded.takeBytes();
    } finally {
      encoder.close();
    }
  }

  int _toPcm16(double sample) {
    final clamped = sample < -1.0 ? -1.0 : (sample > 1.0 ? 1.0 : sample);
    return (clamped * 32767.0).round();
  }
}
