import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotiflac_android/models/download_item.dart';
import 'package:spotiflac_android/models/settings.dart';
import 'package:spotiflac_android/models/track.dart';
import 'package:spotiflac_android/providers/settings_provider.dart';
import 'package:spotiflac_android/providers/extension_provider.dart';
import 'package:spotiflac_android/services/app_state_database.dart';
import 'package:spotiflac_android/services/platform_bridge.dart';
import 'package:spotiflac_android/services/download_request_payload.dart';
import 'package:spotiflac_android/services/ffmpeg_service.dart';
import 'package:spotiflac_android/services/notification_service.dart';
import 'package:spotiflac_android/utils/logger.dart' hide log;
import 'package:spotiflac_android/utils/file_access.dart';
import 'package:spotiflac_android/utils/string_utils.dart';
import 'package:spotiflac_android/utils/artist_utils.dart';
import 'package:spotiflac_android/utils/audio_format_utils.dart';
import 'package:spotiflac_android/utils/int_utils.dart';
import 'package:spotiflac_android/utils/extension_auth_launcher.dart';
import 'package:spotiflac_android/utils/progress_stream_poller.dart';

import 'package:spotiflac_android/providers/download_history_provider.dart';

export 'package:spotiflac_android/providers/download_history_provider.dart';

export 'package:spotiflac_android/services/history_database.dart'
    show HistoryLookupRequest, HistoryBatchLookupRequest;

part 'download_queue_provider_paths.dart';
part 'download_queue_provider_native_worker.dart';
part 'download_queue_provider_finalization.dart';
part 'download_queue_provider_replaygain.dart';
part 'download_queue_provider_embedding.dart';

final _log = AppLogger('DownloadQueue');

/// Set on queued items when the persisted Android SAF grant fails validation.
/// The queue UI matches on this to offer re-selecting the download folder.
const String safPermissionLostErrorMessage =
    'SAF permission invalid or revoked. Please reconfigure download location in Settings.';

/// Set on queued items when the iOS download folder bookmark can no longer be
/// opened. The queue UI matches on this to offer re-selecting the folder.
const String downloadFolderAccessLostErrorMessage =
    'Download folder access lost. Please re-select your download folder in Settings.';

final _invalidFolderChars = RegExp(r'[<>:"/\\|?*]');
final _trimDotsAndSpacesRegex = RegExp(r'^[. ]+|[. ]+$');
final _trimUnderscoresAndSpacesRegex = RegExp(r'^[_ ]+|[_ ]+$');
final _multiWhitespaceRegex = RegExp(r'\s+');
final _multiUnderscoreRegex = RegExp(r'_+');

/// log10 helper using dart:math's natural log.
double _log10(num x) => log(x) / ln10;
final _yearRegex = RegExp(r'^(\d{4})');
const _defaultOutputFolderName = 'SpotiFLAC';
const _defaultAndroidMusicSubpath = 'Music/$_defaultOutputFolderName';
const _maxSafFilenameUtf8Bytes = 180;
const _maxSafDirSegmentUtf8Bytes = 120;
final _batchUniqueFilenameTokenPattern = RegExp(
  r'\{(?:title|track(?:_raw)?|track:\d+|playlist_position(?:_raw)?|playlist_position:\d+|playlist position|playlistPosition|position(?::\d+)?)\}',
  caseSensitive: false,
);

class DownloadQueueState {
  static const Object _noChange = Object();
  final List<DownloadItem> items;
  final DownloadQueueLookup lookup;
  final DownloadItem? currentDownload;
  final bool isProcessing;
  final bool isPaused;
  final String outputDir;
  final String filenameFormat;
  final String singleFilenameFormat;
  final String audioQuality;
  final bool autoFallback;

  const DownloadQueueState({
    this.items = const [],
    this.lookup = const DownloadQueueLookup.empty(),
    this.currentDownload,
    this.isProcessing = false,
    this.isPaused = false,
    this.outputDir = '',
    this.filenameFormat = '{artist} - {title}',
    this.singleFilenameFormat = '{title} - {artist}',
    this.audioQuality = 'LOSSLESS',
    this.autoFallback = true,
  });

  DownloadQueueState copyWith({
    List<DownloadItem>? items,
    DownloadQueueLookup? lookup,
    Object? currentDownload = _noChange,
    bool? isProcessing,
    bool? isPaused,
    String? outputDir,
    String? filenameFormat,
    String? singleFilenameFormat,
    String? audioQuality,
    bool? autoFallback,
  }) {
    final resolvedItems = items ?? this.items;
    return DownloadQueueState(
      items: resolvedItems,
      lookup:
          lookup ??
          (items != null
              ? DownloadQueueLookup.fromItems(resolvedItems)
              : this.lookup),
      currentDownload: identical(currentDownload, _noChange)
          ? this.currentDownload
          : currentDownload as DownloadItem?,
      isProcessing: isProcessing ?? this.isProcessing,
      isPaused: isPaused ?? this.isPaused,
      outputDir: outputDir ?? this.outputDir,
      filenameFormat: filenameFormat ?? this.filenameFormat,
      singleFilenameFormat: singleFilenameFormat ?? this.singleFilenameFormat,
      audioQuality: audioQuality ?? this.audioQuality,
      autoFallback: autoFallback ?? this.autoFallback,
    );
  }

  int get queuedCount => items.isEmpty ? 0 : lookup.queuedCount;
  int get completedCount => items.isEmpty ? 0 : lookup.completedCount;
  int get failedCount => items.isEmpty ? 0 : lookup.failedCount;
  int get activeDownloadsCount =>
      items.isEmpty ? 0 : lookup.activeDownloadsCount;
}

class _ProgressUpdate {
  final DownloadStatus status;
  final double progress;
  final double? speedMBps;
  final int? bytesReceived;
  final int? bytesTotal;

  const _ProgressUpdate({
    required this.status,
    required this.progress,
    this.speedMBps,
    this.bytesReceived,
    this.bytesTotal,
  });
}

class DownloadQueueNotifier extends Notifier<DownloadQueueState> {
  Timer? _queuePersistDebounce;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  int _downloadCount = 0;
  static const _cleanupInterval = 50;
  static const _progressPollingInterval = Duration(milliseconds: 1200);
  static const _idleProgressPollEveryTicks = 3;
  static const _progressStreamBootstrapTimeout = Duration(seconds: 3);
  static const _queueSchedulingInterval = Duration(milliseconds: 250);
  static const _queuePersistDebounceDuration = Duration(milliseconds: 350);
  static const _nativeWorkerRunIdPrefsKey =
      'download_queue_native_worker_run_id';
  static const _bytesUiStep = 104857; // ~0.1 MiB, matches one-decimal MB UI.
  static const _serviceProgressStepPercent = 2;
  static const _decryptStageSafAccess = 'safAccess';
  static const _decryptStageDecrypt = 'decrypt';
  static const _decryptStageSafWrite = 'safWrite';
  final NotificationService _notificationService = NotificationService();
  final AppStateDatabase _appStateDb = AppStateDatabase.instance;
  // Shared across tracks in a batch: an album's tracks embed the same cover,
  // so fetch it once instead of once per track. LRU-capped; files are deleted
  // on eviction and when the queue drains.
  final Map<String, Future<String?>> _embedCoverCache = {};
  late final ProgressStreamPoller<Map<String, dynamic>> _progressPoller =
      ProgressStreamPoller<Map<String, dynamic>>(
        streamProvider: PlatformBridge.downloadProgressStream,
        pollProvider: PlatformBridge.getAllDownloadProgress,
        onProgress: (allProgress) async =>
            _processAllDownloadProgress(allProgress),
        pollingInterval: _progressPollingInterval,
        bootstrapTimeout: _progressStreamBootstrapTimeout,
        onStreamProcessingError: (e) =>
            _log.w('Progress stream processing failed: $e'),
        onStreamFailed: (error) => _log.w(
          'Download progress stream failed, fallback to polling: $error',
        ),
        onStreamTimeout: () =>
            _log.w('Download progress stream timeout, fallback to polling'),
        onPollError: (e) => _log.w('Progress polling failed: $e'),
        shouldPollTick: () => _shouldPollDownloadProgressTick(),
      );
  int _totalQueuedAtStart = 0;
  int _completedInSession = 0;
  int _failedInSession = 0;
  int _queueItemSequence = 0;
  bool _isLoaded = false;
  final Set<String> _ensuredDirs = {};
  int _idleProgressPollTick = 0;
  bool _networkPausedByWifiOnly = false;
  List<ConnectivityResult>? _lastConnectivityResults;
  DateTime _lastConnectionCleanupAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const _connectionCleanupDebounce = Duration(seconds: 2);
  String? _lastServiceTrackName;
  String? _lastServiceArtistName;
  String? _lastServiceStatus;
  int _lastServicePercent = -1;
  int _lastServiceQueueCount = -1;
  DateTime _lastServiceUpdateAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? _lastFinalizingTrackName;
  String? _lastFinalizingArtistName;
  String? _lastNotifTrackName;
  String? _lastNotifArtistName;
  int _lastNotifPercent = -1;
  int _lastNotifQueueCount = -1;
  final Set<String> _locallyCancelledItemIds = {};
  final Set<String> _pausePendingItemIds = {};
  final Set<String> _verificationRetriedItemIds = {};
  final Set<String> _rateLimitRetriedItemIds = {};
  String? _activeNativeWorkerRunId;

  // Album ReplayGain accumulator: keyed by album identifier.
  // Stores per-track loudness data until all album tracks are done,
  // then computes and writes album gain/peak to every track in the album.
  final Map<String, _AlbumRgAccumulator> _albumRgData = {};

  String _verificationRetryKey(String itemId, String service) =>
      '$itemId::${service.trim().toLowerCase()}';

  double _normalizeProgressForUi(double value) {
    final clamped = value.clamp(0.0, 1.0).toDouble();
    if (clamped <= 0) return 0;
    if (clamped >= 1) return 1;
    final rounded = double.parse(clamped.toStringAsFixed(2));
    return rounded == 0 ? 0.01 : rounded;
  }

  double _normalizeSpeedForUi(double value) {
    if (value <= 0) return 0;
    return double.parse(value.toStringAsFixed(1));
  }

  int _normalizeBytesForUi(int value) {
    if (value <= 0) return 0;
    return (value ~/ _bytesUiStep) * _bytesUiStep;
  }

  bool _shouldUpdateProgressNotification({
    required String trackName,
    required String artistName,
    required int progress,
    required int total,
    required int queueCount,
  }) {
    final safeTotal = total > 0 ? total : 1;
    final percent = ((progress * 100) / safeTotal).round().clamp(0, 100);
    final changed =
        trackName != _lastNotifTrackName ||
        artistName != _lastNotifArtistName ||
        percent != _lastNotifPercent ||
        queueCount != _lastNotifQueueCount;
    if (!changed) {
      return false;
    }

    _lastNotifTrackName = trackName;
    _lastNotifArtistName = artistName;
    _lastNotifPercent = percent;
    _lastNotifQueueCount = queueCount;
    return true;
  }

  @override
  DownloadQueueState build() {
    ref.listen<AppSettings>(settingsProvider, (previous, next) {
      updateSettings(next);
      if (previous?.downloadNetworkMode != next.downloadNetworkMode) {
        _handleDownloadNetworkModeChanged(next.downloadNetworkMode);
      }
    });

    ref.onDispose(() {
      _progressPoller.stop();
      _connectivitySub?.cancel();
      _connectivitySub = null;
      if (_queuePersistDebounce?.isActive == true) {
        _queuePersistDebounce?.cancel();
        unawaited(_flushQueueToStorage());
      } else {
        _queuePersistDebounce?.cancel();
      }
      _queuePersistDebounce = null;
    });

    Future.microtask(() async {
      updateSettings(ref.read(settingsProvider));
      await _initOutputDir();
      await _loadQueueFromStorage();
    });
    return const DownloadQueueState();
  }

  /// Flush any debounced queue persistence to disk immediately. Called when
  /// the app is backgrounded: the OS may kill the process without a graceful
  /// teardown, and a pending debounce timer would silently drop the most
  /// recent queue mutations.
  Future<void> flushQueuePersistence() async {
    if (_queuePersistDebounce?.isActive != true) return;
    _queuePersistDebounce?.cancel();
    await _flushQueueToStorage();
  }

  Future<void> _loadQueueFromStorage() async {
    if (_isLoaded) return;
    _isLoaded = true;

    try {
      await _appStateDb.migrateQueueFromSharedPreferences();
      final rows = await _appStateDb.getPendingDownloadQueueRows();
      if (rows.isEmpty) {
        _log.d('No queue found in storage');
        return;
      }

      final pendingItems = <DownloadItem>[];
      for (final row in rows) {
        final itemJson = row['item_json'] as String?;
        if (itemJson == null || itemJson.isEmpty) continue;

        try {
          final decoded = jsonDecode(itemJson);
          if (decoded is! Map) continue;
          var item = DownloadItem.fromJson(Map<String, dynamic>.from(decoded));
          final normalizedService = _normalizeQueuedService(item.service);
          if (normalizedService != item.service) {
            item = item.copyWith(service: normalizedService);
          }
          if (item.status == DownloadStatus.downloading ||
              item.status == DownloadStatus.finalizing) {
            item = item.copyWith(status: DownloadStatus.queued, progress: 0);
          }
          if (item.status == DownloadStatus.queued) {
            pendingItems.add(item);
          }
        } catch (_) {
          continue;
        }
      }

      if (pendingItems.isEmpty) {
        _log.d('No pending items to restore');
        await _appStateDb.replacePendingDownloadQueueRows(const []);
        return;
      }

      final normalizedPendingItems = _normalizeRestoredQueueIds(pendingItems);
      state = state.copyWith(items: normalizedPendingItems);
      _log.i(
        'Restored ${normalizedPendingItems.length} pending items from storage',
      );
      if (await _tryAdoptAndroidNativeWorkerSnapshot(normalizedPendingItems)) {
        return;
      }
      Future.microtask(() => _processQueue());
    } catch (e) {
      _log.e('Failed to load queue from storage: $e');
    }
  }

