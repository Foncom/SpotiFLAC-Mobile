import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:spotiflac_android/services/history_database.dart';
import 'package:spotiflac_android/services/library_database.dart';
import 'package:spotiflac_android/utils/file_access.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:spotiflac_android/providers/download_queue_provider.dart';
import 'package:spotiflac_android/providers/local_library_provider.dart';
import 'package:spotiflac_android/providers/playback_provider.dart';
import 'package:spotiflac_android/providers/music_player_provider.dart';
import 'package:spotiflac_android/providers/settings_provider.dart';
import 'package:spotiflac_android/services/platform_bridge.dart';
import 'package:spotiflac_android/services/ffmpeg_service.dart';
import 'package:spotiflac_android/services/replaygain_service.dart';
import 'package:spotiflac_android/l10n/l10n.dart';
import 'package:spotiflac_android/utils/audio_conversion_utils.dart';
import 'package:spotiflac_android/utils/cover_art_utils.dart';
import 'package:spotiflac_android/utils/logger.dart';
import 'package:spotiflac_android/utils/lyrics_metadata_helper.dart';
import 'package:spotiflac_android/utils/mime_utils.dart';
import 'package:spotiflac_android/utils/image_cache_utils.dart';
import 'package:spotiflac_android/utils/string_utils.dart';
import 'package:spotiflac_android/utils/int_utils.dart';
import 'package:spotiflac_android/utils/nav_bar_inset.dart';
import 'package:spotiflac_android/widgets/audio_analysis_widget.dart';
import 'package:spotiflac_android/widgets/batch_convert_sheet.dart';
import 'package:spotiflac_android/widgets/cached_cover_image.dart';
import 'package:spotiflac_android/widgets/settings_group.dart';
import 'package:spotiflac_android/constants/music_services.dart';
import 'package:spotiflac_android/screens/collapsing_header_scroll_mixin.dart';

part 'track_metadata_edit_sheet.dart';
part 'track_metadata_cards.dart';
part 'track_metadata_lyrics.dart';
part 'track_metadata_convert.dart';
part 'track_metadata_actions.dart';

final _log = AppLogger('TrackMetadata');

class _EmbeddedCoverPreviewCacheEntry {
  final String previewPath;
  final String? sourceValidationToken;

  const _EmbeddedCoverPreviewCacheEntry({
    required this.previewPath,
    this.sourceValidationToken,
  });
}

class TrackMetadataScreen extends ConsumerStatefulWidget {
  final DownloadHistoryItem? item;
  final LocalLibraryItem? localItem;
  final List<DownloadHistoryItem>? historyNavigationItems;
  final List<LocalLibraryItem>? localNavigationItems;
  final int? navigationIndex;
  final String? coverHeroTag;

  const TrackMetadataScreen({
    super.key,
    this.item,
    this.localItem,
    this.historyNavigationItems,
    this.localNavigationItems,
    this.navigationIndex,
    this.coverHeroTag,
  }) : assert(
         item != null || localItem != null,
         'Either item or localItem must be provided',
       ),
       assert(
         historyNavigationItems == null || localNavigationItems == null,
         'Provide only one navigation list type',
       ),
       assert(
         navigationIndex == null ||
             ((historyNavigationItems != null &&
                     navigationIndex >= 0 &&
                     navigationIndex < historyNavigationItems.length) ||
                 (localNavigationItems != null &&
                     navigationIndex >= 0 &&
                     navigationIndex < localNavigationItems.length)),
         'navigationIndex must be within the provided navigation list',
       );

  @override
  ConsumerState<TrackMetadataScreen> createState() =>
      _TrackMetadataScreenState();
}

