import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:spotiflac_android/widgets/audio_analysis_widget.dart';

void main() {
  group('audio spectrogram filter', () {
    test('keeps source rate and uses a full-range float pipeline', () {
      final filter = buildAudioSpectrogramFilter();

      expect(filter, contains('[0:a:0]aformat=sample_fmts=fltp'));
      expect(filter, contains('s=1600x800'));
      expect(filter, contains('scale=log'));
      expect(filter, contains('fscale=lin'));
      expect(filter, contains('win_func=hann'));
      expect(filter, contains('drange=120'));
      expect(filter, contains('limit=0'));
      expect(filter, isNot(contains('pan=')));
      expect(filter, isNot(contains('aresample')));
    });

    test('can render one source channel without app-specific branching', () {
      final filter = buildAudioSpectrogramFilter(channel: 1);

      expect(filter, contains('[0:a:0]pan=mono|c0=c1,'));
      expect(filter, contains('aformat=sample_fmts=fltp'));
    });

    test('processes the complete source without resampling or downmixing', () {
      final arguments = buildAudioSpectrogramArguments(
        inputPath: 'source.flac',
        outputPath: 'spectrum.rgba',
      );

      expect(arguments, containsAllInOrder(['-i', 'source.flac']));
      expect(arguments, containsAllInOrder(['-frames:v', '1']));
      expect(arguments, containsAllInOrder(['-pix_fmt', 'rgba']));
      expect(arguments, isNot(contains('-t')));
      expect(arguments, isNot(contains('-ss')));
      expect(arguments, isNot(contains('-ar')));
      expect(arguments, isNot(contains('-ac')));
    });
  });

  group('broadband spectral cutoff', () {
    const width = 200;
    const height = 800;
    const nyquist = 96000.0;

    test('ignores a narrow ultrasonic pilot above a 22 kHz music band', () {
      final rgba = _blankRgba(width, height);
      _paintFrequencyBand(
        rgba,
        width: width,
        height: height,
        maxFrequencyHz: nyquist,
        lowHz: 0,
        highHz: 22000,
        intensity: 220,
      );
      _paintFrequencyBand(
        rgba,
        width: width,
        height: height,
        maxFrequencyHz: nyquist,
        lowHz: 53880,
        highHz: 54120,
        intensity: 255,
      );

      final cutoff = estimateBroadbandSpectralCutoffHz(
        rgba: rgba,
        width: width,
        height: height,
        maxFrequencyHz: nyquist,
      );

      expect(cutoff, isNotNull);
      expect(cutoff!, inInclusiveRange(21000, 23500));
    });

    test('retains genuine broadband ultrasonic content', () {
      final rgba = _blankRgba(width, height);
      _paintFrequencyBand(
        rgba,
        width: width,
        height: height,
        maxFrequencyHz: nyquist,
        lowHz: 0,
        highHz: 48000,
        intensity: 180,
      );

      final cutoff = estimateBroadbandSpectralCutoffHz(
        rgba: rgba,
        width: width,
        height: height,
        maxFrequencyHz: nyquist,
      );

      expect(cutoff, isNotNull);
      expect(cutoff!, inInclusiveRange(47000, 49500));
    });

    test('does not report an isolated line as a broadband cutoff', () {
      final rgba = _blankRgba(width, height);
      _paintFrequencyBand(
        rgba,
        width: width,
        height: height,
        maxFrequencyHz: nyquist,
        lowHz: 53880,
        highHz: 54120,
        intensity: 255,
      );

      final cutoff = estimateBroadbandSpectralCutoffHz(
        rgba: rgba,
        width: width,
        height: height,
        maxFrequencyHz: nyquist,
      );

      expect(cutoff, isNull);
    });

    test('rejects invalid or incomplete images', () {
      expect(
        estimateBroadbandSpectralCutoffHz(
          rgba: Uint8List(3),
          width: 1,
          height: 1,
          maxFrequencyHz: nyquist,
        ),
        isNull,
      );
    });
  });
}

Uint8List _blankRgba(int width, int height) {
  final rgba = Uint8List(width * height * 4);
  for (var offset = 3; offset < rgba.length; offset += 4) {
    rgba[offset] = 255;
  }
  return rgba;
}

void _paintFrequencyBand(
  Uint8List rgba, {
  required int width,
  required int height,
  required double maxFrequencyHz,
  required double lowHz,
  required double highHz,
  required int intensity,
}) {
  for (var y = 0; y < height; y++) {
    final frequency = (height - y - 0.5) / height * maxFrequencyHz;
    if (frequency < lowHz || frequency > highHz) continue;
    for (var x = 0; x < width; x++) {
      final offset = (y * width + x) * 4;
      rgba[offset] = intensity;
      rgba[offset + 1] = intensity;
      rgba[offset + 2] = intensity;
    }
  }
}