  /// Completes when the app is in the foreground. Verification challenges
  /// can only be handled there: launching a browser from the background is
  /// blocked by the OS and the challenge would expire unseen.
  Future<void> _waitForForeground() async {
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      return;
    }
    final completer = Completer<void>();
    final listener = AppLifecycleListener(
      onResume: () {
        if (!completer.isCompleted) completer.complete();
      },
    );
    try {
      await completer.future;
    } finally {
      listener.dispose();
    }
  }

  Future<bool> _openVerificationAndWait(String extensionId) {
    return openVerificationAndAwaitGrant(
      extensionId,
      browserMode: ref.read(settingsProvider).extensionVerificationBrowserMode,
      awaitForeground: (normalizedExtensionId) async {
        if (WidgetsBinding.instance.lifecycleState !=
            AppLifecycleState.resumed) {
          _log.i(
            'Verification required for $normalizedExtensionId while app is in '
            'background; deferring challenge until the app is foregrounded',
          );
          unawaited(_notificationService.showVerificationRequired());
          await _waitForForeground();
        }
      },
    );
  }

  Future<bool> _handleVerificationRequiredDownload(
    DownloadItem item,
    String errorMsg,
    String? verificationService,
  ) async {
    final targetService = (verificationService ?? '').trim().isNotEmpty
        ? verificationService!.trim()
        : item.service;
    final verificationRetryKey = _verificationRetryKey(item.id, targetService);
    if (_verificationRetriedItemIds.contains(verificationRetryKey)) {
      _log.e(
        'Verification was already completed once for ${item.track.name} on $targetService; not opening another challenge',
      );
      updateItemStatus(
        item.id,
        DownloadStatus.failed,
        error: errorMsg,
        errorType: DownloadErrorType.verificationRequired,
      );
      _failedInSession++;
      return true;
    }
    _verificationRetriedItemIds.add(verificationRetryKey);

    _log.i(
      'Download for ${item.track.name} requires verification; waiting for $targetService grant',
    );
    updateItemStatus(
      item.id,
      DownloadStatus.downloading,
      error: 'Waiting for verification',
      errorType: DownloadErrorType.verificationRequired,
    );

    final verified = await _openVerificationAndWait(targetService);
    final current = _findItemById(item.id);
    if (current == null || _isLocallyCancelled(item.id, item: current)) {
      _log.i('Verification completed after item was removed or cancelled');
      return true;
    }

    if (verified) {
      _log.i(
        'Verification complete for $targetService; retrying ${item.track.name}',
      );
      updateItemStatus(
        item.id,
        DownloadStatus.queued,
        progress: 0,
        speedMBps: 0,
        error: 'Retrying after verification',
        errorType: DownloadErrorType.verificationRequired,
      );
      _saveQueueToStorage();
      return true;
    }

    _log.e('Verification did not complete for $targetService');
    updateItemStatus(
      item.id,
      DownloadStatus.failed,
      error: errorMsg,
      errorType: DownloadErrorType.verificationRequired,
    );
    _failedInSession++;
    return true;
  }

  Duration _rateLimitBackoffDelay(String errorMsg) {
    final lower = errorMsg.toLowerCase();
    final retryAfterMatch = RegExp(
      r'retry[- ]?after(?: seconds)?[:= ]+(\d+)',
      caseSensitive: false,
    ).firstMatch(lower);
    final parsedSeconds = retryAfterMatch == null
        ? null
        : int.tryParse(retryAfterMatch.group(1) ?? '');
    final seconds = (parsedSeconds ?? 30).clamp(5, 300).toInt();
    return Duration(seconds: seconds);
  }

  Future<bool> _handleRateLimitedDownload(
    DownloadItem item,
    String errorMsg,
  ) async {
    if (_rateLimitRetriedItemIds.contains(item.id)) {
      return false;
    }
    _rateLimitRetriedItemIds.add(item.id);

    final delay = _rateLimitBackoffDelay(errorMsg);
    _log.i(
      'Rate limited while downloading ${item.track.name}; retrying after ${delay.inSeconds}s',
    );
    updateItemStatus(
      item.id,
      DownloadStatus.downloading,
      error: 'Rate limited, retrying after ${delay.inSeconds}s',
      errorType: DownloadErrorType.rateLimit,
    );

    await Future<void>.delayed(delay);
    final current = _findItemById(item.id);
    if (current == null || _isLocallyCancelled(item.id, item: current)) {
      return true;
    }
    updateItemStatus(
      item.id,
      DownloadStatus.queued,
      progress: 0,
      speedMBps: 0,
      error: 'Retrying after rate limit',
      errorType: DownloadErrorType.rateLimit,
    );
    _saveQueueToStorage();
    return true;
  }

  void _saveQueueToStorage() {
    _queuePersistDebounce?.cancel();
    _queuePersistDebounce = Timer(_queuePersistDebounceDuration, () {
      _flushQueueToStorage();
    });
  }

  Future<void> _flushQueueToStorage() async {
    try {
      final pendingItems = state.items
          .where(
            (item) =>
                item.status == DownloadStatus.queued ||
                item.status == DownloadStatus.downloading ||
                item.status == DownloadStatus.finalizing,
          )
          .toList();

      if (pendingItems.isEmpty) {
        await _appStateDb.replacePendingDownloadQueueRows(const []);
        _log.d('Cleared queue storage (no pending items)');
      } else {
        final nowIso = DateTime.now().toIso8601String();
        final rows = pendingItems
            .map(
              (item) => <String, dynamic>{
                'id': item.id,
                'item_json': jsonEncode(item.toJson()),
                'status': item.status.name,
                'created_at': item.createdAt.toIso8601String(),
                'updated_at': nowIso,
              },
            )
            .toList(growable: false);
        await _appStateDb.replacePendingDownloadQueueRows(rows);
        _log.d('Saved ${pendingItems.length} pending items to storage');
      }
    } catch (e) {
      _log.e('Failed to save queue to storage: $e');
    }
  }

  void _startMultiProgressPolling() {
    _idleProgressPollTick = 0;
    _progressPoller.start(useStream: Platform.isAndroid || Platform.isIOS);
  }

  /// Idle-cadence gate for the fallback polling timer: polls every tick while
  /// a download is active, but only every [_idleProgressPollEveryTicks]th
  /// tick while idle-but-queued, and not at all while paused/empty.
  bool _shouldPollDownloadProgressTick() {
    final currentItems = state.items;
    final hasQueuedItems = currentItems.any(
      (item) => item.status == DownloadStatus.queued,
    );
    final hasActiveItems = currentItems.any(
      (item) =>
          item.status == DownloadStatus.downloading ||
          item.status == DownloadStatus.finalizing,
    );

    if (!hasActiveItems) {
      if (state.isPaused || !hasQueuedItems) {
        _idleProgressPollTick = 0;
        return false;
      }

      _idleProgressPollTick =
          (_idleProgressPollTick + 1) % _idleProgressPollEveryTicks;
      return _idleProgressPollTick == 0;
    }

    _idleProgressPollTick = 0;
    return true;
  }

  void _processAllDownloadProgress(Map<String, dynamic> allProgress) {
    final rawItems = allProgress['items'];
    final items = rawItems is Map
        ? rawItems.map((key, value) => MapEntry(key.toString(), value))
        : const <String, dynamic>{};
    final currentItems = state.items;
    final lookup = state.lookup;
    int queuedCount = 0;
    int downloadingCount = 0;
    DownloadItem? firstDownloading;
    bool hasFinalizingItem = false;
    String? finalizingTrackName;
    String? finalizingArtistName;
    for (int i = 0; i < currentItems.length; i++) {
      final item = currentItems[i];
      if (item.status == DownloadStatus.downloading) {
        downloadingCount++;
        firstDownloading ??= item;
      }
      if (item.status == DownloadStatus.queued ||
          item.status == DownloadStatus.downloading ||
          item.status == DownloadStatus.finalizing) {
        queuedCount++;
      }
      if (item.status == DownloadStatus.finalizing && !hasFinalizingItem) {
        hasFinalizingItem = true;
        finalizingTrackName = item.track.name;
        finalizingArtistName = item.track.artistName;
      }
    }
    final progressUpdates = <String, _ProgressUpdate>{};

    for (final entry in items.entries) {
      final itemId = entry.key;
      final localItem = lookup.byItemId[itemId];
      if (localItem == null) {
        continue;
      }
      if (_isPausePending(itemId)) {
        PlatformBridge.clearItemProgress(itemId).catchError((_) {});
        continue;
      }
      if (localItem.status == DownloadStatus.skipped) {
        PlatformBridge.clearItemProgress(itemId).catchError((_) {});
        continue;
      }
      if (localItem.status == DownloadStatus.completed ||
          localItem.status == DownloadStatus.failed) {
        continue;
      }
      if (localItem.status == DownloadStatus.finalizing) {
        PlatformBridge.clearItemProgress(itemId).catchError((_) {});
        hasFinalizingItem = true;
        finalizingTrackName = localItem.track.name;
        finalizingArtistName = localItem.track.artistName;
        continue;
      }
      final rawItemProgress = entry.value;
      if (rawItemProgress is! Map) {
        continue;
      }
      final itemProgress = Map<String, dynamic>.from(rawItemProgress);
      final bytesReceived =
          (itemProgress['bytes_received'] as num?)?.toInt() ?? 0;
      final bytesTotal = (itemProgress['bytes_total'] as num?)?.toInt() ?? 0;
      final speedMBps = (itemProgress['speed_mbps'] as num?)?.toDouble() ?? 0.0;
      final isDownloading = itemProgress['is_downloading'] as bool? ?? false;
      final status = itemProgress['status'] as String? ?? 'downloading';
      final progressFromBackend =
          (itemProgress['progress'] as num?)?.toDouble() ?? 0.0;
      final hasRealProgress =
          status != 'preparing' &&
          (bytesReceived > 0 || bytesTotal > 0 || progressFromBackend > 0);

      if (status == 'finalizing') {
        progressUpdates[itemId] = const _ProgressUpdate(
          status: DownloadStatus.finalizing,
          progress: 1.0,
        );
        hasFinalizingItem = true;
        finalizingTrackName = localItem.track.name;
        finalizingArtistName = localItem.track.artistName;
        continue;
      }

      if (status == 'preparing') {
        progressUpdates[itemId] = const _ProgressUpdate(
          status: DownloadStatus.downloading,
          progress: 0.0,
          speedMBps: 0,
          bytesReceived: 0,
          bytesTotal: 0,
        );

        if (LogBuffer.loggingEnabled) {
          _log.d('Preparing [$itemId]: waiting for real download bytes');
        }
        continue;
      }

      if (isDownloading || hasRealProgress) {
        double percentage = 0.0;
        if (bytesTotal > 0) {
          percentage = bytesReceived / bytesTotal;
        } else {
          percentage = progressFromBackend;
        }
        final normalizedProgress = _normalizeProgressForUi(percentage);
        final normalizedSpeed = _normalizeSpeedForUi(speedMBps);
        final normalizedBytes = _normalizeBytesForUi(bytesReceived);

        progressUpdates[itemId] = _ProgressUpdate(
          status: DownloadStatus.downloading,
          progress: normalizedProgress,
          speedMBps: normalizedSpeed,
          bytesReceived: normalizedBytes,
          bytesTotal: bytesTotal,
        );

        if (LogBuffer.loggingEnabled) {
          final mbReceived = bytesReceived / (1024 * 1024);
          final mbTotal = bytesTotal / (1024 * 1024);
          if (bytesTotal > 0) {
            _log.d(
              'Progress [$itemId]: ${(percentage * 100).toStringAsFixed(1)}% (${mbReceived.toStringAsFixed(2)}/${mbTotal.toStringAsFixed(2)} MB) @ ${speedMBps.toStringAsFixed(2)} MB/s',
            );
          } else {
            _log.d(
              'Progress [$itemId]: ${(percentage * 100).toStringAsFixed(1)}% (stream/unknown size) @ ${speedMBps.toStringAsFixed(2)} MB/s',
            );
          }
        }
      }
    }

    if (progressUpdates.isNotEmpty) {
      var updatedItems = currentItems;
      bool changed = false;
      final changedIndices = <int>[];

      for (final entry in progressUpdates.entries) {
        final index = lookup.indexByItemId[entry.key];
        if (index == null) continue;
        final current = updatedItems[index];
        if (current.status == DownloadStatus.skipped ||
            current.status == DownloadStatus.completed ||
            current.status == DownloadStatus.failed) {
          continue;
        }
        final update = entry.value;
        if (current.status == DownloadStatus.finalizing &&
            update.status != DownloadStatus.finalizing) {
          continue;
        }
        final next = current.copyWith(
          status: update.status,
          progress: update.progress,
          speedMBps: update.speedMBps ?? current.speedMBps,
          bytesReceived: update.bytesReceived ?? current.bytesReceived,
          bytesTotal: update.bytesTotal ?? current.bytesTotal,
        );
        if (current.status != next.status ||
            current.progress != next.progress ||
            current.speedMBps != next.speedMBps ||
            current.bytesReceived != next.bytesReceived ||
            current.bytesTotal != next.bytesTotal) {
          if (!changed) {
            updatedItems = List<DownloadItem>.from(updatedItems);
            changed = true;
          }
          updatedItems[index] = next;
          changedIndices.add(index);
        }
      }

      if (changed) {
        state = state.copyWith(
          items: updatedItems,
          lookup: state.lookup.updatedForIndices(
            previousItems: currentItems,
            nextItems: updatedItems,
            changedIndices: changedIndices,
          ),
        );
      }
    }

    if (hasFinalizingItem && finalizingTrackName != null) {
      final safeArtistName = finalizingArtistName ?? '';
      if (Platform.isAndroid) {
        _maybeUpdateAndroidDownloadService(
          trackName: finalizingTrackName,
          artistName: _notificationService.embeddingMetadataLabel,
          progress: 100,
          total: 100,
          queueCount: queuedCount,
          status: 'finalizing',
        );
      } else if (finalizingTrackName != _lastFinalizingTrackName ||
          safeArtistName != _lastFinalizingArtistName) {
        _notificationService.showDownloadFinalizing(
          trackName: finalizingTrackName,
          artistName: safeArtistName,
        );
        _lastFinalizingTrackName = finalizingTrackName;
        _lastFinalizingArtistName = safeArtistName;
      }
      return;
    }
    _lastFinalizingTrackName = null;
    _lastFinalizingArtistName = null;

    if (items.isNotEmpty) {
      if (downloadingCount > 0 && firstDownloading != null) {
        final rawProgress = items[firstDownloading.id];
        if (rawProgress is! Map) {
          return;
        }
        final selectedProgress = Map<String, dynamic>.from(rawProgress);
        final bytesReceived =
            (selectedProgress['bytes_received'] as num?)?.toInt() ?? 0;
        final bytesTotal =
            (selectedProgress['bytes_total'] as num?)?.toInt() ?? 0;
        final backendStatus =
            selectedProgress['status'] as String? ?? 'downloading';
        final trackName = downloadingCount == 1
            ? firstDownloading.track.name
            : '$downloadingCount downloads';
        final artistName = downloadingCount == 1
            ? firstDownloading.track.artistName
            : 'Downloading...';

        int notifProgress = bytesReceived;
        int notifTotal = bytesTotal;

        final progressPercent =
            (selectedProgress['progress'] as num?)?.toDouble() ?? 0.0;
        if (backendStatus == 'preparing') {
          notifProgress = 0;
          notifTotal = 0;
        } else if (bytesTotal <= 0) {
          notifProgress = (progressPercent * 100).toInt();
          notifTotal = 100;
        }
        final serviceStatus = notifTotal <= 0 ? 'preparing' : 'downloading';

        if (!Platform.isAndroid &&
            _shouldUpdateProgressNotification(
              trackName: trackName,
              artistName: artistName,
              progress: notifProgress,
              total: notifTotal,
              queueCount: queuedCount,
            )) {
          final safeNotifTotal = notifTotal > 0 ? notifTotal : 1;
          _notificationService.showDownloadProgress(
            trackName: trackName,
            artistName: artistName,
            progress: notifProgress,
            total: safeNotifTotal,
          );
        }

        if (Platform.isAndroid) {
          _maybeUpdateAndroidDownloadService(
            trackName: firstDownloading.track.name,
            artistName: firstDownloading.track.artistName,
            progress: notifProgress,
            total: notifTotal,
            queueCount: queuedCount,
            status: serviceStatus,
          );
        }
      }
    }
  }

  void _maybeUpdateAndroidDownloadService({
    required String trackName,
    required String artistName,
    required int progress,
    required int total,
    required int queueCount,
    String status = 'downloading',
  }) {
    final now = DateTime.now();
    final progressBucket = total <= 0
        ? -1
        : (() {
            final progressPercent = ((progress * 100) / total)
                .round()
                .clamp(0, 100)
                .toInt();
            return progressPercent == 100
                ? 100
                : ((progressPercent ~/ _serviceProgressStepPercent) *
                          _serviceProgressStepPercent)
                      .clamp(0, 100)
                      .toInt();
          })();

    final didContentChange =
        trackName != _lastServiceTrackName ||
        artistName != _lastServiceArtistName ||
        status != _lastServiceStatus ||
        queueCount != _lastServiceQueueCount ||
        progressBucket != _lastServicePercent;
    final allowHeartbeat =
        now.difference(_lastServiceUpdateAt) >= const Duration(seconds: 5);

    if (!didContentChange && !allowHeartbeat) {
      return;
    }

    _lastServiceTrackName = trackName;
    _lastServiceArtistName = artistName;
    _lastServiceStatus = status;
    _lastServicePercent = progressBucket;
    _lastServiceQueueCount = queueCount;
    _lastServiceUpdateAt = now;

    PlatformBridge.updateDownloadServiceProgress(
      trackName: trackName,
      artistName: artistName,
      progress: progress,
      total: total,
      queueCount: queueCount,
      status: status,
    ).catchError((_) {});
  }

  void _stopProgressPolling() {
    _progressPoller.stop();
    _idleProgressPollTick = 0;
    _lastServiceTrackName = null;
    _lastServiceArtistName = null;
    _lastServiceStatus = null;
    _lastServicePercent = -1;
    _lastServiceQueueCount = -1;
    _lastServiceUpdateAt = DateTime.fromMillisecondsSinceEpoch(0);
    _lastFinalizingTrackName = null;
    _lastFinalizingArtistName = null;
    _lastNotifTrackName = null;
    _lastNotifArtistName = null;
    _lastNotifPercent = -1;
    _lastNotifQueueCount = -1;
  }

  void setOutputDir(String dir) {
    state = state.copyWith(outputDir: dir);
  }

  bool _isSafMode(AppSettings settings) {
    return Platform.isAndroid &&
        settings.storageMode == 'saf' &&
        settings.downloadTreeUri.isNotEmpty;
  }

  bool _isSafWriteFailure(Map<String, dynamic> result) {
    final error = (result['error'] ?? result['message'] ?? '')
        .toString()
        .toLowerCase();
    if (error.isEmpty) return false;
    return error.contains('saf') ||
        error.contains('content uri') ||
        error.contains('permission denied') ||
        error.contains('documentfile');
  }

  String _normalizeQueuedService(String service) {
    final normalized = service.trim();
    if (normalized.isEmpty) {
      return normalized;
    }

    final replacement = ref
        .read(extensionProvider.notifier)
        .replacedBuiltInDownloadProviderFor(normalized);
    if (replacement != null && replacement.isNotEmpty) {
      return replacement;
    }

    return normalized;
  }

  bool _hasActiveDownloadProvider(String service) {
    final normalized = service.trim();
    if (normalized.isEmpty) {
      return false;
    }

    final extensionState = ref.read(extensionProvider);
    return extensionState.extensions.any(
      (ext) =>
          ext.enabled &&
          ext.hasDownloadProvider &&
          ext.id.toLowerCase() == normalized.toLowerCase(),
    );
  }

  /// Builds the backend [DownloadRequestPayload] shared by the native-worker
  /// request builder and the inline single-item download path. Fields whose
  /// source value legitimately differs between the two callers (SAF staging,
  /// download strategy) are left as parameters.
  DownloadRequestPayload _buildDownloadRequestPayload({
    required Track track,
    required DownloadItem item,
    required AppSettings settings,
    required ExtensionState extensionState,
    required String quality,
    required String filenameFormat,
    required String outputDir,
    required String outputExt,
    required bool useSaf,
    String? safFileName,
    String? deezerTrackId,
    String? genre,
    String? label,
    String? copyright,
    bool stageSafForDeferredPublish = false,
  }) {
    final resolvedAlbumArtist = _resolveAlbumArtistForMetadata(track, settings);
    final postProcessingEnabled =
        settings.useExtensionProviders &&
        extensionState.extensions.any((e) => e.enabled && e.hasPostProcessing);
    final normalizedTrackNumber =
        (track.trackNumber != null && track.trackNumber! > 0)
        ? track.trackNumber!
        : 0;
    final normalizedDiscNumber =
        (track.discNumber != null && track.discNumber! > 0)
        ? track.discNumber!
        : 0;

    String payloadSpotifyId = track.id;
    String payloadQobuzId = '';
    String payloadTidalId = '';
    if (track.id.startsWith('qobuz:')) {
      payloadQobuzId = track.id.substring(6);
      if (_downloadProviderReplacesLegacyProvider(item.service, 'qobuz')) {
        payloadSpotifyId = '';
      }
    }
    if (track.id.startsWith('tidal:')) {
      payloadTidalId = track.id.substring(6);
      if (_downloadProviderReplacesLegacyProvider(item.service, 'tidal')) {
        payloadSpotifyId = '';
      }
    }

    return DownloadRequestPayload(
      isrc: track.isrc ?? '',
      service: item.service,
      spotifyId: payloadSpotifyId,
      trackName: track.name,
      artistName: track.artistName,
      albumName: track.albumName,
      albumArtist: resolvedAlbumArtist ?? '',
      coverUrl: settings.embedMetadata ? (track.coverUrl ?? '') : '',
      outputDir: outputDir,
      filenameFormat: filenameFormat,
      quality: quality,
      embedMetadata: settings.embedMetadata,
      artistTagMode: settings.artistTagMode,
      embedLyrics:
          settings.embedMetadata &&
          settings.embedLyrics &&
          !_shouldSkipLyrics(extensionState, track.source, item.service),
      embedMaxQualityCover: settings.embedMetadata && settings.maxQualityCover,
      embedReplayGain: settings.embedReplayGain,
      postProcessingEnabled: postProcessingEnabled,
      tidalHighFormat: settings.tidalHighFormat,
      trackNumber: normalizedTrackNumber,
      playlistPosition: _validPlaylistPosition(item),
      discNumber: normalizedDiscNumber,
      totalTracks: track.totalTracks ?? 0,
      totalDiscs: track.totalDiscs ?? 0,
      releaseDate: track.releaseDate ?? '',
      itemId: item.id,
      durationMs: track.duration * 1000,
      source: track.source ?? '',
      genre: genre ?? '',
      label: label ?? '',
      copyright: copyright ?? '',
      composer: track.composer ?? '',
      qobuzId: payloadQobuzId,
      tidalId: payloadTidalId,
      deezerId: deezerTrackId ?? '',
      lyricsMode: settings.lyricsMode,
      storageMode: useSaf ? 'saf' : 'app',
      safTreeUri: useSaf ? settings.downloadTreeUri : '',
      safRelativeDir: useSaf ? outputDir : '',
      safFileName: useSaf ? (safFileName ?? '') : '',
      safOutputExt: useSaf ? outputExt : '',
      outputExt: outputExt,
      stageSafOutput: stageSafForDeferredPublish,
      deferSafPublish: stageSafForDeferredPublish,
      requiresContainerConversion: _shouldRequestContainerConversion(
        item.service,
        outputExt,
      ),
      songLinkRegion: settings.songLinkRegion,
    );
  }

  String _newQueueItemId(Track track, {Set<String>? takenIds}) {
    final trimmedIsrc = track.isrc?.trim();
    final trimmedTrackId = track.id.trim();
    final base = (trimmedIsrc != null && trimmedIsrc.isNotEmpty)
        ? trimmedIsrc
        : (trimmedTrackId.isNotEmpty ? trimmedTrackId : 'track');

    while (true) {
      _queueItemSequence++;
      final candidate =
          '$base-${DateTime.now().microsecondsSinceEpoch}-$_queueItemSequence';
      if (takenIds == null || !takenIds.contains(candidate)) {
        return candidate;
      }
    }
  }

  List<DownloadItem> _normalizeRestoredQueueIds(List<DownloadItem> items) {
    if (items.isEmpty) return items;

    final seen = <String>{};
    var regeneratedCount = 0;
    final normalized = <DownloadItem>[];

    for (final item in items) {
      final trimmedId = item.id.trim();
      final shouldRegenerate = trimmedId.isEmpty || seen.contains(trimmedId);
      if (shouldRegenerate) {
        final newId = _newQueueItemId(item.track, takenIds: seen);
        seen.add(newId);
        normalized.add(item.copyWith(id: newId));
        regeneratedCount++;
      } else {
        seen.add(trimmedId);
        normalized.add(item);
      }
    }

    if (regeneratedCount > 0) {
      _log.w(
        'Regenerated $regeneratedCount duplicate/empty queue item IDs during restore',
      );
    }

    return normalized;
  }

  void updateSettings(AppSettings settings) {
    state = state.copyWith(
      outputDir: settings.downloadDirectory.isNotEmpty
          ? settings.downloadDirectory
          : state.outputDir,
      filenameFormat: settings.filenameFormat,
      singleFilenameFormat: settings.singleFilenameFormat,
      audioQuality: settings.audioQuality,
      autoFallback: settings.autoFallback,
    );
  }

  String addToQueue(
    Track track,
    String service, {
    String? qualityOverride,
    String? playlistName,
    int? playlistPosition,
  }) {
    final settings = ref.read(settingsProvider);
    updateSettings(settings);

    final takenIds = state.items.map((item) => item.id).toSet();
    final id = _newQueueItemId(track, takenIds: takenIds);
    final item = DownloadItem(
      id: id,
      track: track,
      service: _normalizeQueuedService(service),
      createdAt: DateTime.now(),
      qualityOverride: qualityOverride,
      playlistName: playlistName,
      playlistPosition: playlistPosition,
    );

    state = state.copyWith(items: [...state.items, item]);
    _saveQueueToStorage();

    if (!state.isProcessing) {
      Future.microtask(() => _processQueue());
    }

    return id;
  }

  void addMultipleToQueue(
    List<Track> tracks,
    String service, {
    String? qualityOverride,
    String? playlistName,
    List<int?>? playlistPositions,
  }) {
    final settings = ref.read(settingsProvider);
    updateSettings(settings);

    final takenIds = state.items.map((item) => item.id).toSet();
    final shouldAssignPlaylistPositions =
        playlistName != null && playlistName.trim().isNotEmpty;
    final fromBatch = tracks.length > 1;
    final newItems = tracks.asMap().entries.map((entry) {
      final track = entry.value;
      final index = entry.key;
      final explicitPosition =
          playlistPositions != null &&
              index < playlistPositions.length &&
              (playlistPositions[index] ?? 0) > 0
          ? playlistPositions[index]
          : null;
      final id = _newQueueItemId(track, takenIds: takenIds);
      takenIds.add(id);
      return DownloadItem(
        id: id,
        track: track,
        service: _normalizeQueuedService(service),
        createdAt: DateTime.now(),
        qualityOverride: qualityOverride,
        playlistName: playlistName,
        playlistPosition:
            explicitPosition ??
            (shouldAssignPlaylistPositions ? index + 1 : null),
        fromBatch: fromBatch,
      );
    }).toList();

    state = state.copyWith(items: [...state.items, ...newItems]);
    _saveQueueToStorage();

    if (!state.isProcessing) {
      Future.microtask(() => _processQueue());
    }
  }

  void updateItemStatus(
    String id,
    DownloadStatus status, {
    double? progress,
    double? speedMBps,
    String? filePath,
    String? error,
    DownloadErrorType? errorType,
  }) {
    final items = state.items;
    final index = state.lookup.indexByItemId[id] ?? -1;
    if (index == -1) return;

    final current = items[index];
    final next = current.copyWith(
      status: status,
      progress: progress ?? current.progress,
      speedMBps: speedMBps ?? current.speedMBps,
      filePath: filePath,
      error: error,
      errorType: errorType,
    );

    if (current.status == next.status &&
        current.progress == next.progress &&
        current.speedMBps == next.speedMBps &&
        current.filePath == next.filePath &&
        current.error == next.error &&
        current.errorType == next.errorType) {
      return;
    }

    final updatedItems = List<DownloadItem>.from(items);
    updatedItems[index] = next;
    state = state.copyWith(items: updatedItems);

    if (Platform.isAndroid && status == DownloadStatus.finalizing) {
      PlatformBridge.clearItemProgress(id).catchError((_) {});
      final queueCount = updatedItems
          .where(
            (entry) =>
                entry.status == DownloadStatus.queued ||
                entry.status == DownloadStatus.downloading ||
                entry.status == DownloadStatus.finalizing,
          )
          .length;
      _maybeUpdateAndroidDownloadService(
        trackName: next.track.name,
        artistName: _notificationService.embeddingMetadataLabel,
        progress: 100,
        total: 100,
        queueCount: queueCount,
        status: 'finalizing',
      );
    }

    if (status == DownloadStatus.completed ||
        status == DownloadStatus.failed ||
        status == DownloadStatus.skipped) {
      _saveQueueToStorage();
    }
  }

  void updateProgress(String id, double progress, {double? speedMBps}) {
    final item = state.lookup.byItemId[id];
    if (item == null) return;
    if (item.status == DownloadStatus.skipped ||
        item.status == DownloadStatus.completed ||
        item.status == DownloadStatus.failed) {
      return;
    }
    updateItemStatus(
      id,
      DownloadStatus.downloading,
      progress: progress,
      speedMBps: speedMBps,
    );
  }

  DownloadItem? _findItemById(String id) {
    return state.lookup.byItemId[id];
  }

  bool _isLocallyCancelled(String id, {DownloadItem? item}) {
    if (_locallyCancelledItemIds.contains(id)) return true;
    final resolved = item ?? _findItemById(id);
    return resolved?.status == DownloadStatus.skipped;
  }

  bool _isPausePending(String id) => _pausePendingItemIds.contains(id);

  void _requeueItemForPause(String id) {
    final updatedItems = state.items
        .map((item) {
          if (item.id != id) return item;
          if (item.status == DownloadStatus.completed ||
              item.status == DownloadStatus.failed ||
              item.status == DownloadStatus.skipped) {
            return item;
          }
          return item.copyWith(
            status: DownloadStatus.queued,
            progress: 0,
            speedMBps: 0,
            bytesReceived: 0,
            bytesTotal: 0,
          );
        })
        .toList(growable: false);

    final currentDownload = state.currentDownload?.id == id
        ? null
        : state.currentDownload;
    state = state.copyWith(
      items: updatedItems,
      currentDownload: currentDownload,
    );
  }

  void _requestNativeCancel(String id) {
    PlatformBridge.cancelDownload(id).catchError((_) {});
    PlatformBridge.clearItemProgress(id).catchError((_) {});
  }

  void cancelItem(String id) {
    _pausePendingItemIds.remove(id);
    _locallyCancelledItemIds.add(id);
    updateItemStatus(id, DownloadStatus.skipped);
    _requestNativeCancel(id);
  }

  void dismissItem(String id) {
    final item = _findItemById(id);
    if (item == null) return;

    final isActive =
        item.status == DownloadStatus.queued ||
        item.status == DownloadStatus.downloading ||
        item.status == DownloadStatus.finalizing;
    final wasFailed =
        item.status == DownloadStatus.failed ||
        item.status == DownloadStatus.skipped;

    if (isActive) {
      _pausePendingItemIds.remove(id);
      _locallyCancelledItemIds.add(id);
      _requestNativeCancel(id);
    } else {
      _locallyCancelledItemIds.remove(id);
    }

    if (item.status != DownloadStatus.completed) {
      _purgeAlbumRgEntry(item.track);
    }

    final items = state.items.where((entry) => entry.id != id).toList();
    final currentDownload = state.currentDownload?.id == id
        ? null
        : state.currentDownload;
    state = state.copyWith(items: items, currentDownload: currentDownload);
    _saveQueueToStorage();

    // Dismissing a failed/skipped item may unblock album RG.
    if (wasFailed) {
      _retriggerAlbumRgChecks();
    }
  }

  void clearCompleted() {
    final removedItems = state.items.where(
      (item) =>
          item.status == DownloadStatus.completed ||
          item.status == DownloadStatus.failed ||
          item.status == DownloadStatus.skipped,
    );
    bool hadFailedOrSkipped = false;
    for (final item in removedItems) {
      if (item.status == DownloadStatus.failed ||
          item.status == DownloadStatus.skipped) {
        hadFailedOrSkipped = true;
        _purgeAlbumRgEntry(item.track);
      }
    }

    final items = state.items
        .where(
          (item) =>
              item.status != DownloadStatus.completed &&
              item.status != DownloadStatus.failed &&
              item.status != DownloadStatus.skipped,
        )
        .toList();

    state = state.copyWith(items: items);
    _saveQueueToStorage();

    if (hadFailedOrSkipped) {
      _retriggerAlbumRgChecks();
    }
  }

  void clearAll() {
    final wasProcessing = state.isProcessing;
    final activeIds = state.items
        .where(
          (item) =>
              item.status == DownloadStatus.queued ||
              item.status == DownloadStatus.downloading ||
              item.status == DownloadStatus.finalizing,
        )
        .map((item) => item.id)
        .toList(growable: false);

    if (activeIds.isNotEmpty) {
      _pausePendingItemIds.addAll(activeIds);
      _locallyCancelledItemIds.addAll(activeIds);
      for (final id in activeIds) {
        _requestNativeCancel(id);
      }
    }

    state = state.copyWith(items: [], isPaused: false, currentDownload: null);
    if (Platform.isAndroid &&
        ref.read(settingsProvider).nativeDownloadWorkerEnabled) {
      PlatformBridge.cancelNativeDownloadWorker().catchError((_) {});
    }
    _notificationService.cancelDownloadNotification();
    _saveQueueToStorage();
    _albumRgData.clear();
    if (!wasProcessing) {
      _locallyCancelledItemIds.clear();
    }
    _pausePendingItemIds.clear();
  }

  void pauseQueue() {
    if (state.isProcessing && !state.isPaused) {
      if (Platform.isAndroid &&
          ref.read(settingsProvider).nativeDownloadWorkerEnabled) {
        PlatformBridge.pauseNativeDownloadWorker().catchError((_) {});
      }
      final activeIds = state.items
          .where(
            (item) =>
                item.status == DownloadStatus.downloading ||
                item.status == DownloadStatus.finalizing,
          )
          .map((item) => item.id)
          .toSet();

      if (activeIds.isNotEmpty) {
        _pausePendingItemIds.addAll(activeIds);
        for (final id in activeIds) {
          _requestNativeCancel(id);
          _requeueItemForPause(id);
        }
      }

      state = state.copyWith(isPaused: true, currentDownload: null);
      _notificationService.cancelDownloadNotification();
      _log.i('Queue paused');
    }
  }

  void resumeQueue() {
    if (state.isPaused) {
      if (Platform.isAndroid &&
          ref.read(settingsProvider).nativeDownloadWorkerEnabled) {
        PlatformBridge.resumeNativeDownloadWorker().catchError((_) {});
      }
      state = state.copyWith(isPaused: false);
      _log.i('Queue resumed');
      if (state.queuedCount > 0 && !state.isProcessing) {
        Future.microtask(() => _processQueue());
      }
    }
  }

  void togglePause() {
    if (state.isPaused) {
      resumeQueue();
    } else {
      pauseQueue();
    }
  }

  void retryItem(String id) {
    final item = state.items.where((i) => i.id == id).firstOrNull;
    if (item == null) {
      _log.w('retryItem: Item not found: $id');
      return;
    }

    if (item.status != DownloadStatus.failed &&
        item.status != DownloadStatus.skipped) {
      _log.w('retryItem: Item status is ${item.status}, not retrying');
      return;
    }

    _log.i('Retrying item: ${item.track.name} (id: $id)');
    // A cancel issued while the item never started leaves a pre-registered
    // flag in the Go backend that the next attempt would consume and abort
    // instantly; the user asked for a retry, so drop it first.
    unawaited(
      PlatformBridge.resetDownloadCancel(id).catchError((Object e) {
        _log.w('Failed to reset cancel flag for $id: $e');
      }),
    );
    _locallyCancelledItemIds.remove(id);
    _verificationRetriedItemIds.removeWhere(
      (retryKey) => retryKey == id || retryKey.startsWith('$id::'),
    );
    _rateLimitRetriedItemIds.remove(id);

    // Purge stale ReplayGain entry for this track so a re-scan doesn't
    // produce duplicate entries that bias album gain.
    _purgeAlbumRgEntry(item.track);

    final items = state.items.map((i) {
      if (i.id == id) {
        return i.copyWith(
          status: DownloadStatus.queued,
          progress: 0,
          error: null,
        );
      }
      return i;
    }).toList();
    state = state.copyWith(items: items);
    _saveQueueToStorage();

    if (!state.isProcessing) {
      _log.d('Starting queue processing for retry');
      Future.microtask(() => _processQueue());
    } else {
      _log.d('Queue already processing, item will be picked up');
    }
  }

  void retryAllFailed() {
    final failedIds = state.items
        .where(
          (item) =>
              item.status == DownloadStatus.failed ||
              item.status == DownloadStatus.skipped,
        )
        .map((item) => item.id)
        .toSet();
    if (failedIds.isEmpty) {
      _log.d('retryAllFailed: no failed downloads to retry');
      return;
    }

    _log.i('Retrying ${failedIds.length} failed download(s)');
    for (final id in failedIds) {
      unawaited(
        PlatformBridge.resetDownloadCancel(id).catchError((Object e) {
          _log.w('Failed to reset cancel flag for $id: $e');
        }),
      );
    }
    _locallyCancelledItemIds.removeAll(failedIds);
    _pausePendingItemIds.removeAll(failedIds);

    for (final item in state.items) {
      if (!failedIds.contains(item.id)) continue;
      _purgeAlbumRgEntry(item.track);
    }

    final items = state.items
        .map((item) {
          if (!failedIds.contains(item.id)) return item;
          return item.copyWith(
            status: DownloadStatus.queued,
            progress: 0,
            speedMBps: 0,
            bytesReceived: 0,
            bytesTotal: 0,
            error: null,
          );
        })
        .toList(growable: false);

    state = state.copyWith(items: items, isPaused: false);
    _saveQueueToStorage();

    if (!state.isProcessing) {
      Future.microtask(() => _processQueue());
    }
  }

  void removeItem(String id) {
    final removedItem = state.items.where((item) => item.id == id).firstOrNull;
    _locallyCancelledItemIds.remove(id);
    final items = state.items.where((item) => item.id != id).toList();
    state = state.copyWith(items: items);
    _saveQueueToStorage();

    // Clean stale album RG entries when a track is removed from the queue.
    // Only purge for items that were NOT completed — completed items' RG data
    // must survive removal because album gain is computed after the last track
    // finishes, by which time earlier completed tracks have been removed.
    if (removedItem != null && removedItem.status != DownloadStatus.completed) {
      _purgeAlbumRgEntry(removedItem.track);
      // Removing a failed/skipped item may unblock album RG for the album.
      _retriggerAlbumRgChecks();
    }
  }

  Future<String?> exportFailedDownloads() async {
    final failedItems = state.items
        .where((item) => item.status == DownloadStatus.failed)
        .toList();

    if (failedItems.isEmpty) {
      _log.d('No failed downloads to export');
      return null;
    }

    try {
      String baseDir = state.outputDir;
      if (baseDir.isEmpty) {
        final dir = await getApplicationDocumentsDirectory();
        baseDir = dir.path;
      }

      final failedDownloadsDir = '$baseDir/failed_downloads';
      final failedDir = Directory(failedDownloadsDir);
      if (!await failedDir.exists()) {
        await failedDir.create(recursive: true);
      }

      // Use date-only format for daily grouping (YYYY-MM-DD)
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final fileName = 'failed_downloads_$dateStr.txt';
      final filePath = '$failedDownloadsDir/$fileName';

      final file = File(filePath);
      final bool fileExists = await file.exists();

      final buffer = StringBuffer();

      if (!fileExists) {
        buffer.writeln('# SpotiFLAC Failed Downloads');
        buffer.writeln('# Date: $dateStr');
        buffer.writeln('#');
        buffer.writeln('# Format: [Time] Track - Artist | URL | Error');
        buffer.writeln('');
      }

      final timeStr =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      for (final item in failedItems) {
        final track = item.track;
        final spotifyUrl = track.id.startsWith('deezer:')
            ? 'https://www.deezer.com/track/${track.id.substring(7)}'
            : 'https://open.spotify.com/track/${track.id}';
        final error = item.error ?? 'Unknown error';
        buffer.writeln(
          '[$timeStr] ${track.name} - ${track.artistName} | $spotifyUrl | $error',
        );
      }

      if (fileExists) {
        await file.writeAsString(buffer.toString(), mode: FileMode.append);
        _log.i('Appended ${failedItems.length} failed downloads to: $filePath');
      } else {
        await file.writeAsString(buffer.toString());
        _log.i('Created new failed downloads file: $filePath');
      }

      return filePath;
    } catch (e) {
      _log.e('Failed to export failed downloads: $e');
      return null;
    }
  }

  void clearFailedDownloads() {
    final failedItems = state.items
        .where((item) => item.status == DownloadStatus.failed)
        .toList();
    for (final item in failedItems) {
      _purgeAlbumRgEntry(item.track);
    }

    final items = state.items
        .where((item) => item.status != DownloadStatus.failed)
        .toList();
    state = state.copyWith(items: items);
    _saveQueueToStorage();
    _log.d('Cleared failed downloads from queue');

    // Removing failed items may unblock album RG for affected albums.
    if (failedItems.isNotEmpty) {
      _retriggerAlbumRgChecks();
    }
  }

  Future<String?> _runPostProcessingHooks(String filePath, Track track) async {
    try {
      final settings = ref.read(settingsProvider);
      final extensionState = ref.read(extensionProvider);
      final resolvedAlbumArtist = _resolveAlbumArtistForMetadata(
        track,
        settings,
      );

      if (!settings.useExtensionProviders) return null;

      final hasPostProcessing = extensionState.extensions.any(
        (e) => e.enabled && e.hasPostProcessing,
      );
      if (!hasPostProcessing) return null;

      _log.d('Running post-processing hooks on: $filePath');

      final metadata = <String, dynamic>{
        'title': track.name,
        'artist': track.artistName,
        'album': track.albumName,
        'track_number': track.trackNumber ?? 0,
        'disc_number': track.discNumber ?? 0,
        'isrc': track.isrc ?? '',
        'release_date': track.releaseDate ?? '',
        'duration_ms': track.duration * 1000,
        'cover_url': track.coverUrl ?? '',
      };
      if (resolvedAlbumArtist != null) {
        metadata['album_artist'] = resolvedAlbumArtist;
      }

      final result = await PlatformBridge.runPostProcessingV2(
        filePath,
        metadata: metadata,
      );

      if (result['success'] == true) {
        final hooksRun = result['hooks_run'] as int? ?? 0;
        final newPath = result['file_path'] as String?;
        _log.i('Post-processing completed: $hooksRun hook(s) executed');

        if (newPath != null && newPath != filePath) {
          _log.d('File path changed by post-processing: $newPath');
          return newPath;
        }
        return filePath;
      } else {
        final error = result['error'] as String? ?? 'Unknown error';
        _log.w('Post-processing failed: $error');
      }
    } catch (e) {
      _log.w('Post-processing error: $e');
    }
    return null;
  }

  bool _hasWifiConnection(List<ConnectivityResult> results) {
    return results.contains(ConnectivityResult.wifi);
  }

  void _startConnectivityMonitoring() {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen(
      _handleConnectivityResults,
      onError: (Object error, StackTrace stackTrace) {
        _log.w('Connectivity monitoring failed: $error');
      },
      cancelOnError: false,
    );
  }

  void _stopConnectivityMonitoring({bool clearNetworkPause = true}) {
    _connectivitySub?.cancel();
    _connectivitySub = null;
    if (clearNetworkPause) {
      _networkPausedByWifiOnly = false;
    }
  }

  void _handleDownloadNetworkModeChanged(String mode) {
    if (mode == 'wifi_only') {
      if (state.isProcessing || _networkPausedByWifiOnly) {
        _startConnectivityMonitoring();
      }
      return;
    }

    final shouldResume = _networkPausedByWifiOnly && state.isPaused;
    // Keep monitoring active in every mode while downloading so idle
    // connections are still recycled when the network switches.
    if (state.isProcessing) {
      _networkPausedByWifiOnly = false;
      _startConnectivityMonitoring();
    } else {
      _stopConnectivityMonitoring();
    }
    if (shouldResume) {
      resumeQueue();
    }
  }

  /// Closes idle backend HTTP connections when the connectivity set changes
  /// (e.g. WiFi <-> cellular). Stale sockets bound to the old interface would
  /// otherwise be reused, stalling the first request after a network switch.
  /// Applies to every download network mode. Fire-and-forget with a light
  /// debounce so network flapping does not spam the bridge.
  void _maybeCleanupOnNetworkChange(List<ConnectivityResult> results) {
    final previous = _lastConnectivityResults;
    final unchanged =
        previous != null && _connectivitySetEquals(previous, results);
    _lastConnectivityResults = List<ConnectivityResult>.unmodifiable(results);
    if (previous == null || unchanged) return;

    final now = DateTime.now();
    if (now.difference(_lastConnectionCleanupAt) < _connectionCleanupDebounce) {
      return;
    }
    _lastConnectionCleanupAt = now;

    _log.i('Network changed, closing idle backend connections');
    unawaited(
      PlatformBridge.cleanupConnections().catchError((Object e) {
        _log.w('Failed to clean up connections after network change: $e');
      }),
    );
  }

  bool _connectivitySetEquals(
    List<ConnectivityResult> a,
    List<ConnectivityResult> b,
  ) {
    final setA = a.toSet();
    final setB = b.toSet();
    return setA.length == setB.length && setA.containsAll(setB);
  }

  void _handleConnectivityResults(List<ConnectivityResult> results) {
    _maybeCleanupOnNetworkChange(results);

    final settings = ref.read(settingsProvider);
    if (settings.downloadNetworkMode != 'wifi_only') return;

    if (_hasWifiConnection(results)) {
      if (_networkPausedByWifiOnly && state.isPaused) {
        _networkPausedByWifiOnly = false;
        _log.i('WiFi restored, resuming network-paused queue');
        resumeQueue();
      }
      return;
    }

    if (state.isProcessing && !state.isPaused) {
      _networkPausedByWifiOnly = true;
      _log.w('WiFi connection lost, pausing active queue');
      pauseQueue();
    }
  }

  DownloadErrorType _downloadErrorTypeFromBackend(String? errorType) {
    switch (errorType) {
      case 'not_found':
        return DownloadErrorType.notFound;
      case 'rate_limit':
        return DownloadErrorType.rateLimit;
      case 'network':
        return DownloadErrorType.network;
      case 'permission':
        return DownloadErrorType.permission;
      case 'verification_required':
        return DownloadErrorType.verificationRequired;
      default:
        return DownloadErrorType.unknown;
    }
  }

  DownloadErrorType _downloadErrorTypeFromMessage(String errorMsg) {
    final lowerMsg = errorMsg.toLowerCase();
    if (isExtensionVerificationRequired(errorMsg)) {
      return DownloadErrorType.verificationRequired;
    }
    if (errorMsg.contains('429') ||
        lowerMsg.contains('rate limit') ||
        lowerMsg.contains('too many requests')) {
      return DownloadErrorType.rateLimit;
    }
    if (lowerMsg.contains('not found') ||
        lowerMsg.contains('not available') ||
        lowerMsg.contains('no results')) {
      return DownloadErrorType.notFound;
    }
    if (lowerMsg.contains('permission') ||
        lowerMsg.contains('operation not permitted') ||
        lowerMsg.contains('access denied')) {
      return DownloadErrorType.permission;
    }
    if (lowerMsg.contains('network') ||
        lowerMsg.contains('connection') ||
        lowerMsg.contains('timeout') ||
        lowerMsg.contains('dial')) {
      return DownloadErrorType.network;
    }
    return DownloadErrorType.unknown;
  }

  Future<void> _processQueue() async {
    if (state.isProcessing) return;

    final settings = ref.read(settingsProvider);
    updateSettings(settings);
    final isSafMode = _isSafMode(settings);
    var iosDownloadBookmarkActive = false;
    if (settings.downloadNetworkMode == 'wifi_only') {
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasWifi = connectivityResult.contains(ConnectivityResult.wifi);
      if (!hasWifi) {
        _log.w('WiFi-only mode enabled but no WiFi connection. Queue paused.');
        _networkPausedByWifiOnly = true;
        _startConnectivityMonitoring();
        state = state.copyWith(isProcessing: false, isPaused: true);
        return;
      }
    }
    // Monitor in every mode so idle connections are recycled on a network
    // switch, even though only wifi_only pauses the queue.
    _networkPausedByWifiOnly = false;
    _startConnectivityMonitoring();

    if (await _tryProcessQueueWithAndroidNativeWorker(settings)) {
      return;
    }

    state = state.copyWith(isProcessing: true);
    _log.i('Starting queue processing...');

    _totalQueuedAtStart = state.items
        .where((i) => i.status == DownloadStatus.queued)
        .length;
    _completedInSession = 0;
    _failedInSession = 0;

    if (Platform.isAndroid && _totalQueuedAtStart > 0) {
      final firstItem = state.items.firstWhere(
        (item) => item.status == DownloadStatus.queued,
        orElse: () => state.items.first,
      );
      try {
        await _notificationService.cancelDownloadNotification();
        await PlatformBridge.startDownloadService(
          trackName: firstItem.track.name,
          artistName: firstItem.track.artistName,
          queueCount: _totalQueuedAtStart,
        );
        _log.d('Foreground service started');
      } catch (e) {
        _log.e('Failed to start foreground service: $e');
      }
    }

    // iOS: request a background execution window (no foreground service).
    if (Platform.isIOS && _totalQueuedAtStart > 0) {
      await PlatformBridge.beginBackgroundDownloadTask();
    }

    if (!isSafMode && state.outputDir.isEmpty) {
      _log.d('Output dir empty, initializing...');
      await _initOutputDir();
    }

    // iOS: Validate that outputDir is writable (not iCloud Drive which Go can't access)
    if (!isSafMode && Platform.isIOS && state.outputDir.isNotEmpty) {
      final isICloudPath =
          state.outputDir.contains('Mobile Documents') ||
          state.outputDir.contains('CloudDocs') ||
          state.outputDir.contains('com~apple~CloudDocs');
      if (isICloudPath) {
        _log.w(
          'iOS: iCloud Drive path detected, falling back to app Documents folder',
        );
        _log.w('Go backend cannot write to iCloud Drive due to iOS sandboxing');
        final musicDir = await _ensureDefaultDocumentsOutputDir();
        state = state.copyWith(outputDir: musicDir.path);
        ref.read(settingsProvider.notifier).setDownloadDirectory(musicDir.path);
      } else if (!isValidIosWritablePath(state.outputDir)) {
        _log.w(
          'iOS: Invalid output path detected (container root?), falling back to app Documents folder',
        );
        _log.w('Original path: ${state.outputDir}');
        final correctedPath = await validateOrFixIosPath(state.outputDir);
        _log.i('Corrected path: $correctedPath');
        state = state.copyWith(outputDir: correctedPath);
        ref.read(settingsProvider.notifier).setDownloadDirectory(correctedPath);
      }
    }

    if (!isSafMode && state.outputDir.isEmpty) {
      _log.d('Using fallback directory...');
      final musicDir = await _ensureDefaultDocumentsOutputDir();
      state = state.copyWith(outputDir: musicDir.path);
    }

    if (!isSafMode) {
      _log.d('Output directory: ${state.outputDir}');
    } else {
      _log.d('Output directory: SAF (tree_uri=${settings.downloadTreeUri})');
      try {
        final testResult = await PlatformBridge.createSafFileFromPath(
          treeUri: settings.downloadTreeUri,
          relativeDir: '',
          fileName: '.spotiflac_test',
          mimeType: 'application/octet-stream',
          srcPath: '',
        );
        if (testResult != null) {
          await PlatformBridge.safDelete(testResult);
        }
      } catch (e) {
        _log.e('SAF permission validation failed: $e');
        _log.w('SAF tree URI may be invalid or permission revoked');
        for (final item in state.items) {
          if (item.status == DownloadStatus.queued) {
            updateItemStatus(
              item.id,
              DownloadStatus.failed,
              error: safPermissionLostErrorMessage,
            );
          }
        }
        state = state.copyWith(isProcessing: false);
        return;
      }
    }

    if (!isSafMode &&
        Platform.isIOS &&
        settings.downloadDirectoryBookmark.isNotEmpty) {
      final resolvedPath = await PlatformBridge.startAccessingIosBookmark(
        settings.downloadDirectoryBookmark,
      );
      if (resolvedPath != null && resolvedPath.isNotEmpty) {
        iosDownloadBookmarkActive = true;
        if (resolvedPath != state.outputDir) {
          _log.i('Resolved iOS download bookmark path: $resolvedPath');
          state = state.copyWith(outputDir: resolvedPath);
        }
      } else {
        _log.e('Failed to access iOS download folder bookmark');
        _log.w(
          'The saved download folder may have been moved, deleted, or its access grant lost',
        );
        for (final item in state.items) {
          if (item.status == DownloadStatus.queued) {
            updateItemStatus(
              item.id,
              DownloadStatus.failed,
              error: downloadFolderAccessLostErrorMessage,
            );
          }
        }
        state = state.copyWith(isProcessing: false);
        await PlatformBridge.endBackgroundDownloadTask();
        return;
      }
    }

    try {
      await _runQueueLoop();
    } finally {
      if (iosDownloadBookmarkActive) {
        await PlatformBridge.stopAccessingIosBookmark();
        iosDownloadBookmarkActive = false;
      }
    }
    final stoppedWhilePaused = state.isPaused;
    final keepConnectivityMonitoring =
        stoppedWhilePaused && _networkPausedByWifiOnly;

    _stopProgressPolling();
    _clearEmbedCoverCache();
    if (!keepConnectivityMonitoring) {
      _stopConnectivityMonitoring();
    }

    if (Platform.isAndroid) {
      try {
        await PlatformBridge.stopDownloadService();
        _log.d('Foreground service stopped');
      } catch (e) {
        _log.e('Failed to stop foreground service: $e');
      }
    }

    if (Platform.isIOS) {
      await PlatformBridge.endBackgroundDownloadTask();
    }

    if (_downloadCount > 0) {
      _log.d('Final connection cleanup...');
      try {
        await PlatformBridge.cleanupConnections();
      } catch (e) {
        _log.e('Final cleanup failed: $e');
      }
      _downloadCount = 0;
    }

    _log.i(
      'Queue stats - completed: $_completedInSession, failed: $_failedInSession, totalAtStart: $_totalQueuedAtStart',
    );
    final hasSessionResults = _completedInSession > 0 || _failedInSession > 0;
    if (!stoppedWhilePaused && _totalQueuedAtStart > 0 && hasSessionResults) {
      await _notificationService.showQueueComplete(
        completedCount: _completedInSession,
        failedCount: _failedInSession,
      );

      final settings = ref.read(settingsProvider);
      if (settings.autoExportFailedDownloads && _failedInSession > 0) {
        final exportPath = await exportFailedDownloads();
        if (exportPath != null) {
          _log.i('Auto-exported failed downloads to: $exportPath');
        }
      }
    } else if (!stoppedWhilePaused && _totalQueuedAtStart > 0) {
      await _notificationService.showQueueCanceled(
        canceledCount: _totalQueuedAtStart,
      );
    }

    if (stoppedWhilePaused) {
      _log.i('Queue processing paused');
    } else {
      _log.i('Queue processing finished');
    }
    state = state.copyWith(isProcessing: false, currentDownload: null);

    final hasQueuedItems = state.items.any(
      (item) => item.status == DownloadStatus.queued,
    );
    if (hasQueuedItems && !state.isPaused) {
      _log.i(
        'Found queued items after processing finished, restarting queue...',
      );
      Future.microtask(() => _processQueue());
    }
  }

  Future<void> _runQueueLoop() async {
    final activeDownloads = <String, Future<void>>{};

    _startMultiProgressPolling();

    while (true) {
      if (state.isPaused) {
        if (activeDownloads.isEmpty) {
          _log.d('Queue is paused and no active download remains');
          break;
        }
        _log.d('Queue is paused, waiting for active download...');
        await Future.any([
          Future.wait(activeDownloads.values),
          Future<void>.delayed(_queueSchedulingInterval),
        ]);
        continue;
      }

      final queuedItems = state.items
          .where(
            (item) =>
                item.status == DownloadStatus.queued &&
                !_pausePendingItemIds.contains(item.id),
          )
          .toList();

      if (queuedItems.isEmpty && activeDownloads.isEmpty) {
        _log.d('No more items to process');
        break;
      }

      final maxConcurrent = ref
          .read(settingsProvider)
          .concurrentDownloads
          .clamp(1, 3);
      while (activeDownloads.length < maxConcurrent &&
          queuedItems.isNotEmpty &&
          !state.isPaused) {
        final item = queuedItems.removeAt(0);

        updateItemStatus(item.id, DownloadStatus.downloading);

        final future = _downloadSingleItem(item).whenComplete(() {
          activeDownloads.remove(item.id);
          PlatformBridge.clearItemProgress(item.id).catchError((_) {});
        });

        activeDownloads[item.id] = future;
        _log.d('Started download: ${item.track.name}');
      }

      if (activeDownloads.isNotEmpty) {
        await Future.any([
          Future.any(activeDownloads.values),
          Future<void>.delayed(_queueSchedulingInterval),
        ]);
      } else {
        await Future<void>.delayed(_queueSchedulingInterval);
      }
    }

    if (activeDownloads.isNotEmpty) {
      await Future.wait(activeDownloads.values);
    }

    _stopProgressPolling();
    final remainingIds = state.items.map((item) => item.id).toSet();
    _locallyCancelledItemIds.removeWhere((id) => !remainingIds.contains(id));
    _pausePendingItemIds.removeWhere((id) => !remainingIds.contains(id));
    _verificationRetriedItemIds.removeWhere((retryKey) {
      final itemId = retryKey.split('::').first;
      return !remainingIds.contains(itemId);
    });
    _rateLimitRetriedItemIds.removeWhere((id) => !remainingIds.contains(id));
  }

  Future<void> _downloadSingleItem(DownloadItem item) async {
    final normalizedService = _normalizeQueuedService(item.service);
    if (normalizedService != item.service) {
      item = item.copyWith(service: normalizedService);
      state = state.copyWith(
        items: [
          for (final existing in state.items)
            if (existing.id == item.id) item else existing,
        ],
        currentDownload: state.currentDownload?.id == item.id
            ? item
            : state.currentDownload,
      );
      _saveQueueToStorage();
    }

    if (!_hasActiveDownloadProvider(item.service)) {
      updateItemStatus(
        item.id,
        DownloadStatus.failed,
        error: 'Download provider is no longer available',
        errorType: DownloadErrorType.notFound,
      );
      return;
    }

    _log.d('Processing: ${item.track.name} by ${item.track.artistName}');
    _log.d('Cover URL: ${item.track.coverUrl}');
    var pausedDuringThisRun = false;

    final currentItem = _findItemById(item.id) ?? item;
    if (_isLocallyCancelled(item.id, item: currentItem)) {
      _log.i('Download was cancelled before start, skipping');
      return;
    }

    if (_isPausePending(item.id)) {
      pausedDuringThisRun = true;
      _requeueItemForPause(item.id);
      _log.i('Download is pause-pending before start, skipping');
      return;
    }

    state = state.copyWith(currentDownload: item);

    updateItemStatus(item.id, DownloadStatus.downloading);

    // Shared guard for every checkpoint below: an item that vanished from the
    // queue or was flagged locally-cancelled aborts immediately; a
    // pause-pending item re-queues instead. [deleteFileOnAbort], when given,
    // is removed before returning (used once a file has already been written).
    Future<bool> shouldAbortWork(
      String stage, {
      String? deleteFileOnAbort,
    }) async {
      final current = _findItemById(item.id);
      if (current == null || _isLocallyCancelled(item.id, item: current)) {
        _log.i('Download was cancelled $stage, skipping');
        if (deleteFileOnAbort != null) {
          await deleteFile(deleteFileOnAbort);
          _log.d('Deleted cancelled download file: $deleteFileOnAbort');
        }
        return true;
      }
      if (_isPausePending(item.id)) {
        pausedDuringThisRun = true;
        if (deleteFileOnAbort != null) {
          await deleteFile(deleteFileOnAbort);
          _log.d('Deleted paused download file: $deleteFileOnAbort');
        }
        _requeueItemForPause(item.id);
        _log.i('Download pause requested $stage, re-queueing');
        return true;
      }
      return false;
    }

    try {
      final settings = ref.read(settingsProvider);
      final metadataEmbeddingEnabled = settings.embedMetadata;

      Track trackToDownload = item.track;
      final needsEnrichment =
          trackToDownload.id.startsWith('deezer:') &&
          (trackToDownload.isrc == null ||
              trackToDownload.isrc!.isEmpty ||
              trackToDownload.trackNumber == null ||
              trackToDownload.trackNumber == 0 ||
              trackToDownload.totalTracks == null ||
              trackToDownload.totalTracks == 0 ||
              (trackToDownload.composer == null ||
                  trackToDownload.composer!.isEmpty));

      if (needsEnrichment) {
        try {
          _log.d(
            'Enriching incomplete metadata for Deezer track: ${trackToDownload.name}',
          );
          _log.d(
            'Current ISRC: ${trackToDownload.isrc}, TrackNumber: ${trackToDownload.trackNumber}',
          );
          final rawId = trackToDownload.id.split(':')[1];
          _log.d('Fetching full metadata for Deezer ID: $rawId');
          final fullData = await PlatformBridge.getProviderMetadata(
            'deezer',
            'track',
            rawId,
          );
          _log.d('Got response keys: ${fullData.keys.toList()}');

          if (fullData.containsKey('track')) {
            final trackData = fullData['track'];
            _log.d('Track data type: ${trackData.runtimeType}');
            if (trackData is Map<String, dynamic>) {
              final data = trackData;
              _log.d('Track data keys: ${data.keys.toList()}');
              _log.d('ISRC from API: ${data['isrc']}');
              _log.d('album_type from API: ${data['album_type']}');
              final enrichedTotalTracks = readPositiveInt(data['total_tracks']);
              final enrichedTotalDiscs = readPositiveInt(data['total_discs']);
              final enrichedComposer = normalizeOptionalString(
                data['composer']?.toString(),
              );
              trackToDownload = Track(
                id: (data['spotify_id'] as String?) ?? trackToDownload.id,
                name: (data['name'] as String?) ?? trackToDownload.name,
                artistName:
                    (data['artists'] as String?) ?? trackToDownload.artistName,
                albumName:
                    (data['album_name'] as String?) ??
                    trackToDownload.albumName,
                albumArtist: data['album_artist'] as String?,
                artistId:
                    (data['artist_id'] ?? data['artistId'])?.toString() ??
                    trackToDownload.artistId,
                albumId:
                    data['album_id']?.toString() ?? trackToDownload.albumId,
                coverUrl: data['images'] as String?,
                duration:
                    ((data['duration_ms'] as int?) ??
                        (trackToDownload.duration * 1000)) ~/
                    1000,
                isrc: (data['isrc'] as String?) ?? trackToDownload.isrc,
                trackNumber: data['track_number'] as int?,
                discNumber: data['disc_number'] as int?,
                totalDiscs: enrichedTotalDiscs ?? trackToDownload.totalDiscs,
                releaseDate: data['release_date'] as String?,
                deezerId: rawId,
                availability: trackToDownload.availability,
                albumType:
                    (data['album_type'] as String?) ??
                    trackToDownload.albumType,
                totalTracks: enrichedTotalTracks ?? trackToDownload.totalTracks,
                composer: enrichedComposer ?? trackToDownload.composer,
                source: trackToDownload.source,
              );
              _log.d(
                'Metadata enriched: Track ${trackToDownload.trackNumber}, Disc ${trackToDownload.discNumber}, ISRC ${trackToDownload.isrc}, AlbumType ${trackToDownload.albumType}',
              );
            } else {
              _log.w('Unexpected track data type: ${trackData.runtimeType}');
            }
          } else {
            _log.w('Response does not contain track key');
          }
        } catch (e, stack) {
          _log.w('Failed to enrich metadata: $e');
          _log.w('Stack trace: $stack');
        }

        if (await shouldAbortWork('during metadata enrichment')) {
          return;
        }
      }

      _log.d('Track coverUrl after enrichment: ${trackToDownload.coverUrl}');

      final resolvedAlbumArtist = _resolveAlbumArtistForMetadata(
        trackToDownload,
        settings,
      );

      var quality = item.qualityOverride ?? state.audioQuality;
      if (quality == 'DEFAULT') quality = state.audioQuality;
      final isSafMode = _isSafMode(settings);
      final relativeOutputDir = isSafMode
          ? await _buildRelativeOutputDir(
              trackToDownload,
              settings.folderOrganization,
              separateSingles: settings.separateSingles,
              albumFolderStructure: settings.albumFolderStructure,
              createPlaylistFolder: settings.createPlaylistFolder,
              useAlbumArtistForFolders: settings.useAlbumArtistForFolders,
              usePrimaryArtistOnly: settings.usePrimaryArtistOnly,
              filterContributingArtistsInAlbumArtist:
                  settings.filterContributingArtistsInAlbumArtist,
              playlistName: item.playlistName,
            )
          : '';
      String? appOutputDir;
      final initialOutputDir = isSafMode
          ? relativeOutputDir
          : await _buildOutputDir(
              trackToDownload,
              settings.folderOrganization,
              separateSingles: settings.separateSingles,
              albumFolderStructure: settings.albumFolderStructure,
              createPlaylistFolder: settings.createPlaylistFolder,
              useAlbumArtistForFolders: settings.useAlbumArtistForFolders,
              usePrimaryArtistOnly: settings.usePrimaryArtistOnly,
              filterContributingArtistsInAlbumArtist:
                  settings.filterContributingArtistsInAlbumArtist,
              playlistName: item.playlistName,
            );
      var effectiveOutputDir = isSafMode
          ? _sanitizeSafRelativeDir(initialOutputDir)
          : initialOutputDir;
      var effectiveSafMode = isSafMode;

      String? safFileName;
      String? safBaseName;
      String safOutputExt = _determineOutputExt(quality, item.service);
      final baseFilenameFormat = _shouldTreatAsSingleRelease(trackToDownload)
          ? state.singleFilenameFormat
          : state.filenameFormat;
      final effectiveFilenameFormat = _filenameFormatForItem(
        item,
        baseFilenameFormat,
      );
      if (isSafMode) {
        final baseName = await PlatformBridge.buildFilename(
          effectiveFilenameFormat,
          _filenameMetadataForTrack(
            trackToDownload,
            playlistPosition: _validPlaylistPosition(item),
          ),
        );
        safFileName = await _buildSafFileName(baseName, safOutputExt);
        safBaseName = safFileName.replaceFirst(RegExp(r'\.[^.]+$'), '');
      }
      String? finalSafFileName = safFileName;
      // Filled by the SAF embed op from the local temp so the final quality
      // probe doesn't have to copy the published file back out of SAF.
      Map<String, dynamic>? probedFinalMetadata;

      String? genre;
      String? label;
      String? copyright;
      final extensionState = ref.read(extensionProvider);
      final selectedExtensionDownloadProvider =
          settings.useExtensionProviders &&
          extensionState.extensions.any(
            (e) =>
                e.enabled &&
                e.hasDownloadProvider &&
                e.id.toLowerCase() == item.service.toLowerCase(),
          );
      final trackSource = (trackToDownload.source ?? '').trim().toLowerCase();
      final shouldSkipExtensionSongLinkPrelookup =
          trackSource.isNotEmpty &&
          extensionState.extensions.any(
            (e) =>
                e.enabled &&
                e.hasMetadataProvider &&
                e.id.toLowerCase() == trackSource,
          );

      String? deezerTrackId = await _resolveDeezerIdFromKnownOrIsrc(
        trackToDownload,
        item.id,
        lookupContext: 'ISRC',
      );
      if (await shouldAbortWork('during Deezer ISRC lookup')) {
        return;
      }

      // For tidal:/qobuz: tracks without ISRC, resolve ISRC from provider
      // API directly (faster than SongLink and avoids rate limits).
      final providerResolved = await _resolveDeezerIdViaProviderIfNeeded(
        trackToDownload,
        deezerTrackId,
        item.id,
      );
      trackToDownload = providerResolved.track;
      deezerTrackId = providerResolved.deezerTrackId;
      if (await shouldAbortWork('during provider ISRC resolution')) {
        return;
      }

      if (!selectedExtensionDownloadProvider &&
          deezerTrackId == null &&
          !shouldSkipExtensionSongLinkPrelookup &&
          trackToDownload.id.isNotEmpty &&
          !trackToDownload.id.startsWith('deezer:') &&
          !trackToDownload.id.startsWith('extension:') &&
          !trackToDownload.id.startsWith('tidal:') &&
          !trackToDownload.id.startsWith('qobuz:')) {
        final spotifyLookup = await _resolveSpotifyTrackViaDeezer(
          trackToDownload,
        );
        trackToDownload = spotifyLookup.track;
        deezerTrackId ??= spotifyLookup.deezerTrackId;

        if (await shouldAbortWork('during SongLink availability lookup')) {
          return;
        }
      } else if (selectedExtensionDownloadProvider && deezerTrackId == null) {
        _log.d(
          'Skipping Flutter SongLink Deezer prelookup for extension provider: ${item.service}',
        );
      } else if (shouldSkipExtensionSongLinkPrelookup &&
          deezerTrackId == null) {
        _log.d(
          'Skipping Flutter SongLink Deezer prelookup for extension-sourced track; backend metadata enrichment will resolve identifiers first',
        );
      }

      // Genre/label/copyright are only consumed at embed time (the payload
      // copy is just echoed back in the response), so this lookup overlaps
      // with the download instead of delaying its start; it is awaited right
      // after the download returns.
      final extendedMetadataFuture = _loadExtendedMetadataForDeezerId(
        deezerTrackId,
      ).catchError((Object e) {
        _log.w('Extended metadata lookup failed: $e');
        return null;
      });

      Map<String, dynamic> result;

      final hasActiveExtensions = extensionState.extensions.any(
        (e) => e.enabled,
      );
      final useExtensions =
          settings.useExtensionProviders && hasActiveExtensions;

      Future<Map<String, dynamic>> runDownload({
        required bool useSaf,
        required String outputDir,
      }) async {
        final outputExt = safOutputExt;
        final shouldUseExtensions = useExtensions;
        final shouldUseFallback = state.autoFallback;

        if (shouldUseExtensions) {
          _log.d('Using extension providers for download');
          _log.d(
            'Quality: $quality${item.qualityOverride != null ? ' (override)' : ''}',
          );
        } else if (shouldUseFallback) {
          _log.d('Using auto-fallback mode');
          _log.d(
            'Quality: $quality${item.qualityOverride != null ? ' (override)' : ''}',
          );
        }

        if (!useSaf) {
          await _ensureDirExists(outputDir, label: 'Output folder');
        }

        _log.d('Output dir: $outputDir');

        final payload = _buildDownloadRequestPayload(
          track: trackToDownload,
          item: item,
          settings: settings,
          extensionState: extensionState,
          quality: quality,
          filenameFormat: effectiveFilenameFormat,
          outputDir: outputDir,
          outputExt: outputExt,
          useSaf: useSaf,
          safFileName: safFileName,
          deezerTrackId: deezerTrackId,
          genre: genre,
          label: label,
          copyright: copyright,
        );

        return PlatformBridge.downloadByStrategy(
          payload: payload,
          useExtensions: shouldUseExtensions,
          useFallback: shouldUseFallback,
        );
      }

      if (await shouldAbortWork('before native download start')) {
        return;
      }

      result = await runDownload(
        useSaf: effectiveSafMode,
        outputDir: effectiveOutputDir,
      );

      if (effectiveSafMode &&
          result['success'] != true &&
          _isSafWriteFailure(result)) {
        if (_isLocallyCancelled(item.id)) {
          _log.i('Download was cancelled before SAF fallback, skipping');
          return;
        }
        _log.w('SAF write failed, retrying with app-private storage');
        appOutputDir ??= await _buildOutputDir(
          trackToDownload,
          settings.folderOrganization,
          separateSingles: settings.separateSingles,
          albumFolderStructure: settings.albumFolderStructure,
          createPlaylistFolder: settings.createPlaylistFolder,
          useAlbumArtistForFolders: settings.useAlbumArtistForFolders,
          usePrimaryArtistOnly: settings.usePrimaryArtistOnly,
          filterContributingArtistsInAlbumArtist:
              settings.filterContributingArtistsInAlbumArtist,
          playlistName: item.playlistName,
        );
        final fallbackResult = await runDownload(
          useSaf: false,
          outputDir: appOutputDir,
        );
        if (fallbackResult['success'] == true) {
          effectiveSafMode = false;
          effectiveOutputDir = appOutputDir;
          finalSafFileName = null;
          result = fallbackResult;
        }
      }

      _log.d('Result: $result');

      final extendedMetadata = await extendedMetadataFuture;
      if (extendedMetadata != null) {
        genre = extendedMetadata.genre;
        label = extendedMetadata.label;
        copyright = extendedMetadata.copyright;
      }

      final resultFilePath = result['file_path'] as String?;
      final resultFileToCleanup =
          (resultFilePath != null && result['success'] == true)
          ? resultFilePath
          : null;
      if (await shouldAbortWork(
        'after result',
        deleteFileOnAbort: resultFileToCleanup,
      )) {
        return;
      }

      if (result['success'] == true) {
        var filePath = result['file_path'] as String?;
        final reportedFileName = result['file_name'] as String?;
        if (effectiveSafMode &&
            reportedFileName != null &&
            reportedFileName.isNotEmpty) {
          finalSafFileName = reportedFileName;
        }

        final wasExisting = result['already_exists'] == true;
        if (wasExisting) {
          _log.i('File already exists in library: $filePath');
        }

        _log.i('Download success, file: $filePath');

        final actualBitDepth = result['actual_bit_depth'] as int?;
        final actualSampleRate = result['actual_sample_rate'] as int?;
        String actualQuality = quality;

        if (actualBitDepth != null && actualBitDepth > 0) {
          final sampleRateKHz = actualSampleRate != null && actualSampleRate > 0
              ? (actualSampleRate / 1000).toStringAsFixed(
                  actualSampleRate % 1000 == 0 ? 0 : 1,
                )
              : '?';
          actualQuality = '$actualBitDepth-bit/${sampleRateKHz}kHz';
          _log.i('Actual quality: $actualQuality');
        }

        final actualService =
            ((result['service'] as String?)?.toLowerCase()) ??
            item.service.toLowerCase();
        final resultOutputExt = _downloadResultOutputExt(
          result,
          filePath: filePath,
        );
        final resultAudioFormat = normalizeAudioFormatValue(
          result['audio_codec']?.toString() ??
              result['actual_audio_codec']?.toString(),
        );
        final resultIsLossyAudio = isLossyAudioFormat(resultAudioFormat);
        final requiresContainerConversion =
            result['requires_container_conversion'] == true ||
            result['requiresContainerConversion'] == true ||
            (!resultIsLossyAudio &&
                _shouldRequestContainerConversion(actualService, safOutputExt));
        final preferredOutputExt = _extensionPreferredOutputExt(actualService);
        final shouldPreserveNativeM4a =
            !requiresContainerConversion &&
            (resultOutputExt == '.m4a' ||
                resultOutputExt == '.mp4' ||
                preferredOutputExt == '.m4a' ||
                preferredOutputExt == '.mp4' ||
                _extensionPreservesNativeOutputExt(actualService, '.m4a') ||
                _extensionPreservesNativeOutputExt(actualService, '.mp4'));
        final decryptionDescriptor =
            DownloadDecryptionDescriptor.fromDownloadResult(result);
        trackToDownload = _buildTrackForMetadataEmbedding(
          trackToDownload,
          result,
          resolvedAlbumArtist,
        );
        _log.d(
          'Track coverUrl after download result: ${trackToDownload.coverUrl}',
        );

        if (!wasExisting && decryptionDescriptor != null && filePath != null) {
          _log.i(
            'Encrypted stream detected, decrypting via ${decryptionDescriptor.normalizedStrategy}...',
          );
          updateItemStatus(item.id, DownloadStatus.finalizing, progress: 0.9);

          final isSafSource = effectiveSafMode && isContentUri(filePath);
          final decryptOutcome = await _finalizeDecryption(
            result: result,
            filePath: filePath,
            storageMode: effectiveSafMode ? 'saf' : 'app',
            downloadTreeUri: settings.downloadTreeUri,
            safRelativeDir: effectiveOutputDir,
            baseName: safBaseName ?? 'track',
            extFallback: '.flac',
            repairAc4: true,
          );
          if (decryptOutcome.path == null) {
            final String errorMsg;
            switch (decryptOutcome.failStage) {
              case _decryptStageSafAccess:
                _log.e('Failed to copy encrypted SAF file to temp for decrypt');
                errorMsg = 'Failed to access encrypted SAF file';
                break;
              case _decryptStageSafWrite:
                _log.e('Failed to write decrypted stream back to SAF');
                errorMsg = 'Failed to write decrypted file to storage';
                break;
              default:
                _log.e(
                  isSafSource
                      ? 'FFmpeg decrypt failed for SAF file'
                      : 'FFmpeg decrypt failed for local file',
                );
                errorMsg = 'Failed to decrypt encrypted stream';
                break;
            }
            updateItemStatus(
              item.id,
              DownloadStatus.failed,
              error: errorMsg,
              errorType: DownloadErrorType.unknown,
            );
            return;
          }
          filePath = decryptOutcome.path;
          if (decryptOutcome.newFileName != null) {
            finalSafFileName = decryptOutcome.newFileName;
          }
          _log.i(
            isSafSource
                ? 'SAF decryption completed'
                : 'Local decryption completed',
          );
        }

        final isContentUriPath = filePath != null && isContentUri(filePath);
        final mimeType = isContentUriPath
            ? await _getSafMimeType(filePath)
            : null;
        final isM4aFile =
            filePath != null &&
            (filePath.endsWith('.m4a') ||
                filePath.endsWith('.mp4') ||
                resultOutputExt == '.m4a' ||
                resultOutputExt == '.mp4' ||
                (mimeType != null && mimeType.contains('mp4')));
        final isFlacFile =
            filePath != null &&
            (filePath.endsWith('.flac') ||
                resultOutputExt == '.flac' ||
                (mimeType != null && mimeType.contains('flac')));
        final shouldForceDashSafM4aHandling =
            !wasExisting &&
            isContentUriPath &&
            effectiveSafMode &&
            _downloadProviderReplacesLegacyProvider(actualService, 'tidal') &&
            filePath.endsWith('.flac') &&
            (mimeType == null || mimeType.contains('flac'));

        if (shouldForceDashSafM4aHandling) {
          _log.w(
            'SAF file is labeled FLAC but backend returned DASH/M4A stream; converting it back to FLAC.',
          );
        }

        if (isM4aFile || shouldForceDashSafM4aHandling) {
          final currentFilePath = filePath;

          if (isContentUriPath && effectiveSafMode) {
            if (quality == 'HIGH') {
              final tidalHighFormat = settings.tidalHighFormat;
              _log.i(
                'Lossy 320kbps quality (SAF), converting M4A to $tidalHighFormat...',
              );

              final format = lossyFormatForSetting(tidalHighFormat);
              final displayFormat = displayFormatForLossyFormat(format);
              final newExt = lossyExtensionForFormat(format);
              final newFileName = '${safBaseName ?? 'track'}$newExt';
              var opStarted = false;
              var convertFailed = false;
              try {
                final newUri = await _replaceSafFileVia(
                  uri: currentFilePath,
                  treeUri: settings.downloadTreeUri,
                  relativeDir: effectiveOutputDir,
                  op: (tempPath, addCleanup) async {
                    opStarted = true;
                    updateItemStatus(
                      item.id,
                      DownloadStatus.finalizing,
                      progress: 0.95,
                    );
                    final convertedPath = await FFmpegService.convertM4aToLossy(
                      tempPath,
                      format: format,
                      bitrate: tidalHighFormat,
                      deleteOriginal: false,
                    );
                    if (convertedPath == null) {
                      convertFailed = true;
                      return null;
                    }
                    addCleanup(convertedPath);
                    _log.i(
                      'Successfully converted M4A to $format (temp): $convertedPath',
                    );
                    _log.i('Embedding metadata to $format...');
                    updateItemStatus(
                      item.id,
                      DownloadStatus.finalizing,
                      progress: 0.99,
                    );

                    final backendGenre = result['genre'] as String?;
                    final backendLabel = result['label'] as String?;
                    final backendCopyright = result['copyright'] as String?;

                    await _embedMetadataToFile(
                      convertedPath,
                      trackToDownload,
                      format: metadataFormatForLossyFormat(format),
                      genre: backendGenre ?? genre,
                      label: backendLabel ?? label,
                      copyright: backendCopyright,
                      downloadService: item.service,
                    );

                    return (convertedPath, newFileName);
                  },
                );

                if (newUri != null) {
                  filePath = newUri;
                  finalSafFileName = newFileName;
                  final bitrateDisplay = tidalHighFormat.contains('_')
                      ? '${tidalHighFormat.split('_').last}kbps'
                      : '320kbps';
                  actualQuality = '$displayFormat $bitrateDisplay';
                } else if (convertFailed) {
                  _log.w('M4A to $format conversion failed, keeping M4A file');
                  actualQuality = 'AAC 320kbps';
                } else if (opStarted) {
                  _log.w(
                    'Failed to write converted $format to SAF, keeping M4A',
                  );
                  actualQuality = 'AAC 320kbps';
                }
              } catch (e) {
                _log.w('SAF M4A conversion failed: $e');
                actualQuality = 'AAC 320kbps';
              }
            } else if (shouldPreserveNativeM4a) {
              // Decrypted streams are already in their final format.
              // Converting e.g. eac3 M4A to FLAC would produce fake upscaled output.
              _log.d(
                'M4A/MP4 file detected (SAF), preserving native container...',
              );
              final preserveExt = currentFilePath.toLowerCase().endsWith('.mp4')
                  ? '.mp4'
                  : '.m4a';
              final newFileName = '${safBaseName ?? 'track'}$preserveExt';
              var opStarted = false;
              try {
                final newUri = await _replaceSafFileVia(
                  uri: currentFilePath,
                  treeUri: settings.downloadTreeUri,
                  relativeDir: effectiveOutputDir,
                  op: (tempPath, _) async {
                    opStarted = true;
                    if (metadataEmbeddingEnabled) {
                      updateItemStatus(
                        item.id,
                        DownloadStatus.finalizing,
                        progress: 0.99,
                      );
                      final finalTrack = _buildTrackForMetadataEmbedding(
                        trackToDownload,
                        result,
                        resolvedAlbumArtist,
                      );
                      final backendGenre = result['genre'] as String?;
                      final backendLabel = result['label'] as String?;
                      final backendCopyright = result['copyright'] as String?;

                      await _embedMetadataToFile(
                        tempPath,
                        finalTrack,
                        format: 'm4a',
                        genre: backendGenre ?? genre,
                        label: backendLabel ?? label,
                        copyright: backendCopyright,
                        downloadService: item.service,
                        writeExternalLrc: false,
                      );
                    }
                    return (tempPath, newFileName);
                  },
                );

                if (newUri != null) {
                  filePath = newUri;
                  finalSafFileName = newFileName;
                } else if (opStarted) {
                  _log.w('Failed to write M4A to SAF, keeping original');
                }
              } catch (e) {
                _log.w('SAF native M4A handling failed: $e');
              }
            } else {
              _log.d('M4A file detected (SAF), converting to FLAC...');
              String? branch;
              String? producedFileName;
              try {
                final newUri = await _replaceSafFileVia(
                  uri: currentFilePath,
                  treeUri: settings.downloadTreeUri,
                  relativeDir: effectiveOutputDir,
                  op: (tempPath, addCleanup) async {
                    final length = await File(tempPath).length();
                    if (length < 1024) {
                      _log.w(
                        'Temp M4A is too small (<1KB), skipping conversion',
                      );
                      branch = 'skip';
                      return null;
                    }
                    final codec = await FFmpegService.probePrimaryAudioCodec(
                      tempPath,
                    );
                    final isAlreadyNativeFlac =
                        codec == 'flac' &&
                        await FFmpegService.isNativeFlacFile(tempPath);
                    if (!FFmpegService.isLosslessAudioCodec(codec)) {
                      _log.d(
                        'Preserving native container; audio codec is ${codec ?? 'unknown'}, '
                        'no FLAC container conversion needed.',
                      );
                      branch = 'preserve';
                      final preserveExt = resultOutputExt == '.mp4'
                          ? '.mp4'
                          : '.m4a';
                      final newFileName =
                          '${safBaseName ?? 'track'}$preserveExt';
                      producedFileName = newFileName;
                      return (tempPath, newFileName);
                    } else if (isAlreadyNativeFlac) {
                      _log.d(
                        'Native FLAC payload detected in SAF temp file; '
                        'publishing as FLAC and embedding metadata.',
                      );
                      branch = 'nativeFlac';
                      final finalTrack = _buildTrackForMetadataEmbedding(
                        trackToDownload,
                        result,
                        resolvedAlbumArtist,
                      );

                      final backendGenre = result['genre'] as String?;
                      final backendLabel = result['label'] as String?;
                      final backendCopyright = result['copyright'] as String?;

                      await _embedMetadataToFile(
                        tempPath,
                        finalTrack,
                        format: 'flac',
                        genre: backendGenre ?? genre,
                        label: backendLabel ?? label,
                        copyright: backendCopyright,
                        downloadService: item.service,
                        writeExternalLrc: false,
                      );

                      final newFileName = '${safBaseName ?? 'track'}.flac';
                      producedFileName = newFileName;
                      return (tempPath, newFileName);
                    } else {
                      updateItemStatus(
                        item.id,
                        DownloadStatus.finalizing,
                        progress: 0.95,
                      );
                      final flacPath = await FFmpegService.convertM4aToFlac(
                        tempPath,
                      );
                      if (flacPath == null) {
                        _log.w(
                          'FFmpeg conversion returned null, keeping M4A file',
                        );
                        branch = 'convertFailed';
                        return null;
                      }
                      addCleanup(flacPath);
                      _log.d('Converted to FLAC (temp): $flacPath');
                      _log.d(
                        'Embedding metadata and cover to converted FLAC...',
                      );
                      final finalTrack = _buildTrackForMetadataEmbedding(
                        trackToDownload,
                        result,
                        resolvedAlbumArtist,
                      );

                      final backendGenre = result['genre'] as String?;
                      final backendLabel = result['label'] as String?;
                      final backendCopyright = result['copyright'] as String?;

                      await _embedMetadataToFile(
                        flacPath,
                        finalTrack,
                        format: 'flac',
                        genre: backendGenre ?? genre,
                        label: backendLabel ?? label,
                        copyright: backendCopyright,
                        downloadService: item.service,
                        writeExternalLrc: false,
                      );

                      final newFileName = '${safBaseName ?? 'track'}.flac';
                      branch = 'convert';
                      producedFileName = newFileName;
                      return (flacPath, newFileName);
                    }
                  },
                );

                if (newUri != null) {
                  filePath = newUri;
                  finalSafFileName = producedFileName;
                } else if (branch == 'nativeFlac') {
                  _log.w('Failed to write native FLAC to SAF');
                } else if (branch == 'convert') {
                  _log.w('Failed to write FLAC to SAF, keeping M4A');
                }
              } catch (e) {
                _log.w('SAF M4A->FLAC conversion failed: $e');
              }
            }
          } else {
            if (quality == 'HIGH') {
              final tidalHighFormat = settings.tidalHighFormat;
              _log.i(
                'Lossy 320kbps quality download, converting M4A to $tidalHighFormat...',
              );

              try {
                updateItemStatus(
                  item.id,
                  DownloadStatus.finalizing,
                  progress: 0.95,
                );

                final format = lossyFormatForSetting(tidalHighFormat);
                final displayFormat = displayFormatForLossyFormat(format);
                final convertedPath = await FFmpegService.convertM4aToLossy(
                  currentFilePath,
                  format: format,
                  bitrate: tidalHighFormat,
                  deleteOriginal: true,
                );

                if (convertedPath != null) {
                  filePath = convertedPath;
                  final bitrateDisplay = tidalHighFormat.contains('_')
                      ? '${tidalHighFormat.split('_').last}kbps'
                      : '320kbps';
                  actualQuality = '$displayFormat $bitrateDisplay';
                  _log.i(
                    'Successfully converted M4A to $format: $convertedPath',
                  );

                  _log.i('Embedding metadata to $format...');
                  updateItemStatus(
                    item.id,
                    DownloadStatus.finalizing,
                    progress: 0.99,
                  );

                  final backendGenre = result['genre'] as String?;
                  final backendLabel = result['label'] as String?;
                  final backendCopyright = result['copyright'] as String?;

                  await _embedMetadataToFile(
                    convertedPath,
                    trackToDownload,
                    format: metadataFormatForLossyFormat(format),
                    genre: backendGenre ?? genre,
                    label: backendLabel ?? label,
                    copyright: backendCopyright,
                    downloadService: item.service,
                  );
                  _log.d('Metadata embedded successfully');
                } else {
                  _log.w('M4A to $format conversion failed, keeping M4A file');
                  actualQuality = 'AAC 320kbps';
                }
              } catch (e) {
                _log.w('M4A conversion process failed: $e, keeping M4A file');
                actualQuality = 'AAC 320kbps';
              }
            } else if (shouldPreserveNativeM4a) {
              _log.d('M4A/MP4 file detected, preserving native container...');

              try {
                var targetPath = currentFilePath;
                final file = File(targetPath);
                if (!await file.exists()) {
                  _log.e('File does not exist at path: $filePath');
                } else {
                  if (!(targetPath.toLowerCase().endsWith('.m4a') ||
                      targetPath.toLowerCase().endsWith('.mp4'))) {
                    final renamedPath = targetPath.replaceAll(
                      RegExp(r'\.[^.]+$'),
                      '.m4a',
                    );
                    final finalRenamedPath = renamedPath == targetPath
                        ? '$targetPath.m4a'
                        : renamedPath;
                    await file.rename(finalRenamedPath);
                    targetPath = finalRenamedPath;
                    filePath = finalRenamedPath;
                  } else {
                    filePath = targetPath;
                  }

                  if (metadataEmbeddingEnabled) {
                    updateItemStatus(
                      item.id,
                      DownloadStatus.finalizing,
                      progress: 0.99,
                    );
                    final finalTrack = _buildTrackForMetadataEmbedding(
                      trackToDownload,
                      result,
                      resolvedAlbumArtist,
                    );

                    final backendGenre = result['genre'] as String?;
                    final backendLabel = result['label'] as String?;
                    final backendCopyright = result['copyright'] as String?;

                    await _embedMetadataToFile(
                      targetPath,
                      finalTrack,
                      format: 'm4a',
                      genre: backendGenre ?? genre,
                      label: backendLabel ?? label,
                      copyright: backendCopyright,
                      downloadService: item.service,
                    );
                  }
                }
              } catch (e) {
                _log.w('Native M4A handling failed: $e');
              }
            } else {
              _log.d(
                'M4A file detected (Hi-Res DASH stream), attempting conversion to FLAC...',
              );

              try {
                final file = File(currentFilePath);
                if (!await file.exists()) {
                  _log.e('File does not exist at path: $filePath');
                } else {
                  final length = await file.length();
                  _log.i('File size before conversion: ${length / 1024} KB');

                  if (length < 1024) {
                    _log.w(
                      'File is too small (<1KB), skipping conversion. Download might be corrupt.',
                    );
                  } else {
                    final codec = await FFmpegService.probePrimaryAudioCodec(
                      currentFilePath,
                    );
                    final isAlreadyNativeFlac =
                        codec == 'flac' &&
                        await FFmpegService.isNativeFlacFile(currentFilePath);
                    if (!FFmpegService.isLosslessAudioCodec(codec)) {
                      _log.d(
                        'Preserving native container; audio codec is ${codec ?? 'unknown'}, '
                        'no FLAC container conversion needed.',
                      );
                    } else if (isAlreadyNativeFlac) {
                      _log.d(
                        'Native FLAC payload detected; ensuring .flac '
                        'extension and embedding metadata.',
                      );
                      var flacPath = currentFilePath;
                      if (!currentFilePath.toLowerCase().endsWith('.flac')) {
                        final renamedPath = currentFilePath.replaceAll(
                          RegExp(r'\.[^.]+$'),
                          '.flac',
                        );
                        final targetPath = renamedPath == currentFilePath
                            ? '$currentFilePath.flac'
                            : renamedPath;
                        await File(currentFilePath).rename(targetPath);
                        flacPath = targetPath;
                        filePath = targetPath;
                      }

                      final finalTrack = _buildTrackForMetadataEmbedding(
                        trackToDownload,
                        result,
                        resolvedAlbumArtist,
                      );

                      final backendGenre = result['genre'] as String?;
                      final backendLabel = result['label'] as String?;
                      final backendCopyright = result['copyright'] as String?;

                      await _embedMetadataToFile(
                        flacPath,
                        finalTrack,
                        format: 'flac',
                        genre: backendGenre ?? genre,
                        label: backendLabel ?? label,
                        copyright: backendCopyright,
                        downloadService: item.service,
                      );
                    } else {
                      updateItemStatus(
                        item.id,
                        DownloadStatus.finalizing,
                        progress: 0.95,
                      );
                      final flacPath = await FFmpegService.convertM4aToFlac(
                        currentFilePath,
                      );

                      if (flacPath != null) {
                        filePath = flacPath;
                        _log.d('Converted to FLAC: $flacPath');

                        _log.d(
                          'Embedding metadata and cover to converted FLAC...',
                        );
                        try {
                          final finalTrack = _buildTrackForMetadataEmbedding(
                            trackToDownload,
                            result,
                            resolvedAlbumArtist,
                          );

                          final backendGenre = result['genre'] as String?;
                          final backendLabel = result['label'] as String?;
                          final backendCopyright =
                              result['copyright'] as String?;

                          if (backendGenre != null ||
                              backendLabel != null ||
                              backendCopyright != null) {
                            _log.d(
                              'Extended metadata from backend - Genre: $backendGenre, Label: $backendLabel, Copyright: $backendCopyright',
                            );
                          }

                          await _embedMetadataToFile(
                            flacPath,
                            finalTrack,
                            format: 'flac',
                            genre: backendGenre ?? genre,
                            label: backendLabel ?? label,
                            copyright: backendCopyright,
                            downloadService: item.service,
                          );
                          _log.d('Metadata and cover embedded successfully');
                        } catch (e) {
                          _log.w('Warning: Failed to embed metadata/cover: $e');
                        }
                      } else {
                        _log.w(
                          'FFmpeg conversion returned null, keeping M4A file',
                        );
                      }
                    }
                  }
                }
              } catch (e) {
                _log.w(
                  'FFmpeg conversion process failed: $e, keeping M4A file',
                );
              }
            }
          }
        } else if (metadataEmbeddingEnabled &&
            isContentUriPath &&
            effectiveSafMode &&
            !isM4aFile &&
            !wasExisting) {
          final currentFilePath = filePath;
          final isOpusFile =
              filePath.endsWith('.opus') ||
              filePath.endsWith('.ogg') ||
              resultOutputExt == '.opus' ||
              resultOutputExt == '.ogg';
          final isMp3File =
              filePath.endsWith('.mp3') || resultOutputExt == '.mp3';
          final ext = isOpusFile
              ? (resultOutputExt == '.ogg' ? '.ogg' : '.opus')
              : isMp3File
              ? '.mp3'
              : '.flac';
          final formatName = isOpusFile
              ? 'Opus'
              : isMp3File
              ? 'MP3'
              : 'FLAC';
          _log.d(
            'SAF $formatName detected, embedding metadata and cover via temp file...',
          );
          final newFileName = '${safBaseName ?? 'track'}$ext';
          var opStarted = false;
          try {
            final newUri = await _replaceSafFileVia(
              uri: currentFilePath,
              treeUri: settings.downloadTreeUri,
              relativeDir: effectiveOutputDir,
              op: (tempPath, _) async {
                opStarted = true;
                updateItemStatus(
                  item.id,
                  DownloadStatus.finalizing,
                  progress: 0.99,
                );

                final finalTrack = _buildTrackForMetadataEmbedding(
                  trackToDownload,
                  result,
                  resolvedAlbumArtist,
                );
                final backendGenre = result['genre'] as String?;
                final backendLabel = result['label'] as String?;
                final backendCopyright = result['copyright'] as String?;

                // writeExternalLrc: false — tempPath lives in the cache dir,
                // so a sidecar .lrc written next to it would be orphaned;
                // the SAF .lrc is written by _saveExternalLrc after publish,
                // reusing the LRC fetched here via result['lyrics_lrc'].
                final embedFormat = isMp3File
                    ? 'mp3'
                    : isOpusFile
                    ? 'opus'
                    : 'flac';
                final fetchedLrc = await _embedMetadataToFile(
                  tempPath,
                  finalTrack,
                  format: embedFormat,
                  genre: backendGenre ?? genre,
                  label: backendLabel ?? label,
                  copyright: backendCopyright,
                  downloadService: item.service,
                  writeExternalLrc: false,
                );
                final existingLrc = result['lyrics_lrc'] as String?;
                if ((existingLrc == null || existingLrc.isEmpty) &&
                    fetchedLrc != null &&
                    fetchedLrc.isNotEmpty) {
                  result['lyrics_lrc'] = fetchedLrc;
                }

                // Probe quality from the local temp now: the same probe on
                // the published content:// URI would copy the whole file
                // out of SAF again just to read a few header bytes.
                try {
                  probedFinalMetadata = await PlatformBridge.readFileMetadata(
                    tempPath,
                  );
                } catch (_) {}

                return (tempPath, newFileName);
              },
            );

            if (newUri != null) {
              filePath = newUri;
              finalSafFileName = newFileName;
              _log.d('SAF $formatName metadata embedding completed');
            } else if (opStarted) {
              _log.w(
                'Failed to write metadata-updated $formatName back to SAF',
              );
            }
          } catch (e) {
            _log.w('SAF $formatName metadata embedding failed: $e');
          }
        } else if (metadataEmbeddingEnabled &&
            !isContentUriPath &&
            !effectiveSafMode &&
            isFlacFile &&
            !wasExisting &&
            decryptionDescriptor != null) {
          _log.d(
            'Local FLAC after decrypt detected, embedding metadata and cover...',
          );
          try {
            updateItemStatus(
              item.id,
              DownloadStatus.finalizing,
              progress: 0.99,
            );

            final finalTrack = _buildTrackForMetadataEmbedding(
              trackToDownload,
              result,
              resolvedAlbumArtist,
            );
            final backendGenre = result['genre'] as String?;
            final backendLabel = result['label'] as String?;
            final backendCopyright = result['copyright'] as String?;

            await _embedMetadataToFile(
              filePath,
              finalTrack,
              format: 'flac',
              genre: backendGenre ?? genre,
              label: backendLabel ?? label,
              copyright: backendCopyright,
              downloadService: item.service,
            );
            _log.d('Local FLAC metadata embedding completed');
          } catch (e) {
            _log.w('Local FLAC metadata embedding failed: $e');
          }
        }

        if (await shouldAbortWork(
          'during finalization',
          deleteFileOnAbort: filePath,
        )) {
          return;
        }

        if (effectiveSafMode &&
            filePath != null &&
            filePath.isNotEmpty &&
            !isContentUri(filePath) &&
            settings.downloadTreeUri.isNotEmpty) {
          final fallbackName = (finalSafFileName ?? safFileName ?? '').trim();
          if (fallbackName.isNotEmpty) {
            try {
              final resolved = await PlatformBridge.resolveSafFile(
                treeUri: settings.downloadTreeUri,
                relativeDir: effectiveOutputDir,
                fileName: fallbackName,
              );
              final resolvedUri = (resolved['uri'] as String? ?? '').trim();
              final resolvedRelativeDir =
                  (resolved['relative_dir'] as String? ?? '').trim();
              if (resolvedUri.isNotEmpty && isContentUri(resolvedUri)) {
                _log.w('Recovered SAF URI from transient path: $filePath');
                filePath = resolvedUri;
                finalSafFileName = fallbackName;
                if (resolvedRelativeDir.isNotEmpty) {
                  effectiveOutputDir = resolvedRelativeDir;
                }
              } else {
                _log.w(
                  'Failed to recover SAF URI (fileName=$fallbackName, dir=$effectiveOutputDir)',
                );
              }
            } catch (e) {
              _log.w('SAF URI recovery failed: $e');
            }
          } else {
            _log.w(
              'SAF download returned non-URI path without filename metadata: $filePath',
            );
          }
        }

        updateItemStatus(
          item.id,
          DownloadStatus.completed,
          progress: 1.0,
          filePath: filePath,
        );

        if (effectiveSafMode && filePath != null && isContentUri(filePath)) {
          await _saveExternalLrc(
            result: result,
            settings: settings,
            extensionState: extensionState,
            track: trackToDownload,
            service: item.service,
            filePath: filePath,
            storageMode: 'saf',
            downloadTreeUri: settings.downloadTreeUri,
            safRelativeDir: effectiveOutputDir,
            resolveBaseName: () async {
              final currentFinalName = finalSafFileName;
              return currentFinalName != null
                  ? currentFinalName.replaceFirst(RegExp(r'\.[^.]+$'), '')
                  : safBaseName ??
                        await PlatformBridge.sanitizeFilename(
                          '${trackToDownload.artistName} - ${trackToDownload.name}',
                        );
            },
            onFetchError: (e) =>
                _log.w('Failed to fetch lyrics for external LRC: $e'),
          );
        }

        if (filePath != null) {
          await _runPostProcessingHooks(filePath, trackToDownload);
        }

        // Album ReplayGain: update the accumulator path to the final file
        // location.  For SAF downloads the metadata was embedded on a temp
        // copy, so the stored path still points there.  Replace it with the
        // actual output path (SAF content URI or local path) so the later
        // album-gain writer targets the correct file.
        if (filePath != null) {
          _updateAlbumRgFilePath(trackToDownload, filePath);
        }

        // Album ReplayGain: check if all album tracks are now complete and,
        // if so, compute and write album gain/peak to every track file.
        try {
          await _checkAndWriteAlbumReplayGain(trackToDownload);
        } catch (e) {
          _log.w('Album ReplayGain check failed: $e');
        }

        _completedInSession++;

        final historyNotifier = ref.read(downloadHistoryProvider.notifier);
        final existingInHistory =
            await historyNotifier.getBySpotifyIdAsync(trackToDownload.id) ??
            (trackToDownload.isrc != null
                ? await historyNotifier.getByIsrcAsync(trackToDownload.isrc!)
                : null);

        if (wasExisting && existingInHistory != null) {
          _log.i('Track already in library, skipping history update');
          await _notificationService.showDownloadComplete(
            trackName: item.track.name,
            artistName: item.track.artistName,
            completedCount: _completedInSession,
            totalCount: _totalQueuedAtStart,
            alreadyInLibrary: true,
          );
          removeItem(item.id);
          return;
        }

        await _notificationService.showDownloadComplete(
          trackName: item.track.name,
          artistName: item.track.artistName,
          completedCount: _completedInSession,
          totalCount: _totalQueuedAtStart,
          alreadyInLibrary: wasExisting,
        );

        if (filePath != null) {
          final backendBitDepth = result['actual_bit_depth'] as int?;
          final backendSampleRate = result['actual_sample_rate'] as int?;
          final backendFormat =
              normalizeAudioFormatValue(
                result['audio_codec']?.toString() ??
                    result['format']?.toString(),
              ) ??
              normalizeAudioFormatValue(audioFormatForPath(filePath));
          final backendBitrateKbps = readPositiveBitrateKbps(
            result['bitrate'] ?? result['actual_bitrate'],
          );
          final backendGenre = result['genre'] as String?;
          final backendLabel = result['label'] as String?;
          final backendCopyright = result['copyright'] as String?;
          final effectiveGenre =
              normalizeOptionalString(backendGenre) ??
              normalizeOptionalString(genre) ??
              normalizeOptionalString(existingInHistory?.genre);
          final effectiveLabel =
              normalizeOptionalString(backendLabel) ??
              normalizeOptionalString(label) ??
              normalizeOptionalString(existingInHistory?.label);
          final effectiveCopyright =
              normalizeOptionalString(backendCopyright) ??
              normalizeOptionalString(copyright) ??
              normalizeOptionalString(existingInHistory?.copyright);

          int? finalBitDepth = backendBitDepth;
          int? finalSampleRate = backendSampleRate;
          String? finalFormat = backendFormat;
          int? finalBitrateKbps = isLossyAudioFormat(finalFormat)
              ? backendBitrateKbps
              : null;
          final lowerFilePath = filePath.toLowerCase();
          final canProbeFinalMetadata =
              filePath.startsWith('content://') ||
              lowerFilePath.endsWith('.flac') ||
              lowerFilePath.endsWith('.m4a') ||
              lowerFilePath.endsWith('.mp4') ||
              lowerFilePath.endsWith('.aac') ||
              lowerFilePath.endsWith('.mp3') ||
              lowerFilePath.endsWith('.opus') ||
              lowerFilePath.endsWith('.ogg');

          if (canProbeFinalMetadata) {
            try {
              final probed = probedFinalMetadata;
              final metadata = (probed != null && probed['error'] == null)
                  ? probed
                  : await PlatformBridge.readFileMetadata(filePath);
              if (metadata['error'] == null) {
                final probedBitDepth = metadata['bit_depth'] is num
                    ? (metadata['bit_depth'] as num).toInt()
                    : int.tryParse(metadata['bit_depth']?.toString() ?? '');
                final probedSampleRate = metadata['sample_rate'] is num
                    ? (metadata['sample_rate'] as num).toInt()
                    : int.tryParse(metadata['sample_rate']?.toString() ?? '');

                if (probedBitDepth != null && probedBitDepth > 0) {
                  finalBitDepth = probedBitDepth;
                }
                if (probedSampleRate != null && probedSampleRate > 0) {
                  finalSampleRate = probedSampleRate;
                }
                final probedFormat = normalizeAudioFormatValue(
                  metadata['audio_codec']?.toString() ??
                      metadata['format']?.toString(),
                );
                if (probedFormat != null) {
                  finalFormat = probedFormat;
                }
                final probedBitrateKbps = readPositiveBitrateKbps(
                  metadata['bitrate'] ?? metadata['bit_rate'],
                );
                if (probedBitrateKbps != null &&
                    isLossyAudioFormat(finalFormat)) {
                  finalBitrateKbps = probedBitrateKbps;
                }

                final resolvedQuality = resolveDisplayQuality(
                  filePath: filePath,
                  fileName: finalSafFileName,
                  detectedFormat: finalFormat,
                  bitDepth: finalBitDepth,
                  sampleRate: finalSampleRate,
                  bitrateKbps: finalBitrateKbps,
                  storedQuality: actualQuality,
                );
                if (resolvedQuality != null) {
                  actualQuality = resolvedQuality;
                }
              }
            } catch (e) {
              _log.d('Final audio metadata probe failed for $filePath: $e');
            }
          }

          _log.d('Saving to history - coverUrl: ${trackToDownload.coverUrl}');

          final isLossyOutput =
              isLossyAudioFormat(finalFormat) ||
              lowerFilePath.endsWith('.mp3') ||
              lowerFilePath.endsWith('.opus') ||
              lowerFilePath.endsWith('.ogg');
          final historyBitDepth = isLossyOutput ? null : finalBitDepth;
          final historySampleRate = isLossyOutput ? null : finalSampleRate;
          final historyBitrate = isLossyOutput ? finalBitrateKbps : null;

          if (settings.saveDownloadHistory) {
            ref
                .read(downloadHistoryProvider.notifier)
                .addToHistory(
                  _historyItemFromResult(
                    item: item,
                    trackToDownload: trackToDownload,
                    result: result,
                    filePath: filePath,
                    quality: actualQuality,
                    useSaf: effectiveSafMode,
                    downloadTreeUri: settings.downloadTreeUri,
                    safRelativeDir: effectiveOutputDir,
                    safFileName: finalSafFileName ?? safFileName,
                    bitDepth: historyBitDepth,
                    sampleRate: historySampleRate,
                    bitrate: historyBitrate,
                    format: finalFormat,
                    genre: effectiveGenre,
                    label: effectiveLabel,
                    copyright: effectiveCopyright,
                  ),
                );
          }

          removeItem(item.id);
        }
      } else {
        if (await shouldAbortWork('after backend failure')) {
          return;
        }

        var errorMsg = result['error'] as String? ?? 'Download failed';
        final errorTypeStr = result['error_type'] as String? ?? 'unknown';
        final retryAfterSeconds = readPositiveInt(
          result['retry_after_seconds'],
        );
        if (retryAfterSeconds != null && retryAfterSeconds > 0) {
          errorMsg = '$errorMsg retry-after: $retryAfterSeconds';
        }
        if (errorTypeStr == 'cancelled') {
          if (_isPausePending(item.id)) {
            pausedDuringThisRun = true;
            _requeueItemForPause(item.id);
            _log.i('Download was paused by backend cancellation, re-queueing');
          } else {
            _log.i(
              'Download was cancelled by backend, skipping error handling',
            );
            updateItemStatus(item.id, DownloadStatus.skipped);
          }
          return;
        }

        final backendErrorType = _downloadErrorTypeFromBackend(errorTypeStr);
        final errorType = backendErrorType == DownloadErrorType.unknown
            ? _downloadErrorTypeFromMessage(errorMsg)
            : backendErrorType;

        if (errorType == DownloadErrorType.verificationRequired) {
          await _handleVerificationRequiredDownload(
            item,
            errorMsg,
            result['service'] as String?,
          );
          return;
        }
        if (errorType == DownloadErrorType.rateLimit &&
            await _handleRateLimitedDownload(item, errorMsg)) {
          return;
        }

        _log.e('Download failed: $errorMsg (type: $errorTypeStr)');
        updateItemStatus(
          item.id,
          DownloadStatus.failed,
          error: errorMsg,
          errorType: errorType,
        );
        _failedInSession++;

        try {
          await PlatformBridge.cleanupConnections();
        } catch (e) {
          _log.e('Post-failure connection cleanup failed: $e');
        }
      }

      _downloadCount++;
      if (_downloadCount % _cleanupInterval == 0) {
        _log.d(
          'Cleaning up idle connections (after $_downloadCount downloads)...',
        );
        try {
          await PlatformBridge.cleanupConnections();
        } catch (e) {
          _log.e('Connection cleanup failed: $e');
        }
      }
    } catch (e, stackTrace) {
      if (await shouldAbortWork('after exception')) {
        return;
      }

      _log.e('Exception: $e', e, stackTrace);

      String errorMsg = e.toString();
      DownloadErrorType errorType = DownloadErrorType.unknown;

      if (errorMsg.contains('could not find Deezer equivalent') ||
          errorMsg.contains('track not found on Deezer')) {
        errorMsg = 'Track not found on Deezer (Metadata Unavailable)';
        errorType = DownloadErrorType.notFound;
      } else {
        errorType = _downloadErrorTypeFromMessage(errorMsg);
      }

      if (errorType == DownloadErrorType.verificationRequired) {
        await _handleVerificationRequiredDownload(item, errorMsg, item.service);
        return;
      }
      if (errorType == DownloadErrorType.rateLimit &&
          await _handleRateLimitedDownload(item, errorMsg)) {
        return;
      }

      updateItemStatus(
        item.id,
        DownloadStatus.failed,
        error: errorMsg,
        errorType: errorType,
      );
      _failedInSession++;

      try {
        await PlatformBridge.cleanupConnections();
      } catch (cleanupErr) {
        _log.e('Post-exception connection cleanup failed: $cleanupErr');
      }
    } finally {
      if (pausedDuringThisRun) {
        _pausePendingItemIds.remove(item.id);
      }
    }
  }
}

