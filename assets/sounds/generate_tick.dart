import 'dart:io';
import 'dart:typed_data';

void main() {
  // Generate simple tick sound (short high-pitched click)
  // This is a minimal WAV file generator for a tick sound
  
  final sampleRate = 44100;
  final duration = 0.05; // 50ms
  final frequency = 2000; // 2kHz for sharp tick
  
  final samples = <int>[];
  for (var i = 0; i < sampleRate * duration; i++) {
    final t = i / sampleRate;
    // Envelope: quick attack, exponential decay
    final envelope = (1 - t / duration).clamp(0, 1);
    final value = (sin(2 * 3.14159 * frequency * t) * envelope * 32767).toInt();
    samples.add(value.clamp(-32768, 32767));
  }
  
  // Write WAV file
  final file = File('assets/sounds/tick.wav');
  final buffer = BytesBuilder();
  
  // RIFF header
  buffer.add([0x52, 0x49, 0x46, 0x46]); // "RIFF"
  buffer.add(_uint32(36 + samples.length * 2)); // File size - 8
  buffer.add([0x57, 0x41, 0x56, 0x45]); // "WAVE"
  
  // fmt chunk
  buffer.add([0x66, 0x6d, 0x74, 0x20]); // "fmt "
  buffer.add(_uint32(16)); // Chunk size
  buffer.add(_uint16(1)); // Audio format (PCM)
  buffer.add(_uint16(1)); // Number of channels (mono)
  buffer.add(_uint32(sampleRate)); // Sample rate
  buffer.add(_uint32(sampleRate * 2)); // Byte rate
  buffer.add(_uint16(2)); // Block align
  buffer.add(_uint16(16)); // Bits per sample
  
  // data chunk
  buffer.add([0x64, 0x61, 0x74, 0x61]); // "data"
  buffer.add(_uint32(samples.length * 2)); // Data size
  for (var sample in samples) {
    buffer.add(_uint16(sample + 32768)); // Convert to unsigned
  }
  
  file.writeAsBytesSync(buffer.toBytes());
  print('Generated tick.wav');
}

Uint8List _uint32(int value) {
  return Uint8List.fromList([
    value & 0xFF,
    (value >> 8) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 24) & 0xFF,
  ]);
}

Uint8List _uint16(int value) {
  return Uint8List.fromList([
    value & 0xFF,
    (value >> 8) & 0xFF,
  ]);
}

double sin(double x) {
  // Simple Taylor series approximation
  x = x % (2 * 3.14159);
  if (x < 0) x += 2 * 3.14159;
  return x - (x * x * x) / 6 + (x * x * x * x * x) / 120;
}