class _TrackMetadataScreenState extends ConsumerState<TrackMetadataScreen>
    with CollapsingHeaderScrollMixin<TrackMetadataScreen> {
  static const int _maxCoverPreviewCacheEntries = 96;
  static final Map<String, _EmbeddedCoverPreviewCacheEntry>
  _embeddedCoverPreviewCache = {};

  bool _fileExists = false;
  bool _hasCheckedFile = false;
  int? _fileSize;
  String? _lyrics;
  String? _rawLyrics;
  bool _lyricsLoading = false;
  String? _lyricsError;
  String? _lyricsSource;
  bool _lyricsEmbedded = false;
  bool _isEmbedding = false;
  bool _isInstrumental = false;
  bool _embeddedLyricsChecked = false;
  bool _isConverting = false;
  bool _hasMetadataChanges = false;
  bool _hasLoadedResolvedAudioMetadata = false;
  bool _isTrackSwipeNavigationInFlight = false;
  int _metadataLoadGeneration = 0;
  int _metadataTransitionDirection = 0;
  late DownloadHistoryItem? _currentDownloadItem;
  late LocalLibraryItem? _currentLocalLibraryItem;
  late int? _currentNavigationIndex;
  Map<String, dynamic>? _editedMetadata;
  String? _embeddedCoverPreviewPath;
  static final RegExp _lrcTimestampPattern = RegExp(
    r'^\[\d{2}:\d{2}\.\d{2,3}\]',
  );
  static final RegExp _lrcMetadataPattern = RegExp(r'^\[[a-zA-Z]+:.*\]$');
  static final RegExp _lrcInlineTimestampPattern = RegExp(
    r'<\d{2}:\d{2}\.\d{2,3}>',
  );
  static final RegExp _lrcSpeakerPrefixPattern = RegExp(r'^(v1|v2):\s*');
  static final RegExp _lrcBackgroundLinePattern = RegExp(r'^\[bg:(.*)\]$');
  static final RegExp _invalidFileNameChars = RegExp(r'[<>:"/\\|?*\x00-\x1f]');
  static final RegExp _multiUnderscore = RegExp(r'_+');
  static final RegExp _leadingOrTrailingDots = RegExp(r'^\.+|\.+$');
  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String get _coverCacheKey => _itemId;

  bool _isCacheTrackedPath(String? path) {
    if (!_hasPath(path)) return false;
    return _embeddedCoverPreviewCache.values.any(
      (entry) => entry.previewPath == path,
    );
  }

  bool _isVolatileSafTempPath(String path) {
    if (path.isEmpty) return false;
    return path.contains(
      '${Platform.pathSeparator}cache${Platform.pathSeparator}saf_',
    );
  }

  Future<String?> _readLocalFileValidationToken(String path) async {
    if (path.isEmpty || isContentUri(path) || _isVolatileSafTempPath(path)) {
      return null;
    }
    try {
      final stat = await fileStat(path);
      if (stat == null) return null;
      return '${stat.modified?.millisecondsSinceEpoch ?? 0}:${stat.size ?? 0}';
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheEmbeddedCoverPreview(
    String cacheKey,
    String sourcePath,
    String previewPath,
  ) async {
    final sourceValidationToken = await _readLocalFileValidationToken(
      sourcePath,
    );
    final existing = _embeddedCoverPreviewCache[cacheKey];
    _embeddedCoverPreviewCache[cacheKey] = _EmbeddedCoverPreviewCacheEntry(
      previewPath: previewPath,
      sourceValidationToken: sourceValidationToken,
    );
    if (existing != null && existing.previewPath != previewPath) {
      await _cleanupTempFileAndParentIfNotCached(existing.previewPath);
    }

    while (_embeddedCoverPreviewCache.length > _maxCoverPreviewCacheEntries) {
      final oldestKey = _embeddedCoverPreviewCache.keys.first;
      final removed = _embeddedCoverPreviewCache.remove(oldestKey);
      if (removed != null) {
        await _cleanupTempFileAndParentIfNotCached(removed.previewPath);
      }
    }
  }

  Future<void> _invalidateEmbeddedCoverPreviewCacheForPath(
    String cacheKey,
  ) async {
    if (cacheKey.isEmpty) return;
    final removed = _embeddedCoverPreviewCache.remove(cacheKey);
    if (removed != null) {
      await _cleanupTempFileAndParentIfNotCached(removed.previewPath);
    }
  }

  Future<String?> _getCachedEmbeddedCoverPreviewPathIfValid(
    String cacheKey,
    String sourcePath,
  ) async {
    if (cacheKey.isEmpty) return null;
    final cached = _embeddedCoverPreviewCache[cacheKey];
    if (cached == null) return null;

    if (!await fileExists(cached.previewPath)) {
      _embeddedCoverPreviewCache.remove(cacheKey);
      return null;
    }

    if (!isContentUri(sourcePath) && !_isVolatileSafTempPath(sourcePath)) {
      final currentToken = await _readLocalFileValidationToken(sourcePath);
      if (currentToken != null &&
          cached.sourceValidationToken != null &&
          currentToken != cached.sourceValidationToken) {
        _embeddedCoverPreviewCache.remove(cacheKey);
        await _cleanupTempFileAndParentIfNotCached(cached.previewPath);
        return null;
      }
    }

    return cached.previewPath;
  }

  @override
  void initState() {
    super.initState();
    _currentDownloadItem = widget.item;
    _currentLocalLibraryItem = widget.localItem;
    _currentNavigationIndex = widget.navigationIndex;
    _checkFile();
  }

  @override
  void dispose() {
    unawaited(_cleanupTempFileAndParentIfNotCached(_embeddedCoverPreviewPath));
    super.dispose();
  }

  /// setState is @protected, so the extension part files route rebuilds
  /// through this forwarder.
  void _setState(VoidCallback fn) => setState(fn);

  @override
  double calculateExpandedHeight(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    return (mediaSize.height * 0.55).clamp(360.0, 520.0);
  }

  Future<void> _checkFile() async {
    final generation = _metadataLoadGeneration;
    final filePath = cleanFilePath;

    bool exists = false;
    int? size;
    try {
      final stat = await fileStat(filePath);
      if (stat != null) {
        exists = true;
        size = stat.size;
      }
    } catch (_) {}

    if (mounted &&
        generation == _metadataLoadGeneration &&
        filePath == cleanFilePath &&
        (exists != _fileExists || size != _fileSize || !_hasCheckedFile)) {
      setState(() {
        _fileExists = exists;
        _fileSize = size;
        _hasCheckedFile = true;
      });
    }

    if (mounted &&
        generation == _metadataLoadGeneration &&
        filePath == cleanFilePath &&
        exists &&
        _lyrics == null &&
        !_lyricsLoading) {
      _checkEmbeddedLyrics();
    }
    if (mounted &&
        generation == _metadataLoadGeneration &&
        filePath == cleanFilePath &&
        exists &&
        !_isCueVirtualTrack &&
        !_hasLoadedResolvedAudioMetadata) {
      unawaited(_refreshResolvedAudioMetadataFromFile());
    }
    if (mounted &&
        generation == _metadataLoadGeneration &&
        filePath == cleanFilePath &&
        exists &&
        !_hasPath(_embeddedCoverPreviewPath)) {
      final cachedPath = await _getCachedEmbeddedCoverPreviewPathIfValid(
        _coverCacheKey,
        filePath,
      );
      if (mounted &&
          generation == _metadataLoadGeneration &&
          filePath == cleanFilePath &&
          _hasPath(cachedPath)) {
        setState(() => _embeddedCoverPreviewPath = cachedPath);
      }
    }
  }

  bool _hasPath(String? path) => path != null && path.trim().isNotEmpty;

  Future<void> _cleanupTempFileAndParent(String? path) async {
    if (!_hasPath(path)) return;
    final file = File(path!);
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
    try {
      final dir = file.parent;
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }

  Future<void> _cleanupTempFileAndParentIfNotCached(String? path) async {
    if (_isCacheTrackedPath(path)) return;
    await _cleanupTempFileAndParent(path);
  }

  Future<void> _refreshResolvedAudioMetadataFromFile() async {
    final generation = _metadataLoadGeneration;
    final sourcePath = cleanFilePath;
    if ((_isLocalItem && _localLibraryItem == null) ||
        (!_isLocalItem && _downloadItem == null) ||
        _isCueVirtualTrack ||
        _hasLoadedResolvedAudioMetadata) {
      return;
    }

    _hasLoadedResolvedAudioMetadata = true;

    try {
      final metadata = await PlatformBridge.readFileMetadata(sourcePath);
      if (!mounted ||
          generation != _metadataLoadGeneration ||
          sourcePath != cleanFilePath) {
        return;
      }
      if (metadata['error'] != null) {
        return;
      }

      final resolvedBitDepth = readPositiveInt(metadata['bit_depth']);
      final resolvedSampleRate = readPositiveInt(metadata['sample_rate']);
      final resolvedFormat = _normalizeAudioFormatValue(
        metadata['audio_codec']?.toString() ?? metadata['format']?.toString(),
      );
      final resolvedBitrate = _isBitrateFormatValue(resolvedFormat)
          ? _readPlausibleBitrateKbps(
              metadata['bitrate'] ?? metadata['bit_rate'],
            )
          : null;
      final resolvedDuration = readPositiveInt(metadata['duration']);
      final resolvedAlbum = metadata['album']?.toString();
      final resolvedTitle = metadata['title']?.toString();
      final resolvedArtist = metadata['artist']?.toString();
      final resolvedAlbumArtist = metadata['album_artist']?.toString();
      final resolvedDate = metadata['date']?.toString();
      final resolvedGenre = metadata['genre']?.toString();
      final resolvedQuality = _displayQualityForValues(
        format: resolvedFormat ?? _storedAudioFormat,
        bitDepth: resolvedBitDepth ?? bitDepth,
        sampleRate: resolvedSampleRate ?? sampleRate,
        bitrateKbps: resolvedBitrate ?? _audioBitrate,
        storedQuality: _quality,
      );

      final needsDuration =
          resolvedDuration != null &&
          resolvedDuration > 0 &&
          (duration == null || duration == 0);

      // Resolve label/copyright from file when the model doesn't carry them
      // (e.g. local library items, or download history items without these fields).
      final resolvedTrackNumber = readPositiveInt(metadata['track_number']);
      final resolvedTotalTracks = readPositiveInt(metadata['total_tracks']);
      final resolvedDiscNumber = readPositiveInt(metadata['disc_number']);
      final resolvedTotalDiscs = readPositiveInt(metadata['total_discs']);
      final resolvedComposer = metadata['composer']?.toString();
      final resolvedLabel = metadata['label']?.toString();
      final resolvedCopyright = metadata['copyright']?.toString();
      final resolvedISRC = metadata['isrc']?.toString();
      final needsTrackNumber =
          resolvedTrackNumber != null &&
          resolvedTrackNumber > 0 &&
          trackNumber == null;
      final needsTotalTracks =
          resolvedTotalTracks != null &&
          resolvedTotalTracks > 0 &&
          totalTracks == null;
      final needsDiscNumber =
          resolvedDiscNumber != null &&
          resolvedDiscNumber > 0 &&
          discNumber == null;
      final needsTotalDiscs =
          resolvedTotalDiscs != null &&
          resolvedTotalDiscs > 0 &&
          totalDiscs == null;
      final needsComposer =
          resolvedComposer != null &&
          resolvedComposer.isNotEmpty &&
          (composer == null || composer!.isEmpty);
      // The file is the source of truth for edited tags: an edit writes the
      // new value into the file, but the cached history item may still carry
      // the old one. Prefer the file value whenever present so re-opening the
      // screen reflects the latest saved tags instead of the stale model.
      // (Empty file values never override the model, so nothing is hidden.)
      bool present(String? v) => v != null && v.trim().isNotEmpty;
      final fileHasTitle = present(resolvedTitle);
      final fileHasArtist = present(resolvedArtist);
      final fileHasAlbumArtist = present(resolvedAlbumArtist);
      final fileHasAlbum = present(resolvedAlbum);
      final fileHasDate = present(resolvedDate);
      final fileHasGenre = present(resolvedGenre);
      final fileHasComposer = present(resolvedComposer);
      final fileHasCopyright = present(resolvedCopyright);
      final fileHasISRC = present(resolvedISRC);
      final fileHasLabel = present(resolvedLabel);
      final fileHasTrackNumber =
          resolvedTrackNumber != null && resolvedTrackNumber > 0;
      final fileHasTotalTracks =
          resolvedTotalTracks != null && resolvedTotalTracks > 0;
      final fileHasDiscNumber =
          resolvedDiscNumber != null && resolvedDiscNumber > 0;
      final fileHasTotalDiscs =
          resolvedTotalDiscs != null && resolvedTotalDiscs > 0;

      final shouldPersistResolvedAudioMetadata =
          !_isLocalItem &&
          (resolvedBitDepth != null ||
              resolvedSampleRate != null ||
              resolvedBitrate != null ||
              resolvedFormat != null ||
              needsTrackNumber ||
              needsTotalTracks ||
              needsDiscNumber ||
              needsTotalDiscs ||
              needsDuration ||
              needsComposer ||
              (isPlaceholderQualityLabel(_quality) && resolvedQuality != null));

      if ((resolvedBitDepth != null ||
              resolvedSampleRate != null ||
              fileHasTitle ||
              fileHasArtist ||
              fileHasAlbumArtist ||
              fileHasAlbum ||
              fileHasDate ||
              fileHasGenre ||
              needsDuration ||
              fileHasTrackNumber ||
              fileHasTotalTracks ||
              fileHasDiscNumber ||
              fileHasTotalDiscs ||
              fileHasComposer ||
              fileHasISRC ||
              fileHasLabel ||
              fileHasCopyright ||
              isPlaceholderQualityLabel(_quality)) &&
          mounted) {
        setState(() {
          _editedMetadata = {
            ...?_editedMetadata,
            // ignore: use_null_aware_elements
            if (resolvedBitDepth != null) 'bit_depth': resolvedBitDepth,
            // ignore: use_null_aware_elements
            if (resolvedSampleRate != null) 'sample_rate': resolvedSampleRate,
            if (fileHasTitle) 'title': resolvedTitle,
            if (fileHasArtist) 'artist': resolvedArtist,
            if (fileHasAlbumArtist) 'album_artist': resolvedAlbumArtist,
            if (fileHasAlbum) 'album': resolvedAlbum,
            if (fileHasDate) 'date': resolvedDate,
            if (fileHasGenre) 'genre': resolvedGenre,
            if (needsDuration) 'duration': resolvedDuration,
            if (fileHasTrackNumber) 'track_number': resolvedTrackNumber,
            if (fileHasTotalTracks) 'total_tracks': resolvedTotalTracks,
            if (fileHasDiscNumber) 'disc_number': resolvedDiscNumber,
            if (fileHasTotalDiscs) 'total_discs': resolvedTotalDiscs,
            if (fileHasComposer) 'composer': resolvedComposer,
            if (fileHasISRC) 'isrc': resolvedISRC,
            if (fileHasLabel) 'label': resolvedLabel,
            if (fileHasCopyright) 'copyright': resolvedCopyright,
          };
        });
      }

      if (shouldPersistResolvedAudioMetadata) {
        await ref
            .read(downloadHistoryProvider.notifier)
            .updateAudioMetadataForItem(
              id: _downloadItem!.id,
              quality: resolvedQuality,
              bitDepth: resolvedBitDepth,
              sampleRate: resolvedSampleRate,
              bitrate: resolvedBitrate,
              format: resolvedFormat,
              trackNumber: needsTrackNumber ? resolvedTrackNumber : null,
              totalTracks: needsTotalTracks ? resolvedTotalTracks : null,
              discNumber: needsDiscNumber ? resolvedDiscNumber : null,
              totalDiscs: needsTotalDiscs ? resolvedTotalDiscs : null,
              duration: needsDuration ? resolvedDuration : null,
              composer: needsComposer ? resolvedComposer : null,
            );
        if (mounted && _downloadItem != null) {
          setState(() {
            _currentDownloadItem = _downloadItem!.copyWith(
              quality: resolvedQuality,
              bitDepth: resolvedBitDepth,
              sampleRate: resolvedSampleRate,
              bitrate: resolvedBitrate,
              format: resolvedFormat,
              trackNumber: needsTrackNumber ? resolvedTrackNumber : null,
              totalTracks: needsTotalTracks ? resolvedTotalTracks : null,
              discNumber: needsDiscNumber ? resolvedDiscNumber : null,
              totalDiscs: needsTotalDiscs ? resolvedTotalDiscs : null,
              duration: needsDuration ? resolvedDuration : null,
              composer: needsComposer ? resolvedComposer : null,
            );
          });
        }
      } else if (_isLocalItem && needsDuration) {
        await LibraryDatabase.instance.updateAudioMetadata(
          _localLibraryItem!.id,
          duration: resolvedDuration,
        );
        await ref.read(localLibraryProvider.notifier).reloadFromStorage();
      }
    } catch (e) {
      _log.w('Failed to resolve audio metadata from file: $e');
    }
  }

  Future<void> _refreshEmbeddedCoverPreview({bool force = false}) async {
    final generation = _metadataLoadGeneration;
    final cacheKey = _coverCacheKey;
    final sourcePath = cleanFilePath;
    if (!force) {
      final cachedPath = await _getCachedEmbeddedCoverPreviewPathIfValid(
        cacheKey,
        sourcePath,
      );
      if (_hasPath(cachedPath)) {
        if (mounted &&
            generation == _metadataLoadGeneration &&
            sourcePath == cleanFilePath &&
            _embeddedCoverPreviewPath != cachedPath) {
          setState(() => _embeddedCoverPreviewPath = cachedPath);
        }
        return;
      }
    }

    String? newPreviewPath;
    try {
      if (!_fileExists) {
        await _invalidateEmbeddedCoverPreviewCacheForPath(cacheKey);
        await _cleanupTempFileAndParentIfNotCached(_embeddedCoverPreviewPath);
        if (mounted &&
            generation == _metadataLoadGeneration &&
            sourcePath == cleanFilePath) {
          setState(() => _embeddedCoverPreviewPath = null);
        }
        return;
      }
      if (force) {
        await _invalidateEmbeddedCoverPreviewCacheForPath(cacheKey);
      }
      final tempDir = await Directory.systemTemp.createTemp(
        'track_cover_preview_',
      );
      final outputPath =
          '${tempDir.path}${Platform.pathSeparator}cover_preview.jpg';
      final result = await PlatformBridge.extractCoverToFile(
        sourcePath,
        outputPath,
      );
      if (result['error'] == null && await File(outputPath).exists()) {
        newPreviewPath = outputPath;
        await _cacheEmbeddedCoverPreview(cacheKey, sourcePath, outputPath);
      } else {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      }
    } catch (_) {}

    final oldPreviewPath = _embeddedCoverPreviewPath;
    if (!mounted ||
        generation != _metadataLoadGeneration ||
        sourcePath != cleanFilePath) {
      if (newPreviewPath != null) {
        await _cleanupTempFileAndParentIfNotCached(newPreviewPath);
      }
      return;
    }

    setState(() => _embeddedCoverPreviewPath = newPreviewPath);
    if (oldPreviewPath != null && oldPreviewPath != newPreviewPath) {
      await _cleanupTempFileAndParentIfNotCached(oldPreviewPath);
    }
  }

  bool get _isLocalItem => _currentLocalLibraryItem != null;
  DownloadHistoryItem? get _downloadItem => _currentDownloadItem;
  LocalLibraryItem? get _localLibraryItem => _currentLocalLibraryItem;
  bool get _hasHistoryNavigation =>
      widget.historyNavigationItems != null && widget.navigationIndex != null;
  bool get _hasLocalNavigation =>
      widget.localNavigationItems != null && widget.navigationIndex != null;
  bool get _hasTrackSwipeNavigation =>
      _hasHistoryNavigation || _hasLocalNavigation;
  int? get _navigationIndex => _currentNavigationIndex;
  int get _navigationLength =>
      widget.historyNavigationItems?.length ??
      widget.localNavigationItems?.length ??
      0;

  String get _itemId =>
      _isLocalItem ? _localLibraryItem!.id : _downloadItem!.id;
  String get trackName =>
      _editedMetadata?['title']?.toString() ??
      (_isLocalItem ? _localLibraryItem!.trackName : _downloadItem!.trackName);
  String get artistName =>
      _editedMetadata?['artist']?.toString() ??
      (_isLocalItem
          ? _localLibraryItem!.artistName
          : _downloadItem!.artistName);
  String get albumName =>
      _editedMetadata?['album']?.toString() ??
      (_isLocalItem ? _localLibraryItem!.albumName : _downloadItem!.albumName);
  String? get albumArtist {
    final edited = _editedMetadata?['album_artist']?.toString();
    if (edited != null && edited.isNotEmpty) return edited;
    return normalizeOptionalString(
      _isLocalItem
          ? _localLibraryItem!.albumArtist
          : _downloadItem!.albumArtist,
    );
  }

  int? get trackNumber {
    final edited = _editedMetadata?['track_number'];
    if (edited != null) {
      final v = int.tryParse(edited.toString());
      if (v != null && v > 0) return v;
    }
    return _isLocalItem
        ? _localLibraryItem!.trackNumber
        : _downloadItem!.trackNumber;
  }

  int? get totalTracks =>
      readPositiveInt(_editedMetadata?['total_tracks']) ??
      (_isLocalItem
          ? _localLibraryItem!.totalTracks
          : _downloadItem!.totalTracks);

  int? get discNumber {
    final edited = _editedMetadata?['disc_number'];
    if (edited != null) {
      final v = int.tryParse(edited.toString());
      if (v != null && v > 0) return v;
    }
    return _isLocalItem
        ? _localLibraryItem!.discNumber
        : _downloadItem!.discNumber;
  }

  int? get totalDiscs =>
      readPositiveInt(_editedMetadata?['total_discs']) ??
      (_isLocalItem
          ? _localLibraryItem!.totalDiscs
          : _downloadItem!.totalDiscs);

  String? get releaseDate =>
      _editedMetadata?['date']?.toString() ??
      (_isLocalItem
          ? _localLibraryItem!.releaseDate
          : _downloadItem!.releaseDate);
  String? get isrc {
    final raw =
        _editedMetadata?['isrc']?.toString() ??
        (_isLocalItem ? _localLibraryItem!.isrc : _downloadItem!.isrc);
    if (raw == null || raw.trim().isEmpty) return null;
    final upper = raw.trim().toUpperCase();
    // Only accept valid ISRC codes (CC-XXX-YY-NNNNN, 12 alphanumeric chars).
    // Strip hyphens/spaces that some sources include.
    final stripped = upper.replaceAll(RegExp(r'[-\s]'), '');
    if (_isrcValidationPattern.hasMatch(stripped)) return stripped;
    return null;
  }

  static final RegExp _isrcValidationPattern = RegExp(
    r'^[A-Z]{2}[A-Z0-9]{3}\d{7}$',
  );
  String? get genre =>
      _editedMetadata?['genre']?.toString() ??
      (_isLocalItem ? _localLibraryItem!.genre : _downloadItem!.genre);
  String? get label =>
      _editedMetadata?['label']?.toString() ??
      (_isLocalItem ? _localLibraryItem!.label : _downloadItem!.label);
  String? get copyright =>
      _editedMetadata?['copyright']?.toString() ??
      (_isLocalItem ? _localLibraryItem!.copyright : _downloadItem!.copyright);
  String? get composer =>
      _editedMetadata?['composer']?.toString() ??
      (_isLocalItem ? _localLibraryItem!.composer : null);
  int? get duration =>
      readPositiveInt(_editedMetadata?['duration']) ??
      (_isLocalItem ? _localLibraryItem!.duration : _downloadItem!.duration);
  int? get bitDepth =>
      readPositiveInt(_editedMetadata?['bit_depth']) ??
      (_isLocalItem ? _localLibraryItem!.bitDepth : _downloadItem!.bitDepth);
  int? get sampleRate =>
      readPositiveInt(_editedMetadata?['sample_rate']) ??
      (_isLocalItem
          ? _localLibraryItem!.sampleRate
          : _downloadItem!.sampleRate);
  int? get _audioBitrate =>
      _isLocalItem ? _localLibraryItem!.bitrate : _downloadItem?.bitrate;
  String? get _storedAudioFormat =>
      _isLocalItem ? _localLibraryItem?.format : _downloadItem?.format;

  String get _filePath =>
      _isLocalItem ? _localLibraryItem!.filePath : _downloadItem!.filePath;
  String get _coverHeroTag =>
      widget.coverHeroTag ??
      (_isLocalItem ? 'cover_lib_$_itemId' : 'cover_$_itemId');
  String? get _coverUrl => _isLocalItem
      ? null
      : highResCoverUrl(normalizeRemoteHttpUrl(_downloadItem!.coverUrl));

  String? get _localCoverPath =>
      _isLocalItem ? _localLibraryItem!.coverPath : null;
  String? get _spotifyId => _isLocalItem ? null : _downloadItem!.spotifyId;
  String get _service =>
      _isLocalItem ? MusicServices.local : _downloadItem!.service;
  DateTime get _addedAt {
    if (_isLocalItem) {
      final modTime = _localLibraryItem!.fileModTime;
      if (modTime != null && modTime > 0) {
        return DateTime.fromMillisecondsSinceEpoch(modTime);
      }
      return _localLibraryItem!.scannedAt;
    }
    return _downloadItem!.downloadedAt;
  }

  String? get _quality => _isLocalItem ? null : _downloadItem!.quality;

  String? _normalizeAudioFormatValue(String? value) {
    final normalized = normalizeOptionalString(
      value,
    )?.toLowerCase().replaceAll('-', '_');
    return switch (normalized) {
      'flac' => 'flac',
      'alac' => 'alac',
      'aac' || 'mp4a' => 'aac',
      'eac3' || 'ec_3' => 'eac3',
      'ac3' || 'ac_3' => 'ac3',
      'ac4' || 'ac_4' => 'ac4',
      'mp3' => 'mp3',
      'opus' || 'ogg' => 'opus',
      'm4a' || 'mp4' => 'm4a',
      _ => null,
    };
  }

  int? _readPlausibleBitrateKbps(dynamic value) {
    final parsed = readPositiveInt(value);
    if (parsed == null) return null;
    final kbps = parsed >= 10000 ? (parsed / 1000).round() : parsed;
    return kbps >= 16 ? kbps : null;
  }

  bool _isBitrateFormatValue(String? value) {
    return const {
      'aac',
      'eac3',
      'ac3',
      'ac4',
      'mp3',
      'opus',
      'm4a',
    }.contains(_normalizeAudioFormatValue(value));
  }

  String? _usableStoredQuality(String? quality) {
    final normalized = normalizeOptionalString(quality);
    if (normalized == null || isPlaceholderQualityLabel(normalized)) {
      return null;
    }
    final bitrateMatch = RegExp(
      r'\b(\d+)\s*kbps\b',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (bitrateMatch != null) {
      final bitrate = int.tryParse(bitrateMatch.group(1) ?? '');
      if (bitrate != null && bitrate < 16) return null;
    }
    return normalized;
  }

  String? _displayQualityForValues({
    required String? format,
    int? bitDepth,
    int? sampleRate,
    int? bitrateKbps,
    String? storedQuality,
  }) {
    final normalizedFormat = _normalizeAudioFormatValue(format);
    final formatLabel = normalizedFormat == null
        ? normalizeOptionalString(format)?.toUpperCase()
        : _formatLabelForRaw(normalizedFormat);
    if (_isBitrateFormatValue(normalizedFormat)) {
      return buildDisplayAudioQuality(
            bitrateKbps: bitrateKbps,
            format: formatLabel,
          ) ??
          _usableStoredQuality(storedQuality) ??
          formatLabel;
    }
    return buildDisplayAudioQuality(
      bitDepth: bitDepth,
      sampleRate: sampleRate,
      storedQuality: _usableStoredQuality(storedQuality),
    );
  }

  String _displayServiceTrackId(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return raw;
    final spotifyTrackIdPattern = RegExp(r'^[A-Za-z0-9]{22}$');

    if (raw.startsWith('deezer:')) return raw.substring('deezer:'.length);
    if (raw.startsWith('tidal:')) return raw.substring('tidal:'.length);
    if (raw.startsWith('qobuz:')) return raw.substring('qobuz:'.length);
    if (spotifyTrackIdPattern.hasMatch(raw)) return raw;

    if (raw.startsWith('spotify:')) {
      final last = raw.split(':').last.trim();
      if (spotifyTrackIdPattern.hasMatch(last)) return last;
      return raw;
    }

    final uri = Uri.tryParse(raw);
    if (uri != null &&
        uri.host.contains('spotify.com') &&
        uri.pathSegments.length >= 2 &&
        uri.pathSegments.first == 'track') {
      final candidate = uri.pathSegments[1].trim();
      if (spotifyTrackIdPattern.hasMatch(candidate)) {
        return candidate;
      }
    }

    return raw;
  }

  String _serviceForTrackId(String value, {required String fallbackService}) {
    final raw = value.trim();
    if (raw.isEmpty) return fallbackService;
    final spotifyTrackIdPattern = RegExp(r'^[A-Za-z0-9]{22}$');

    if (raw.startsWith('deezer:')) return MusicServices.deezer;
    if (raw.startsWith('tidal:')) return MusicServices.tidal;
    if (raw.startsWith('qobuz:')) return MusicServices.qobuz;
    if (raw.startsWith('spotify:')) return MusicServices.spotify;
    if (spotifyTrackIdPattern.hasMatch(raw)) return MusicServices.spotify;

    final uri = Uri.tryParse(raw);
    if (uri != null) {
      final host = uri.host.toLowerCase();
      if (host.contains('spotify.com')) return MusicServices.spotify;
      if (host.contains('deezer.com')) return MusicServices.deezer;
      if (host.contains('tidal.com')) return MusicServices.tidal;
      if (host.contains('qobuz.com')) return MusicServices.qobuz;
    }

    return fallbackService;
  }

  String? get _displayAudioQuality {
    final fileName = _extractFileNameFromPathOrUri(cleanFilePath);
    final fileExt = fileName.contains('.')
        ? fileName.split('.').last.toUpperCase()
        : null;

    return _displayQualityForValues(
      format: _storedAudioFormat ?? fileExt,
      bitDepth: bitDepth,
      sampleRate: sampleRate,
      bitrateKbps: _audioBitrate,
      storedQuality: _quality,
    );
  }

  /// The raw file path, with EXISTS: prefix stripped but #trackNN preserved.
  /// Use this when you need the full virtual path (e.g. for display or DB lookups).
  String get rawFilePath {
    final path = _filePath;
    return path.startsWith('EXISTS:') ? path.substring(7) : path;
  }

  /// The clean file path with both EXISTS: prefix and #trackNN suffix stripped.
  /// Use this for actual filesystem/SAF operations.
  String get cleanFilePath {
    var path = _filePath;
    if (path.startsWith('EXISTS:')) path = path.substring(7);
    if (isCueVirtualPath(path)) path = stripCueTrackSuffix(path);
    return path;
  }

  bool get _isCueVirtualTrack => isCueVirtualPath(rawFilePath);

  String _cueVirtualTrackGuidance(BuildContext context) {
    return 'This CUE track is virtual. Use ${context.l10n.cueSplitButton} first.';
  }

  void _showCueVirtualTrackSnackBar(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_cueVirtualTrackGuidance(context))));
  }

  void _hideCurrentSnackBar() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  String get _l10nCueSplitFailed => context.l10n.cueSplitFailed;
  String get _l10nCueSplitNoAudioFile => context.l10n.cueSplitNoAudioFile;

  String _l10nCueSplitSplitting(int current, int total) {
    return context.l10n.cueSplitSplitting(current, total);
  }

  String _l10nCueSplitSuccess(int count) {
    return context.l10n.cueSplitSuccess(count);
  }

  void _showSnackBarMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showLongSnackBarMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 60)),
    );
  }

  String _formatPathForDisplay(String pathOrUri) {
    if (pathOrUri.isEmpty || !pathOrUri.startsWith('content://')) {
      return pathOrUri;
    }

    try {
      final uri = Uri.parse(pathOrUri);
      final segments = uri.pathSegments;
      String? documentId;

      final documentIndex = segments.indexOf('document');
      if (documentIndex != -1 && documentIndex + 1 < segments.length) {
        documentId = Uri.decodeComponent(segments[documentIndex + 1]);
      }

      if (documentId == null || documentId.isEmpty) {
        final treeIndex = segments.indexOf('tree');
        if (treeIndex != -1 && treeIndex + 1 < segments.length) {
          documentId = Uri.decodeComponent(segments[treeIndex + 1]);
        }
      }

      if (documentId == null || documentId.isEmpty) return pathOrUri;

      final separatorIndex = documentId.indexOf(':');
      if (separatorIndex <= 0) return documentId;

      final volumeId = documentId.substring(0, separatorIndex);
      final relativePath = documentId
          .substring(separatorIndex + 1)
          .replaceAll('\\', '/');

      if (volumeId.toLowerCase() == 'primary') {
        if (relativePath.isEmpty) return '/storage/emulated/0';
        return '/storage/emulated/0/$relativePath';
      }

      if (relativePath.isEmpty) return volumeId;
      return 'SD Card/$relativePath';
    } catch (_) {
      return pathOrUri;
    }
  }

  void _markMetadataChanged() {
    _hasMetadataChanges = true;
  }

  void _popWithMetadataResult() {
    Navigator.pop(context, _hasMetadataChanges ? true : null);
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity;
    if (velocity == null || velocity.abs() < 350) return;
    if (velocity < 0) {
      unawaited(_navigateToAdjacentTrack(1));
    } else {
      unawaited(_navigateToAdjacentTrack(-1));
    }
  }

  Future<void> _navigateToAdjacentTrack(int offset) async {
    if (_isTrackSwipeNavigationInFlight || !_hasTrackSwipeNavigation) return;
    final currentIndex = _navigationIndex;
    if (currentIndex == null) return;
    final targetIndex = currentIndex + offset;
    if (targetIndex < 0 || targetIndex >= _navigationLength) return;

    _isTrackSwipeNavigationInFlight = true;
    final oldPreviewPath = _embeddedCoverPreviewPath;

    try {
      setState(() {
        _metadataLoadGeneration++;
        _metadataTransitionDirection = offset > 0 ? 1 : -1;
        _currentNavigationIndex = targetIndex;
        if (_hasHistoryNavigation) {
          _currentDownloadItem = widget.historyNavigationItems![targetIndex];
          _currentLocalLibraryItem = null;
        } else {
          _currentDownloadItem = null;
          _currentLocalLibraryItem = widget.localNavigationItems![targetIndex];
        }
        _fileExists = false;
        _hasCheckedFile = false;
        _fileSize = null;
        _lyrics = null;
        _rawLyrics = null;
        _lyricsLoading = false;
        _lyricsError = null;
        _lyricsSource = null;
        showTitleInAppBar = false;
        _lyricsEmbedded = false;
        _isInstrumental = false;
        _embeddedLyricsChecked = false;
        _hasLoadedResolvedAudioMetadata = false;
        _editedMetadata = null;
        _embeddedCoverPreviewPath = null;
      });

      if (scrollController.hasClients) {
        scrollController.jumpTo(0);
      }

      if (oldPreviewPath != null) {
        unawaited(_cleanupTempFileAndParentIfNotCached(oldPreviewPath));
      }
      await _checkFile();
    } finally {
      if (mounted) {
        _isTrackSwipeNavigationInFlight = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final expandedHeight = calculateExpandedHeight(context);
    final bottomInset = context.navBarBottomInset;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: _handleHorizontalDragEnd,
      child: Scaffold(
        body: CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverAppBar(
              expandedHeight: expandedHeight,
              pinned: true,
              stretch: true,
              backgroundColor: colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              title: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: showTitleInAppBar ? 1.0 : 0.0,
                child: Text(
                  trackName,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              flexibleSpace: LayoutBuilder(
                builder: (context, constraints) {
                  final collapseRatio =
                      (constraints.maxHeight - kToolbarHeight) /
                      (expandedHeight - kToolbarHeight);
                  final showContent = collapseRatio > 0.3;

                  return FlexibleSpaceBar(
                    collapseMode: CollapseMode.pin,
                    background: _buildHeaderBackground(
                      context,
                      colorScheme,
                      expandedHeight,
                      showContent,
                    ),
                    stretchModes: const [StretchMode.zoomBackground],
                  );
                },
              ),
              leading: IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                onPressed: _popWithMetadataResult,
              ),
              actions: [
                IconButton(
                  tooltip: MaterialLocalizations.of(context).showMenuTooltip,
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.more_vert, color: Colors.white),
                  ),
                  onPressed: () => _showOptionsMenu(context, ref, colorScheme),
                ),
              ],
            ),

            SliverToBoxAdapter(
              child: _buildAnimatedTrackContent(context, ref, colorScheme),
            ),
            SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
          ],
        ),
      ),
    );
  }

  Future<void> _enqueueThis(WidgetRef ref, {required bool playNext}) async {
    final controller = ref.read(musicPlayerControllerProvider);
    final item = widget.item;
    final localItem = widget.localItem;
    if (item != null) {
      if (playNext) {
        await controller.playNextHistory(item);
      } else {
        await controller.addToQueueHistory(item);
      }
    } else if (localItem != null) {
      if (playNext) {
        await controller.playNextLocal(localItem);
      } else {
        await controller.addToQueueLocal(localItem);
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          playNext
              ? context.l10n.snackbarPlayingNext
              : context.l10n.snackbarAddedToQueueGeneric,
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    WidgetRef ref,
    ColorScheme colorScheme,
    bool fileExists,
  ) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: fileExists
                ? () => _openFile(context, rawFilePath)
                : null,
            icon: const Icon(Icons.play_arrow),
            label: Text(context.l10n.trackMetadataPlay),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _confirmDelete(context, ref, colorScheme),
            icon: Icon(Icons.delete_outline, color: colorScheme.error),
            label: Text(
              context.l10n.trackMetadataDelete,
              style: TextStyle(color: colorScheme.error),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              side: BorderSide(color: colorScheme.error.withValues(alpha: 0.5)),
            ),
          ),
        ),
      ],
    );
  }

  void _showOptionsMenu(
    BuildContext screenContext,
    WidgetRef ref,
    ColorScheme colorScheme,
  ) {
    showModalBottomSheet<void>(
      context: screenContext,
      useRootNavigator: true,
      backgroundColor: colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      isScrollControlled: true,
      builder: (sheetContext) {
        final l10n = sheetContext.l10n;

        final options = <_MetadataOption>[
          if (_fileExists)
            _MetadataOption(
              icon: Icons.playlist_play,
              label: l10n.trackPlayNext,
              onTap: () => _enqueueThis(ref, playNext: true),
            ),
          if (_fileExists)
            _MetadataOption(
              icon: Icons.queue_music,
              label: l10n.trackAddToQueue,
              onTap: () => _enqueueThis(ref, playNext: false),
            ),
          _MetadataOption(
            icon: Icons.copy_outlined,
            label: l10n.trackCopyFilePath,
            dividerAbove: _fileExists,
            onTap: () => _copyToClipboard(screenContext, cleanFilePath),
          ),
          if (_fileExists)
            _MetadataOption(
              icon: Icons.edit_outlined,
              label: l10n.trackEditMetadata,
              onTap: () =>
                  _showEditMetadataSheet(screenContext, ref, colorScheme),
            ),
          if (!_isLocalItem && (_coverUrl != null || _fileExists))
            _MetadataOption(
              icon: Icons.image_outlined,
              label: l10n.trackSaveCoverArt,
              onTap: _saveCoverArt,
            ),
          if (!_isLocalItem)
            _MetadataOption(
              icon: Icons.lyrics_outlined,
              label: l10n.trackSaveLyrics,
              onTap: _saveLyrics,
            ),
          if (_fileExists)
            _MetadataOption(
              icon: Icons.travel_explore,
              label: l10n.trackReEnrich,
              onTap: _reEnrichMetadata,
            ),
          if (_fileExists && _isConvertibleFormat)
            _MetadataOption(
              icon: Icons.swap_horiz,
              label: l10n.trackConvertFormat,
              onTap: () => _showConvertSheet(screenContext),
            ),
          if (_fileExists && !_isCueFile)
            _MetadataOption(
              icon: Icons.graphic_eq,
              label: l10n.trackReplayGain,
              onTap: () => _rescanReplayGain(),
            ),
          if (_fileExists && _isCueFile)
            _MetadataOption(
              icon: Icons.call_split,
              label: l10n.cueSplitTitle,
              onTap: () => _showCueSplitSheet(screenContext),
            ),
          _MetadataOption(
            icon: Icons.share_outlined,
            label: l10n.trackMetadataShare,
            dividerAbove: true,
            onTap: () => _shareFile(screenContext),
          ),
          _MetadataOption(
            icon: Icons.delete_outline,
            label: l10n.trackRemoveFromDevice,
            destructive: true,
            onTap: () => _confirmDelete(screenContext, ref, colorScheme),
          ),
        ];

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.4,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _buildOptionsHeaderCover(colorScheme),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trackName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                artistName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 8),
                  SettingsGroup(
                    children: [
                      for (int i = 0; i < options.length; i++) ...[
                        if (options[i].dividerAbove && i != 0)
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        _MetadataOptionTile(
                          option: options[i],
                          colorScheme: colorScheme,
                          onTap: () => _closeOptionsMenuAndRun(
                            sheetContext,
                            options[i].onTap,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionsHeaderCover(ColorScheme colorScheme) {
    const size = 56.0;
    const cacheWidth = 112;

    Widget placeholder() => Container(
      width: size,
      height: size,
      color: colorScheme.surfaceContainerHighest,
      child: Icon(Icons.music_note, color: colorScheme.onSurfaceVariant),
    );

    if (_coverUrl != null) {
      return CachedCoverImage(
        imageUrl: _coverUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        memCacheWidth: cacheWidth,
        memCacheHeight: cacheWidth,
        errorWidget: (_, _, _) => placeholder(),
      );
    }

    if (_localCoverPath != null && _localCoverPath!.isNotEmpty) {
      return Image.file(
        File(_localCoverPath!),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        errorBuilder: (_, _, _) => placeholder(),
      );
    }

    return placeholder();
  }
}

class _MetadataOption {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  final bool dividerAbove;

  const _MetadataOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.dividerAbove = false,
  });
}

class _MetadataOptionTile extends StatelessWidget {
  final _MetadataOption option;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _MetadataOptionTile({
    required this.option,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = option.destructive
        ? colorScheme.error
        : colorScheme.onSurfaceVariant;
    final titleColor = option.destructive ? colorScheme.error : null;

    return InkWell(
      onTap: onTap,
      splashColor: colorScheme.primary.withValues(alpha: 0.12),
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(option.icon, color: iconColor, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                option.label,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: titleColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