final downloadQueueProvider =
    NotifierProvider<DownloadQueueNotifier, DownloadQueueState>(
      DownloadQueueNotifier.new,
    );

class DownloadQueueLookup {
  final Map<String, DownloadItem> byTrackId;
  final Map<String, DownloadItem> byItemId;
  final Map<String, int> indexByItemId;
  final List<String> itemIds;
  final int queuedCount;
  final int completedCount;
  final int failedCount;
  final int activeDownloadsCount;

  const DownloadQueueLookup.empty()
    : byTrackId = const {},
      byItemId = const {},
      indexByItemId = const {},
      itemIds = const [],
      queuedCount = 0,
      completedCount = 0,
      failedCount = 0,
      activeDownloadsCount = 0;

  DownloadQueueLookup._({
    required Map<String, DownloadItem> byTrackId,
    required Map<String, DownloadItem> byItemId,
    required Map<String, int> indexByItemId,
    required List<String> itemIds,
    required this.queuedCount,
    required this.completedCount,
    required this.failedCount,
    required this.activeDownloadsCount,
  }) : byTrackId = Map.unmodifiable(byTrackId),
       byItemId = Map.unmodifiable(byItemId),
       indexByItemId = Map.unmodifiable(indexByItemId),
       itemIds = List.unmodifiable(itemIds);

