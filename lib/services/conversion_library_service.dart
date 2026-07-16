import 'package:spotiflac_android/providers/download_history_provider.dart';
import 'package:spotiflac_android/services/history_database.dart';
import 'package:spotiflac_android/utils/audio_conversion_utils.dart';

class ConversionLibraryService {
  const ConversionLibraryService._();

  static Future<void> persistHistoryConversion({
    required DownloadHistoryItem source,
    required String newFilePath,
    required String newQuality,
    required String targetFormat,
    required String bitrate,
    required int? bitDepth,
    required int? sampleRate,
    required bool keepOriginal,
    String? newSafFileName,
  }) async {
    final convertedBitrate = convertedAudioBitrateKbps(
      targetFormat: targetFormat,
      bitrate: bitrate,
    );
    final isLossless = isLosslessConversionTarget(targetFormat);

    if (!keepOriginal) {
      await HistoryDatabase.instance.updateFilePath(
        source.id,
        newFilePath,
        newSafFileName: newSafFileName,
        newQuality: newQuality,
        newFormat: normalizedConvertedAudioFormat(targetFormat),
        newBitrate: convertedBitrate,
        newBitDepth: bitDepth,
        newSampleRate: sampleRate,
        clearAudioSpecs: !isLossless,
      );
      return;
    }

    final converted = source.toJson()
      ..['id'] = convertedLibraryItemId(source.id, newFilePath)
      ..['filePath'] = newFilePath
      ..['downloadedAt'] = DateTime.now().toIso8601String()
      ..['quality'] = newQuality
      ..['format'] = normalizedConvertedAudioFormat(targetFormat)
      ..['bitrate'] = convertedBitrate
      ..['bitDepth'] = isLossless ? bitDepth : null
      ..['sampleRate'] = isLossless ? sampleRate : null;
    if (newSafFileName != null) {
      converted['safFileName'] = newSafFileName;
    }
    await HistoryDatabase.instance.upsert(converted);
  }
}