  factory DownloadQueueLookup.fromItems(List<DownloadItem> items) {
    final byTrackId = <String, DownloadItem>{};
    final byItemId = <String, DownloadItem>{};
    final indexByItemId = <String, int>{};
    final itemIds = <String>[];
    var queuedCount = 0;
    var completedCount = 0;
    var failedCount = 0;
    var activeDownloadsCount = 0;
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      byTrackId.putIfAbsent(item.track.id, () => item);
      byItemId[item.id] = item;
      indexByItemId[item.id] = index;
      itemIds.add(item.id);
      if (_countsAsQueued(item.status)) queuedCount++;
      if (item.status == DownloadStatus.completed) completedCount++;
      if (item.status == DownloadStatus.failed) failedCount++;
      if (item.status == DownloadStatus.downloading) activeDownloadsCount++;
    }
    return DownloadQueueLookup._(
      byTrackId: byTrackId,
      byItemId: byItemId,
      indexByItemId: indexByItemId,
      itemIds: itemIds,
      queuedCount: queuedCount,
      completedCount: completedCount,
      failedCount: failedCount,
      activeDownloadsCount: activeDownloadsCount,
    );
  }

  static bool _countsAsQueued(DownloadStatus status) =>
      status == DownloadStatus.queued ||
      status == DownloadStatus.downloading ||
      status == DownloadStatus.finalizing;

  static int _deltaForStatus({
    required DownloadStatus previous,
    required DownloadStatus next,
    required bool Function(DownloadStatus status) predicate,
  }) {
    final had = predicate(previous);
    final has = predicate(next);
    if (had == has) return 0;
    return has ? 1 : -1;
  }

  DownloadQueueLookup updatedForIndices({
    required List<DownloadItem> previousItems,
    required List<DownloadItem> nextItems,
    required Iterable<int> changedIndices,
  }) {
    if (previousItems.length != nextItems.length ||
        itemIds.length != nextItems.length ||
        indexByItemId.length != nextItems.length) {
      return DownloadQueueLookup.fromItems(nextItems);
    }

    final normalizedChanged = <int>[];
    for (final index in changedIndices) {
      if (index < 0 || index >= nextItems.length) {
        return DownloadQueueLookup.fromItems(nextItems);
      }
      normalizedChanged.add(index);
    }
    if (normalizedChanged.isEmpty) return this;

    var nextQueuedCount = queuedCount;
    var nextCompletedCount = completedCount;
    var nextFailedCount = failedCount;
    var nextActiveDownloadsCount = activeDownloadsCount;
    Map<String, DownloadItem>? nextByItemId;
    Map<String, DownloadItem>? nextByTrackId;

    for (final index in normalizedChanged) {
      final previous = previousItems[index];
      final next = nextItems[index];
      if (previous.id != next.id || previous.track.id != next.track.id) {
        return DownloadQueueLookup.fromItems(nextItems);
      }

      nextByItemId ??= Map<String, DownloadItem>.from(byItemId);
      nextByItemId[next.id] = next;
      if (byTrackId[next.track.id]?.id == previous.id) {
        nextByTrackId ??= Map<String, DownloadItem>.from(byTrackId);
        nextByTrackId[next.track.id] = next;
      }
      nextQueuedCount += _deltaForStatus(
        previous: previous.status,
        next: next.status,
        predicate: _countsAsQueued,
      );
      nextCompletedCount += _deltaForStatus(
        previous: previous.status,
        next: next.status,
        predicate: (status) => status == DownloadStatus.completed,
      );
      nextFailedCount += _deltaForStatus(
        previous: previous.status,
        next: next.status,
        predicate: (status) => status == DownloadStatus.failed,
      );
      nextActiveDownloadsCount += _deltaForStatus(
        previous: previous.status,
        next: next.status,
        predicate: (status) => status == DownloadStatus.downloading,
      );
    }

    return DownloadQueueLookup._(
      byTrackId: nextByTrackId ?? byTrackId,
      byItemId: nextByItemId ?? byItemId,
      indexByItemId: indexByItemId,
      itemIds: itemIds,
      queuedCount: nextQueuedCount,
      completedCount: nextCompletedCount,
      failedCount: nextFailedCount,
      activeDownloadsCount: nextActiveDownloadsCount,
    );
  }
}

final downloadQueueLookupProvider = Provider<DownloadQueueLookup>((ref) {
  return ref.watch(downloadQueueProvider.select((s) => s.lookup));
});
