import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:spotiflac_android/services/ffmpeg_service.dart';
import 'package:spotiflac_android/services/platform_bridge.dart';
import 'package:spotiflac_android/l10n/l10n.dart';
import 'package:spotiflac_android/utils/app_bar_layout.dart';
import 'package:spotiflac_android/utils/nav_bar_inset.dart';
import 'package:spotiflac_android/widgets/settings_group.dart';
import 'package:spotiflac_android/utils/file_access.dart';
import 'package:spotiflac_android/utils/lyrics_metadata_helper.dart';
import 'package:spotiflac_android/models/download_item.dart';
import 'package:spotiflac_android/models/track.dart';
import 'package:spotiflac_android/models/unified_library_item.dart';
import 'package:spotiflac_android/providers/download_queue_provider.dart';
import 'package:spotiflac_android/providers/extension_provider.dart';
import 'package:spotiflac_android/providers/library_collections_provider.dart';
import 'package:spotiflac_android/providers/settings_provider.dart';
import 'package:spotiflac_android/providers/local_library_provider.dart';
import 'package:spotiflac_android/providers/playback_provider.dart';
import 'package:spotiflac_android/providers/music_player_provider.dart';
import 'package:spotiflac_android/services/music_player_service.dart';
import 'package:spotiflac_android/services/library_database.dart';
import 'package:spotiflac_android/services/local_track_redownload_service.dart';
import 'package:spotiflac_android/services/batch_track_actions.dart';
import 'package:spotiflac_android/services/downloaded_embedded_cover_resolver.dart';
import 'package:spotiflac_android/screens/track_metadata_screen.dart';
import 'package:spotiflac_android/screens/favorite_artists_screen.dart';
import 'package:spotiflac_android/screens/downloaded_album_screen.dart';
import 'package:spotiflac_android/widgets/re_enrich_field_dialog.dart';
import 'package:spotiflac_android/widgets/batch_progress_dialog.dart';
import 'package:spotiflac_android/widgets/cached_cover_image.dart';
import 'package:spotiflac_android/widgets/audio_quality_badges.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:spotiflac_android/services/cover_cache_manager.dart';
import 'package:spotiflac_android/screens/library_tracks_folder_screen.dart';
import 'package:spotiflac_android/screens/local_album_screen.dart';
import 'package:spotiflac_android/utils/clickable_metadata.dart';
import 'package:spotiflac_android/utils/path_match_keys.dart';
import 'package:spotiflac_android/utils/string_utils.dart';
import 'package:spotiflac_android/widgets/download_service_picker.dart';
import 'package:spotiflac_android/widgets/animation_utils.dart';
import 'package:spotiflac_android/widgets/selection_action_button.dart';
import 'package:spotiflac_android/widgets/selection_bottom_bar.dart';

part 'queue_tab_helpers.dart';
part 'queue_tab_widgets.dart';
part 'queue_tab_selection.dart';
part 'queue_tab_navigation.dart';
part 'queue_tab_collection_items.dart';
part 'queue_tab_filter_widgets.dart';
part 'queue_tab_batch_actions.dart';
part 'queue_tab_item_widgets.dart';

String _formatDownloadSizeMB(num bytes) => '${formatMegabytes(bytes)} MB';

String _formatDownloadProgressLabel(BuildContext context, DownloadItem item) {
  final progress = item.progress.clamp(0.0, 1.0);
  final speedSuffix = item.speedMBps > 0
      ? ' • ${item.speedMBps.toStringAsFixed(1)} MB/s'
      : '';

  if (item.bytesTotal > 0) {
    final received = item.bytesReceived > 0
        ? item.bytesReceived
        : item.bytesTotal * progress;
    final percent = (progress * 100).toStringAsFixed(0);
    return '${_formatDownloadSizeMB(received)} / ${_formatDownloadSizeMB(item.bytesTotal)} • $percent%$speedSuffix';
  }

  if (item.bytesReceived > 0) {
    final canEstimateTotal = progress > 0.01 && progress < 0.995;
    if (canEstimateTotal) {
      final estimatedTotal = item.bytesReceived / progress;
      if (estimatedTotal > item.bytesReceived) {
        return '${_formatDownloadSizeMB(item.bytesReceived)} / ~${_formatDownloadSizeMB(estimatedTotal)}$speedSuffix';
      }
    }
    return '${_formatDownloadSizeMB(item.bytesReceived)}$speedSuffix';
  }

  if (progress > 0) {
    final percent = (progress * 100).toStringAsFixed(0);
    return '$percent%$speedSuffix';
  }

  if (item.speedMBps > 0) {
    return context.l10n.queueDownloadSpeedStatus(
      item.speedMBps.toStringAsFixed(1),
    );
  }

  return context.l10n.queueDownloadStarting;
}

String _formatDownloadStatusLine(BuildContext context, DownloadItem item) {
  final base = _formatDownloadProgressLabel(context, item);
  final eta = _formatDownloadEta(item);
  return eta == null ? base : '$base • $eta';
}

String? _formatDownloadEta(DownloadItem item) {
  if (item.speedMBps <= 0 || item.bytesTotal <= 0) return null;
  final received = item.bytesReceived > 0
      ? item.bytesReceived
      : (item.bytesTotal * item.progress).round();
  final remaining = item.bytesTotal - received;
  if (remaining <= 0) return null;
  final seconds = remaining / (item.speedMBps * 1024 * 1024);
  if (!seconds.isFinite || seconds > 3600) return null;
  if (seconds < 60) return '~${seconds.round()}s';
  final minutes = (seconds / 60).floor();
  final secs = (seconds % 60).round();
  return '~${minutes}m${secs.toString().padLeft(2, '0')}s';
}

class QueueTab extends ConsumerStatefulWidget {
  final PageController? parentPageController;
  final int parentPageIndex;
  final int? nextPageIndex;

  const QueueTab({
    super.key,
    this.parentPageController,
    this.parentPageIndex = 1,
    this.nextPageIndex,
  });

  @override
  ConsumerState<QueueTab> createState() => _QueueTabState();
}

class _QueueTabState extends ConsumerState<QueueTab> {
  static const int _libraryPageSize = 300;
  final _FileExistsListenableCache _fileExistsCache =
      _FileExistsListenableCache();
  static const int _maxSearchIndexCacheSize = 4000;
  static const double _libraryGridMinExtent = 92;
  static const double _libraryGridDefaultExtent = 126;
  static const double _libraryGridMaxExtent = 190;
  bool _embeddedCoverRefreshScheduled = false;
  // Version counter to trigger targeted cover image rebuilds
  // without rebuilding the entire widget tree via setState.
  final ValueNotifier<int> _embeddedCoverVersion = ValueNotifier<int>(0);

  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  OverlayEntry? _selectionOverlayEntry;
  List<UnifiedLibraryItem> _selectionOverlayItems = const [];
  double _selectionOverlayBottomPadding = 0;

  /// Keeps the selection overlays hidden while a modal launched from the
  /// selection toolbar is open, so they don't reappear over its animation.
  bool _suppressSelectionOverlay = false;

  bool _isPlaylistSelectionMode = false;
  final Set<String> _selectedPlaylistIds = {};
  OverlayEntry? _playlistSelectionOverlayEntry;
  List<UserPlaylistCollection> _playlistSelectionOverlayItems = const [];
  double _playlistSelectionOverlayBottomPadding = 0;

  PageController? _filterPageController;
  final List<String> _filterModes = ['all', 'albums', 'singles'];
  bool _isPageControllerInitialized = false;
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

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  Timer? _searchDebounce;
  List<DownloadHistoryItem>? _historyItemsCache;
  List<LocalLibraryItem>? _localLibraryItemsCache;
  _HistoryStats? _historyStatsCache;
  final Map<String, Track> _completionBridge = {};
  final Map<String, DateTime> _completionBridgeAt = {};
  final Set<String> _bridgePrecacheStarted = {};
  final Map<String, String> _searchIndexCache = {};
  final Map<String, String> _localSearchIndexCache = {};
  Map<String, List<DownloadHistoryItem>> _filteredHistoryCache = const {};
  List<DownloadHistoryItem>? _filterItemsCache;
  String _filterQueryCache = '';
  bool _filterRefreshScheduled = false;
  bool _isFilteringHistory = false;
  int _filterRequestId = 0;
  static const int _filterIsolateThreshold = 800;
  List<LocalLibraryItem>? _localFilterItemsCache;
  String _localFilterQueryCache = '';
  List<LocalLibraryItem> _filteredLocalItemsCache = const [];
  final Map<String, _UnifiedCacheEntry> _unifiedItemsCache = {};
  List<DownloadHistoryItem>? _cachedUnifiedDownloadedSource;
  List<UnifiedLibraryItem> _cachedUnifiedDownloaded = const [];
  List<LocalLibraryItem>? _cachedUnifiedLocalSource;
  List<UnifiedLibraryItem> _cachedUnifiedLocal = const [];
  List<DownloadHistoryItem>? _cachedDownloadedPathKeysSource;
  Set<String> _cachedDownloadedPathKeys = const <String>{};
  final Map<String, List<String>> _localPathMatchKeysCache = {};
  List<LocalLibraryItem>? _cachedLocalSinglesSource;
  Map<String, int>? _cachedLocalSinglesAlbumCountsSource;
  List<LocalLibraryItem> _cachedLocalSingles = const [];
  final Map<String, _FilterContentData> _filterContentDataCache = {};
  List<DownloadHistoryItem>? _filterCacheAllHistoryItems;
  _HistoryStats? _filterCacheHistoryStats;
  List<LocalLibraryItem>? _filterCacheLocalLibraryItems;
  LibraryCollectionsState? _filterCacheCollectionState;
  String _filterCacheSearchQuery = '';
  String? _filterCacheSource;
  String? _filterCacheQuality;
  String? _filterCacheFormat;
  String? _filterCacheMetadata;
  String _filterCacheSortMode = 'latest';
  String? _filterSource;
  String? _filterQuality;
  String? _filterFormat;
  String? _filterMetadata;
  String _sortMode = 'latest';
  double _libraryGridExtent = _libraryGridDefaultExtent;
  double? _libraryGridScaleStartExtent;
  final Map<String, int> _libraryPageOffsetByFilter = {};
  bool _libraryPageLoadScheduled = false;
  final Map<_QueueLibraryCountsRequest, QueueLibraryCounts>
  _queueLibraryCountsCache = {};
  final Map<_QueueLibraryPageRequest, _QueueLibraryPageData>
  _queueLibraryPageDataCache = {};
  DateTime? _lastBlankLibraryRepairAt;

  double _effectiveTextScale() {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    if (textScale < 1.0) return 1.0;
    if (textScale > 1.4) return 1.4;
    return textScale;
  }

  double _queueCoverSize() {
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final scale = (shortestSide / 390).clamp(0.82, 1.0);
    final textScale = _effectiveTextScale();
    return (56 * scale * (1 + ((textScale - 1) * 0.12))).clamp(46.0, 56.0);
  }

  double get _libraryAlbumGridExtent =>
      (_libraryGridExtent * 1.45).clamp(150.0, 300.0);

  /// setState is @protected, so the extension part files route rebuilds
  /// through this forwarder.
  void _setState(VoidCallback fn) => setState(fn);

  void _handleLibraryGridScaleStart(ScaleStartDetails details) {
    if (details.pointerCount < 2) return;
    _libraryGridScaleStartExtent = _libraryGridExtent;
  }

  void _handleLibraryGridScaleUpdate(ScaleUpdateDetails details) {
    final startExtent = _libraryGridScaleStartExtent;
    if (startExtent == null || details.pointerCount < 2) return;

    final nextExtent = (startExtent * details.scale).clamp(
      _libraryGridMinExtent,
      _libraryGridMaxExtent,
    );
    if ((nextExtent - _libraryGridExtent).abs() < 0.5) return;
    setState(() => _libraryGridExtent = nextExtent);
  }

  void _handleLibraryGridScaleEnd(ScaleEndDetails details) {
    _libraryGridScaleStartExtent = null;
  }

  @override
  void initState() {
    super.initState();
  }

  void _initializePageController() {
    if (_isPageControllerInitialized) return;
    _isPageControllerInitialized = true;
    final currentFilter = ref.read(settingsProvider).historyFilterMode;
    final initialPage = _filterModes.indexOf(currentFilter).clamp(0, 2);
    _filterPageController = PageController(initialPage: initialPage);
  }

  @override
  void dispose() {
    _hideSelectionOverlay();
    _hidePlaylistSelectionOverlay();
    _fileExistsCache.dispose();
    _embeddedCoverVersion.dispose();
    _filterPageController?.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final normalized = value.trim().toLowerCase();
    _searchDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted || _searchQuery == normalized) return;
      setState(() {
        _searchQuery = normalized;
        _resetLibraryPaging();
      });
      _requestFilterRefresh();
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    if (_searchQuery.isEmpty) return;
    setState(() {
      _searchQuery = '';
      _resetLibraryPaging();
    });
    _requestFilterRefresh();
  }

  int _libraryPageOffsetFor(String filterMode) =>
      _libraryPageOffsetByFilter[filterMode] ?? 0;

  void _resetLibraryPaging() {
    _libraryPageOffsetByFilter.clear();
    _queueLibraryPageDataCache.clear();
  }

  void _loadMoreLibraryItems({
    required String filterMode,
    required bool hasMoreLibrary,
  }) {
    if (_libraryPageLoadScheduled) return;
    _libraryPageLoadScheduled = true;
    setState(() {
      if (hasMoreLibrary) {
        _libraryPageOffsetByFilter[filterMode] =
            _libraryPageOffsetFor(filterMode) + _libraryPageSize;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _libraryPageLoadScheduled = false;
    });
  }

  QueueLibraryCounts _resolveQueueLibraryCounts(
    AsyncValue<QueueLibraryCounts> value,
    _QueueLibraryCountsRequest request,
  ) {
    return value.maybeWhen(
      data: (counts) {
        _queueLibraryCountsCache[request] = counts;
        _trimQueueLibraryCountsCache();
        return counts;
      },
      orElse: () =>
          _queueLibraryCountsCache[request] ??
          const QueueLibraryCounts(
            allTrackCount: 0,
            albumCount: 0,
            singleTrackCount: 0,
          ),
    );
  }

  _QueueLibraryPageData _resolveQueueLibraryPageData(
    AsyncValue<_QueueLibraryPageData>? value,
    _QueueLibraryPageRequest request,
  ) {
    if (value != null) {
      final liveData = value.asData?.value;
      if (liveData != null) {
        _queueLibraryPageDataCache[request] = liveData;
        _trimQueueLibraryPageDataCache(protectedRequest: request);
      }
      value.whenOrNull(
        data: (data) {
          _queueLibraryPageDataCache[request] = data;
          _trimQueueLibraryPageDataCache(protectedRequest: request);
        },
      );
    }

    final pages = <_QueueLibraryPageData>[];
    for (var offset = 0; offset <= request.offset; offset += _libraryPageSize) {
      final page =
          _queueLibraryPageDataCache[_QueueLibraryPageRequest(
            filterMode: request.filterMode,
            limit: request.limit,
            offset: offset,
            searchQuery: request.searchQuery,
            filterSource: request.filterSource,
            filterQuality: request.filterQuality,
            filterFormat: request.filterFormat,
            filterMetadata: request.filterMetadata,
            sortMode: request.sortMode,
            localLibraryEnabled: request.localLibraryEnabled,
          )];
      if (page != null) pages.add(page);
    }

    return _QueueLibraryPageData.combine(pages);
  }

  void _invalidateLibraryDataCaches() {
    _queueLibraryCountsCache.clear();
    _queueLibraryPageDataCache.clear();
    _unifiedItemsCache.clear();
    _invalidateFilterContentCache();
  }

  void _scheduleBlankLibraryRepair({
    required bool hasQueueItems,
    required bool hasLibraryContent,
    required bool hasAnyLibraryItems,
    required bool isLibraryPageLoading,
  }) {
    if (!hasQueueItems ||
        hasLibraryContent ||
        hasAnyLibraryItems ||
        isLibraryPageLoading) {
      return;
    }
    final now = DateTime.now();
    final last = _lastBlankLibraryRepairAt;
    if (last != null && now.difference(last) < const Duration(seconds: 8)) {
      return;
    }
    _lastBlankLibraryRepairAt = now;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _invalidateLibraryDataCaches();
      ref.read(downloadHistoryProvider.notifier).reloadFromStorage();
      ref.read(localLibraryProvider.notifier).reloadFromStorage();
      setState(() {});
    });
  }

  void _trimQueueLibraryCountsCache() {
    const maxCountEntries = 24;
    while (_queueLibraryCountsCache.length > maxCountEntries) {
      _queueLibraryCountsCache.remove(_queueLibraryCountsCache.keys.first);
    }
  }

  bool _isProtectedQueueLibraryPage(
    _QueueLibraryPageRequest request,
    _QueueLibraryPageRequest protectedRequest,
  ) {
    return request.filterMode == protectedRequest.filterMode &&
        request.limit == protectedRequest.limit &&
        request.offset <= protectedRequest.offset &&
        request.searchQuery == protectedRequest.searchQuery &&
        request.filterSource == protectedRequest.filterSource &&
        request.filterQuality == protectedRequest.filterQuality &&
        request.filterFormat == protectedRequest.filterFormat &&
        request.filterMetadata == protectedRequest.filterMetadata &&
        request.sortMode == protectedRequest.sortMode &&
        request.localLibraryEnabled == protectedRequest.localLibraryEnabled;
  }

  void _trimQueueLibraryPageDataCache({
    required _QueueLibraryPageRequest protectedRequest,
  }) {
    const maxPageEntries = 96;
    while (_queueLibraryPageDataCache.length > maxPageEntries) {
      final removableKey = _queueLibraryPageDataCache.keys
          .where(
            (request) =>
                !_isProtectedQueueLibraryPage(request, protectedRequest),
          )
          .firstOrNull;
      if (removableKey == null) break;
      _queueLibraryPageDataCache.remove(removableKey);
    }
  }

  bool _handleLibraryScrollNotification({
    required ScrollNotification notification,
    required String filterMode,
    required bool hasMoreLibrary,
    required bool isPageLoading,
  }) {
    if (isPageLoading || !hasMoreLibrary || notification.depth != 0) {
      return false;
    }

    final metrics = notification.metrics;
    if (metrics.maxScrollExtent <= 0) return false;
    final threshold = metrics.maxScrollExtent * 0.7;
    final nearEnd =
        metrics.pixels >= threshold ||
        metrics.extentAfter <= metrics.viewportDimension * 1.5;
    if (!nearEnd) return false;

    _loadMoreLibraryItems(
      filterMode: filterMode,
      hasMoreLibrary: hasMoreLibrary,
    );
    return false;
  }

  void _invalidateFilterContentCache() {
    _filterContentDataCache.clear();
    _filterCacheAllHistoryItems = null;
    _filterCacheHistoryStats = null;
    _filterCacheLocalLibraryItems = null;
    _filterCacheCollectionState = null;
  }

  // ignore: unused_element
  void _prepareFilterContentCache({
    required List<DownloadHistoryItem> allHistoryItems,
    required _HistoryStats historyStats,
    required List<LocalLibraryItem> localLibraryItems,
    required LibraryCollectionsState collectionState,
  }) {
    final isCacheValid =
        identical(_filterCacheAllHistoryItems, allHistoryItems) &&
        identical(_filterCacheHistoryStats, historyStats) &&
        identical(_filterCacheLocalLibraryItems, localLibraryItems) &&
        identical(_filterCacheCollectionState, collectionState) &&
        _filterCacheSearchQuery == _searchQuery &&
        _filterCacheSource == _filterSource &&
        _filterCacheQuality == _filterQuality &&
        _filterCacheFormat == _filterFormat &&
        _filterCacheMetadata == _filterMetadata &&
        _filterCacheSortMode == _sortMode;

    if (isCacheValid) {
      return;
    }

    _filterContentDataCache.clear();
    _filterCacheAllHistoryItems = allHistoryItems;
    _filterCacheHistoryStats = historyStats;
    _filterCacheLocalLibraryItems = localLibraryItems;
    _filterCacheCollectionState = collectionState;
    _filterCacheSearchQuery = _searchQuery;
    _filterCacheSource = _filterSource;
    _filterCacheQuality = _filterQuality;
    _filterCacheFormat = _filterFormat;
    _filterCacheMetadata = _filterMetadata;
    _filterCacheSortMode = _sortMode;
  }

  // ignore: unused_element
  void _ensureHistoryCaches(
    List<DownloadHistoryItem> items,
    List<LocalLibraryItem> localItems,
    _HistoryStats historyStats,
  ) {
    final historyChanged = !identical(items, _historyItemsCache);
    final localChanged = !identical(localItems, _localLibraryItemsCache);

    if (!historyChanged && !localChanged) return;

    _historyItemsCache = items;
    _localLibraryItemsCache = localItems;
    _historyStatsCache = historyStats;
    if (historyChanged) {
      _searchIndexCache.clear();
      _cachedUnifiedDownloadedSource = null;
      _cachedUnifiedDownloaded = const [];
      _cachedDownloadedPathKeysSource = null;
      _cachedDownloadedPathKeys = const <String>{};
    }
    if (localChanged) {
      _localSearchIndexCache.clear();
      _localPathMatchKeysCache.clear();
      _localFilterItemsCache = null;
      _localFilterQueryCache = '';
      _filteredLocalItemsCache = const [];
      _cachedLocalSinglesSource = null;
      _cachedLocalSinglesAlbumCountsSource = null;
      _cachedLocalSingles = const [];
      _cachedUnifiedLocalSource = null;
      _cachedUnifiedLocal = const [];
    }
    _unifiedItemsCache.clear();
    _invalidateFilterContentCache();

    if (historyChanged) {
      final validPaths = items
          .map((item) => _cleanFilePath(item.filePath))
          .where((path) => path.isNotEmpty)
          .toSet();
      DownloadedEmbeddedCoverResolver.invalidatePathsNotIn(validPaths);
    }
    _requestFilterRefresh();
  }

  String _buildSearchKey(DownloadHistoryItem item) {
    return '${item.trackName} ${item.artistName} ${item.albumName}'
        .toLowerCase();
  }

  String _buildLocalSearchKey(LocalLibraryItem item) {
    return '${item.trackName} ${item.artistName} ${item.albumName}'
        .toLowerCase();
  }

  String _historySearchKeyForItem(DownloadHistoryItem item) {
    final cached = _searchIndexCache[item.id];
    if (cached != null) return cached;

    final searchKey = _buildSearchKey(item);
    _searchIndexCache[item.id] = searchKey;
    while (_searchIndexCache.length > _maxSearchIndexCacheSize) {
      _searchIndexCache.remove(_searchIndexCache.keys.first);
    }
    return searchKey;
  }

  String _localSearchKeyForItem(LocalLibraryItem item) {
    final cached = _localSearchIndexCache[item.id];
    if (cached != null) return cached;

    final searchKey = _buildLocalSearchKey(item);
    _localSearchIndexCache[item.id] = searchKey;
    while (_localSearchIndexCache.length > _maxSearchIndexCacheSize) {
      _localSearchIndexCache.remove(_localSearchIndexCache.keys.first);
    }
    return searchKey;
  }

  List<UnifiedLibraryItem> _unifiedDownloadedItems(
    List<DownloadHistoryItem> items,
  ) {
    if (identical(items, _cachedUnifiedDownloadedSource)) {
      return _cachedUnifiedDownloaded;
    }
    final unified = items
        .map(UnifiedLibraryItem.fromDownloadHistory)
        .toList(growable: false);
    _cachedUnifiedDownloadedSource = items;
    _cachedUnifiedDownloaded = unified;
    return unified;
  }

  List<UnifiedLibraryItem> _unifiedLocalItems(List<LocalLibraryItem> items) {
    if (identical(items, _cachedUnifiedLocalSource)) {
      return _cachedUnifiedLocal;
    }
    final unified = items
        .map(UnifiedLibraryItem.fromLocalLibrary)
        .toList(growable: false);
    _cachedUnifiedLocalSource = items;
    _cachedUnifiedLocal = unified;
    return unified;
  }

  Set<String> _downloadedPathKeys(List<DownloadHistoryItem> historyItems) {
    if (identical(historyItems, _cachedDownloadedPathKeysSource)) {
      return _cachedDownloadedPathKeys;
    }
    final keys = <String>{};
    for (final item in historyItems) {
      keys.addAll(buildPathMatchKeys(item.filePath));
    }
    _cachedDownloadedPathKeysSource = historyItems;
    _cachedDownloadedPathKeys = Set<String>.unmodifiable(keys);
    return _cachedDownloadedPathKeys;
  }

  List<String> _localPathMatchKeys(LocalLibraryItem item) {
    final cached = _localPathMatchKeysCache[item.id];
    if (cached != null) return cached;
    final keys = buildPathMatchKeys(item.filePath).toList(growable: false);
    _localPathMatchKeysCache[item.id] = keys;
    return keys;
  }

  List<LocalLibraryItem> _localSingleItems(
    List<LocalLibraryItem> items,
    Map<String, int> localAlbumCounts,
  ) {
    if (identical(items, _cachedLocalSinglesSource) &&
        identical(localAlbumCounts, _cachedLocalSinglesAlbumCountsSource)) {
      return _cachedLocalSingles;
    }

    final singles = items
        .where((item) => (localAlbumCounts[item.albumKey] ?? 0) == 1)
        .toList(growable: false);
    _cachedLocalSinglesSource = items;
    _cachedLocalSinglesAlbumCountsSource = localAlbumCounts;
    _cachedLocalSingles = singles;
    return singles;
  }

  List<LocalLibraryItem> _filterLocalItems(
    List<LocalLibraryItem> items,
    String query,
  ) {
    if (query.isEmpty) return items;
    if (identical(items, _localFilterItemsCache) &&
        query == _localFilterQueryCache) {
      return _filteredLocalItemsCache;
    }

    final filtered = items
        .where((item) {
          final searchKey = _localSearchKeyForItem(item);
          return searchKey.contains(query);
        })
        .toList(growable: false);

    _localFilterItemsCache = items;
    _localFilterQueryCache = query;
    _filteredLocalItemsCache = filtered;
    return filtered;
  }

  bool _isFilterCacheValid(List<DownloadHistoryItem> items, String query) {
    return identical(items, _filterItemsCache) && query == _filterQueryCache;
  }

  void _requestFilterRefresh() {
    if (_filterRefreshScheduled) return;
    _filterRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _filterRefreshScheduled = false;
      if (!mounted) return;
      _scheduleHistoryFilterUpdate();
    });
  }

  void _scheduleHistoryFilterUpdate() {
    final items = _historyItemsCache;
    if (items == null) return;
    final query = _searchQuery;
    if (_isFilterCacheValid(items, query)) return;

    final albumCounts =
        _historyStatsCache?.albumCounts ?? const <String, int>{};
    if (items.isEmpty) {
      setState(() {
        _filteredHistoryCache = const {};
        _filterItemsCache = items;
        _filterQueryCache = query;
        _isFilteringHistory = false;
      });
      return;
    }

    if (items.length <= _filterIsolateThreshold) {
      final filteredAll = _applyHistorySearchFilter(items, query);
      final filteredAlbums = _filterHistoryByAlbumCount(
        filteredAll,
        albumCounts,
        2,
      );
      final filteredSingles = _filterHistoryByAlbumCount(
        filteredAll,
        albumCounts,
        1,
      );
      setState(() {
        _filteredHistoryCache = {
          'all': filteredAll,
          'albums': filteredAlbums,
          'singles': filteredSingles,
        };
        _filterItemsCache = items;
        _filterQueryCache = query;
        _isFilteringHistory = false;
      });
      return;
    }

    if (!_isFilteringHistory) {
      setState(() => _isFilteringHistory = true);
    }

    final requestId = ++_filterRequestId;
    final includeSearchKey = query.isNotEmpty;
    final entries = List<List<String>>.generate(items.length, (index) {
      final item = items[index];
      final albumKey =
          '${item.albumName.toLowerCase()}|${(item.albumArtist ?? item.artistName).toLowerCase()}';
      if (!includeSearchKey) {
        return [item.id, albumKey];
      }
      final searchKey = _historySearchKeyForItem(item);
      return [item.id, albumKey, searchKey];
    }, growable: false);
    final payload = <String, Object>{
      'entries': entries,
      'albumCounts': albumCounts,
      'query': query,
    };

    compute(_filterHistoryInIsolate, payload).then((result) {
      if (!mounted || requestId != _filterRequestId) return;
      final itemsById = {for (final item in items) item.id: item};
      final filtered = <String, List<DownloadHistoryItem>>{};
      for (final entry in result.entries) {
        filtered[entry.key] = entry.value
            .map((id) => itemsById[id])
            .whereType<DownloadHistoryItem>()
            .toList(growable: false);
      }
      setState(() {
        _filteredHistoryCache = filtered;
        _filterItemsCache = items;
        _filterQueryCache = query;
        _isFilteringHistory = false;
      });
    });
  }

  List<DownloadHistoryItem> _resolveHistoryItems({
    required String filterMode,
    required List<DownloadHistoryItem> allHistoryItems,
    required Map<String, int> albumCounts,
  }) {
    final query = _searchQuery;
    if (_isFilterCacheValid(allHistoryItems, query)) {
      final cached = _filteredHistoryCache[filterMode];
      if (cached != null) return cached;
    }
    if (allHistoryItems.isEmpty) return const [];
    if (query.isEmpty && filterMode == 'all') return allHistoryItems;
    if (allHistoryItems.length <= _filterIsolateThreshold) {
      return _filterHistoryItems(
        allHistoryItems,
        filterMode,
        albumCounts,
        query,
      );
    }
    return const [];
  }

  List<DownloadHistoryItem> _applyHistorySearchFilter(
    List<DownloadHistoryItem> items,
    String searchQuery,
  ) {
    if (searchQuery.isEmpty) return items;
    final query = searchQuery;
    return items
        .where((item) {
          final searchKey = _historySearchKeyForItem(item);
          return searchKey.contains(query);
        })
        .toList(growable: false);
  }

  List<DownloadHistoryItem> _filterHistoryByAlbumCount(
    List<DownloadHistoryItem> items,
    Map<String, int> albumCounts,
    int targetCount,
  ) {
    return items
        .where((item) {
          final key =
              '${item.albumName.toLowerCase()}|${(item.albumArtist ?? item.artistName).toLowerCase()}';
          final count = albumCounts[key] ?? 0;
          return targetCount == 1 ? count == 1 : count >= targetCount;
        })
        .toList(growable: false);
  }

  bool _shouldShowFilteringIndicator({
    required List<DownloadHistoryItem> allHistoryItems,
    required String filterMode,
  }) {
    if (allHistoryItems.isEmpty) return false;
    if (_searchQuery.isEmpty && filterMode == 'all') return false;
    if (allHistoryItems.length <= _filterIsolateThreshold) return false;
    return !_isFilterCacheValid(allHistoryItems, _searchQuery) ||
        _isFilteringHistory;
  }

  void _onFilterPageChanged(int index) {
    HapticFeedback.selectionClick();
    final filterMode = _filterModes[index];
    ref.read(settingsProvider.notifier).setHistoryFilterMode(filterMode);
  }

  void _animateToFilterPage(int index) {
    if (index >= 0 && index < _filterModes.length) {
      final filterMode = _filterModes[index];
      if (ref.read(settingsProvider).historyFilterMode != filterMode) {
        ref.read(settingsProvider.notifier).setHistoryFilterMode(filterMode);
      }
    }
    _filterPageController?.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _onEmbeddedCoverChanged() {
    if (!mounted || _embeddedCoverRefreshScheduled) return;
    _embeddedCoverRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _embeddedCoverRefreshScheduled = false;
      if (mounted) {
        _embeddedCoverVersion.value++;
      }
    });
  }

  Future<void> _scheduleDownloadedEmbeddedCoverRefreshForPath(
    String? filePath, {
    int? beforeModTime,
    bool force = false,
  }) async {
    await DownloadedEmbeddedCoverResolver.scheduleRefreshForPath(
      filePath,
      beforeModTime: beforeModTime,
      force: force,
      onChanged: _onEmbeddedCoverChanged,
    );
  }

  String? _resolveDownloadedEmbeddedCoverPath(String? filePath) {
    return DownloadedEmbeddedCoverResolver.resolve(
      filePath,
      onChanged: _onEmbeddedCoverChanged,
    );
  }

  ValueListenable<bool> _fileExistsListenable(String? filePath) {
    return _fileExistsCache.listenable(filePath);
  }

  int get _activeFilterCount {
    int count = 0;
    if (_filterSource != null) count++;
    if (_filterQuality != null) count++;
    if (_filterFormat != null) count++;
    if (_filterMetadata != null) count++;
    return count;
  }

  void _resetFilters() {
    setState(() {
      _filterSource = null;
      _filterQuality = null;
      _filterFormat = null;
      _filterMetadata = null;
      _sortMode = 'latest';
      _resetLibraryPaging();
      _unifiedItemsCache.clear();
      _invalidateFilterContentCache();
    });
  }

  String _fileExtLower(String filePath) {
    final dotIndex = filePath.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == filePath.length - 1) {
      return '';
    }
    return filePath.substring(dotIndex + 1).toLowerCase();
  }

  String _itemFormatLower(UnifiedLibraryItem item) {
    final localFormat = normalizeOptionalString(item.localItem?.format);
    if (localFormat != null) {
      return localFormat.toLowerCase().replaceAll('-', '_');
    }
    final historyFormat = normalizeOptionalString(item.historyItem?.format);
    if (historyFormat != null) {
      return historyFormat.toLowerCase().replaceAll('-', '_');
    }
    return _fileExtLower(item.filePath);
  }

  List<UnifiedLibraryItem> _applyAdvancedFilters(
    List<UnifiedLibraryItem> items,
  ) {
    List<UnifiedLibraryItem> filtered;
    if (_activeFilterCount == 0) {
      filtered = items;
    } else {
      filtered = items
          .where((item) {
            if (_filterSource != null) {
              if (_filterSource == 'downloaded' &&
                  item.source != LibraryItemSource.downloaded) {
                return false;
              }
              if (_filterSource == 'local' &&
                  item.source != LibraryItemSource.local) {
                return false;
              }
            }

            if (_filterQuality != null && item.quality != null) {
              final quality = item.quality!.toLowerCase();
              switch (_filterQuality) {
                case 'hires':
                  if (!quality.startsWith('24')) return false;
                case 'cd':
                  if (!quality.startsWith('16')) return false;
                case 'lossy':
                  if (quality.startsWith('24') || quality.startsWith('16')) {
                    return false;
                  }
              }
            } else if (_filterQuality != null && item.quality == null) {
              if (_filterQuality != 'lossy') return false;
            }

            if (_filterFormat != null) {
              final ext = _itemFormatLower(item);
              if (ext != _filterFormat) return false;
            }

            if (!_queueUnifiedItemMatchesMetadataFilter(
              item,
              _filterMetadata,
            )) {
              return false;
            }

            return true;
          })
          .toList(growable: false);
    }

    return _applySorting(filtered);
  }

  List<UnifiedLibraryItem> _applySorting(List<UnifiedLibraryItem> items) {
    if (_sortMode == 'latest') {
      return items;
    }
    final sorted = List<UnifiedLibraryItem>.of(items);
    switch (_sortMode) {
      case 'oldest':
        sorted.sort((a, b) => a.addedAt.compareTo(b.addedAt));
      case 'a-z':
        sorted.sort(
          (a, b) =>
              a.trackName.toLowerCase().compareTo(b.trackName.toLowerCase()),
        );
      case 'z-a':
        sorted.sort(
          (a, b) =>
              b.trackName.toLowerCase().compareTo(a.trackName.toLowerCase()),
        );
      case 'artist-asc':
        sorted.sort((a, b) {
          final comparison = _queueCompareOptionalText(
            a.artistName,
            b.artistName,
          );
          if (comparison != 0) {
            return comparison;
          }
          return _queueCompareOptionalText(a.trackName, b.trackName);
        });
      case 'artist-desc':
        sorted.sort((a, b) {
          final comparison = _queueCompareOptionalText(
            a.artistName,
            b.artistName,
            descending: true,
          );
          if (comparison != 0) {
            return comparison;
          }
          return _queueCompareOptionalText(a.trackName, b.trackName);
        });
      case 'album-asc':
        sorted.sort((a, b) {
          final comparison = _queueCompareOptionalText(
            a.albumName,
            b.albumName,
          );
          if (comparison != 0) {
            return comparison;
          }
          return _queueCompareOptionalText(a.trackName, b.trackName);
        });
      case 'album-desc':
        sorted.sort((a, b) {
          final comparison = _queueCompareOptionalText(
            a.albumName,
            b.albumName,
            descending: true,
          );
          if (comparison != 0) {
            return comparison;
          }
          return _queueCompareOptionalText(a.trackName, b.trackName);
        });
      case 'release-oldest':
        sorted.sort((a, b) {
          final comparison = _queueCompareOptionalDate(
            _queueParseReleaseDate(a.releaseDate),
            _queueParseReleaseDate(b.releaseDate),
          );
          if (comparison != 0) {
            return comparison;
          }
          return _queueCompareOptionalText(a.trackName, b.trackName);
        });
      case 'release-newest':
        sorted.sort((a, b) {
          final comparison = _queueCompareOptionalDate(
            _queueParseReleaseDate(a.releaseDate),
            _queueParseReleaseDate(b.releaseDate),
            descending: true,
          );
          if (comparison != 0) {
            return comparison;
          }
          return _queueCompareOptionalText(a.trackName, b.trackName);
        });
      case 'genre-asc':
        sorted.sort((a, b) {
          final comparison = _queueCompareOptionalText(a.genre, b.genre);
          if (comparison != 0) {
            return comparison;
          }
          return _queueCompareOptionalText(a.trackName, b.trackName);
        });
      case 'genre-desc':
        sorted.sort((a, b) {
          final comparison = _queueCompareOptionalText(
            a.genre,
            b.genre,
            descending: true,
          );
          if (comparison != 0) {
            return comparison;
          }
          return _queueCompareOptionalText(a.trackName, b.trackName);
        });
    }
    return sorted;
  }

  Set<String> _getAvailableFormats(List<UnifiedLibraryItem> items) {
    final formats = <String>{};
    for (final item in items) {
      final ext = _itemFormatLower(item);
      if ([
        'flac',
        'alac',
        'mp3',
        'm4a',
        'aac',
        'eac3',
        'ac3',
        'ac4',
        'opus',
        'ogg',
        'wav',
        'aiff',
      ].contains(ext)) {
        formats.add(ext);
      }
    }
    return formats;
  }

  void _showFilterSheet(
    BuildContext context,
    List<UnifiedLibraryItem> allItems,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final availableFormats = _getAvailableFormats(allItems);

    String? tempSource = _filterSource;
    String? tempQuality = _filterQuality;
    String? tempFormat = _filterFormat;
    String? tempMetadata = _filterMetadata;
    String tempSortMode = _sortMode;

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxSheetHeight = constraints.maxHeight * 0.9;
                return ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxSheetHeight),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 32,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: colorScheme.outlineVariant,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),

                          Row(
                            children: [
                              Text(
                                context.l10n.libraryFilterTitle,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () {
                                  setSheetState(() {
                                    tempSource = null;
                                    tempQuality = null;
                                    tempFormat = null;
                                    tempMetadata = null;
                                    tempSortMode = 'latest';
                                  });
                                },
                                child: Text(context.l10n.libraryFilterReset),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          Text(
                            context.l10n.libraryFilterSource,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              FilterChip(
                                label: Text(context.l10n.libraryFilterAll),
                                selected: tempSource == null,
                                onSelected: (_) =>
                                    setSheetState(() => tempSource = null),
                              ),
                              FilterChip(
                                label: Text(
                                  context.l10n.libraryFilterDownloaded,
                                ),
                                selected: tempSource == 'downloaded',
                                onSelected: (_) => setSheetState(
                                  () => tempSource = 'downloaded',
                                ),
                              ),
                              FilterChip(
                                label: Text(context.l10n.libraryFilterLocal),
                                selected: tempSource == 'local',
                                onSelected: (_) =>
                                    setSheetState(() => tempSource = 'local'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          Text(
                            context.l10n.libraryFilterQuality,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              FilterChip(
                                label: Text(context.l10n.libraryFilterAll),
                                selected: tempQuality == null,
                                onSelected: (_) =>
                                    setSheetState(() => tempQuality = null),
                              ),
                              FilterChip(
                                label: Text(
                                  context.l10n.libraryFilterQualityHiRes,
                                ),
                                selected: tempQuality == 'hires',
                                onSelected: (_) =>
                                    setSheetState(() => tempQuality = 'hires'),
                              ),
                              FilterChip(
                                label: Text(
                                  context.l10n.libraryFilterQualityCD,
                                ),
                                selected: tempQuality == 'cd',
                                onSelected: (_) =>
                                    setSheetState(() => tempQuality = 'cd'),
                              ),
                              FilterChip(
                                label: Text(
                                  context.l10n.libraryFilterQualityLossy,
                                ),
                                selected: tempQuality == 'lossy',
                                onSelected: (_) =>
                                    setSheetState(() => tempQuality = 'lossy'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          Text(
                            context.l10n.libraryFilterFormat,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              FilterChip(
                                label: Text(context.l10n.libraryFilterAll),
                                selected: tempFormat == null,
                                onSelected: (_) =>
                                    setSheetState(() => tempFormat = null),
                              ),
                              for (final format
                                  in availableFormats.toList()..sort())
                                FilterChip(
                                  label: Text(format.toUpperCase()),
                                  selected: tempFormat == format,
                                  onSelected: (_) =>
                                      setSheetState(() => tempFormat = format),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          Text(
                            context.l10n.libraryFilterMetadata,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilterChip(
                                label: Text(context.l10n.libraryFilterAll),
                                selected: tempMetadata == null,
                                onSelected: (_) =>
                                    setSheetState(() => tempMetadata = null),
                              ),
                              FilterChip(
                                label: Text(
                                  context.l10n.libraryFilterMetadataComplete,
                                ),
                                selected: tempMetadata == 'complete',
                                onSelected: (_) => setSheetState(
                                  () => tempMetadata = 'complete',
                                ),
                              ),
                              FilterChip(
                                label: Text(
                                  context.l10n.libraryFilterMetadataMissingAny,
                                ),
                                selected: tempMetadata == 'missing-any',
                                onSelected: (_) => setSheetState(
                                  () => tempMetadata = 'missing-any',
                                ),
                              ),
                              FilterChip(
                                label: Text(
                                  context.l10n.libraryFilterMetadataMissingYear,
                                ),
                                selected: tempMetadata == 'missing-year',
                                onSelected: (_) => setSheetState(
                                  () => tempMetadata = 'missing-year',
                                ),
                              ),
                              FilterChip(
                                label: Text(
                                  context
                                      .l10n
                                      .libraryFilterMetadataMissingGenre,
                                ),
                                selected: tempMetadata == 'missing-genre',
                                onSelected: (_) => setSheetState(
                                  () => tempMetadata = 'missing-genre',
                                ),
                              ),
                              FilterChip(
                                label: Text(
                                  context
                                      .l10n
                                      .libraryFilterMetadataMissingAlbumArtist,
                                ),
                                selected:
                                    tempMetadata == 'missing-album-artist',
                                onSelected: (_) => setSheetState(
                                  () => tempMetadata = 'missing-album-artist',
                                ),
                              ),
                              FilterChip(
                                label: Text(
                                  context
                                      .l10n
                                      .libraryFilterMetadataMissingTrackNumber,
                                ),
                                selected:
                                    tempMetadata == 'missing-track-number',
                                onSelected: (_) => setSheetState(
                                  () => tempMetadata = 'missing-track-number',
                                ),
                              ),
                              FilterChip(
                                label: Text(
                                  context
                                      .l10n
                                      .libraryFilterMetadataMissingDiscNumber,
                                ),
                                selected: tempMetadata == 'missing-disc-number',
                                onSelected: (_) => setSheetState(
                                  () => tempMetadata = 'missing-disc-number',
                                ),
                              ),
                              FilterChip(
                                label: Text(
                                  context
                                      .l10n
                                      .libraryFilterMetadataMissingArtist,
                                ),
                                selected: tempMetadata == 'missing-artist',
                                onSelected: (_) => setSheetState(
                                  () => tempMetadata = 'missing-artist',
                                ),
                              ),
                              FilterChip(
                                label: Text(
                                  context
                                      .l10n
                                      .libraryFilterMetadataIncorrectIsrcFormat,
                                ),
                                selected:
                                    tempMetadata == 'incorrect-isrc-format',
                                onSelected: (_) => setSheetState(
                                  () => tempMetadata = 'incorrect-isrc-format',
                                ),
                              ),
                              FilterChip(
                                label: Text(
                                  context
                                      .l10n
                                      .libraryFilterMetadataMissingLabel,
                                ),
                                selected: tempMetadata == 'missing-label',
                                onSelected: (_) => setSheetState(
                                  () => tempMetadata = 'missing-label',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          Text(
                            context.l10n.libraryFilterSort,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              FilterChip(
                                label: Text(
                                  context.l10n.libraryFilterSortLatest,
                                ),
                                selected: tempSortMode == 'latest',
                                onSelected: (_) => setSheetState(
                                  () => tempSortMode = 'latest',
                                ),
                              ),
                              FilterChip(
                                label: Text(
                                  context.l10n.libraryFilterSortOldest,
                                ),
                                selected: tempSortMode == 'oldest',
                                onSelected: (_) => setSheetState(
                                  () => tempSortMode = 'oldest',
                                ),
                              ),
                              FilterChip(
                                label: Text(context.l10n.searchSortTitleAZ),
                                selected: tempSortMode == 'a-z',
                                onSelected: (_) =>
                                    setSheetState(() => tempSortMode = 'a-z'),
                              ),
                              FilterChip(
                                label: Text(context.l10n.searchSortTitleZA),
                                selected: tempSortMode == 'z-a',
                                onSelected: (_) =>
                                    setSheetState(() => tempSortMode = 'z-a'),
                              ),
                              FilterChip(
                                label: Text(context.l10n.searchSortArtistAZ),
                                selected: tempSortMode == 'artist-asc',
                                onSelected: (_) => setSheetState(
                                  () => tempSortMode = 'artist-asc',
                                ),
                              ),
                              FilterChip(
                                label: Text(context.l10n.searchSortArtistZA),
                                selected: tempSortMode == 'artist-desc',
                                onSelected: (_) => setSheetState(
                                  () => tempSortMode = 'artist-desc',
                                ),
                              ),
                              FilterChip(
                                label: Text(
                                  context.l10n.libraryFilterSortAlbumAsc,
                                ),
                                selected: tempSortMode == 'album-asc',
                                onSelected: (_) => setSheetState(
                                  () => tempSortMode = 'album-asc',
                                ),
                              ),
                              FilterChip(
                                label: Text(
                                  context.l10n.libraryFilterSortAlbumDesc,
                                ),
                                selected: tempSortMode == 'album-desc',
                                onSelected: (_) => setSheetState(
                                  () => tempSortMode = 'album-desc',
                                ),
                              ),
                              FilterChip(
                                label: Text(context.l10n.searchSortDateNewest),
                                selected: tempSortMode == 'release-newest',
                                onSelected: (_) => setSheetState(
                                  () => tempSortMode = 'release-newest',
                                ),
                              ),
                              FilterChip(
                                label: Text(context.l10n.searchSortDateOldest),
                                selected: tempSortMode == 'release-oldest',
                                onSelected: (_) => setSheetState(
                                  () => tempSortMode = 'release-oldest',
                                ),
                              ),
                              FilterChip(
                                label: Text(
                                  context.l10n.libraryFilterSortGenreAsc,
                                ),
                                selected: tempSortMode == 'genre-asc',
                                onSelected: (_) => setSheetState(
                                  () => tempSortMode = 'genre-asc',
                                ),
                              ),
                              FilterChip(
                                label: Text(
                                  context.l10n.libraryFilterSortGenreDesc,
                                ),
                                selected: tempSortMode == 'genre-desc',
                                onSelected: (_) => setSheetState(
                                  () => tempSortMode = 'genre-desc',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () {
                                setState(() {
                                  _filterSource = tempSource;
                                  _filterQuality = tempQuality;
                                  _filterFormat = tempFormat;
                                  _filterMetadata = tempMetadata;
                                  _sortMode = tempSortMode;
                                  _resetLibraryPaging();
                                  _unifiedItemsCache.clear();
                                  _invalidateFilterContentCache();
                                });
                                Navigator.pop(context);
                              },
                              child: Text(context.l10n.libraryFilterApply),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _initializePageController();

    ref.listen(downloadQueueLookupProvider, (previous, next) {
      if (previous == null) return;
      for (final id in previous.itemIds) {
        final prevItem = previous.byItemId[id];
        final nextItem = next.byItemId[id];
        if (prevItem == null) continue;
        final wasActive =
            prevItem.status == DownloadStatus.downloading ||
            prevItem.status == DownloadStatus.finalizing ||
            prevItem.status == DownloadStatus.queued;
        final nowCompleted =
            nextItem != null && nextItem.status == DownloadStatus.completed;
        if (wasActive && nowCompleted) {
          _completionBridge[id] = nextItem.track;
          _completionBridgeAt[id] = DateTime.now();
        }
      }
    });
    ref.listen<int>(
      downloadHistoryProvider.select((state) => state.loadedIndexVersion),
      (previous, next) {
        if (previous == null || previous == next) return;
        _invalidateLibraryDataCaches();
        _resetLibraryPaging();
        if (mounted) setState(() {});
      },
    );
    ref.listen<int>(
      localLibraryProvider.select((state) => state.loadedIndexVersion),
      (previous, next) {
        if (previous == null || previous == next) return;
        _invalidateLibraryDataCaches();
        _resetLibraryPaging();
        if (mounted) setState(() {});
      },
    );

    final hasQueueItems = ref.watch(
      downloadQueueLookupProvider.select((lookup) => lookup.itemIds.isNotEmpty),
    );
    final historyTotalCount = ref.watch(
      downloadHistoryProvider.select((state) => state.totalCount),
    );
    final localLibraryTotalCount = ref.watch(
      localLibraryProvider.select((state) => state.totalCount),
    );
    final localLibraryEnabled = ref.watch(
      settingsProvider.select((s) => s.localLibraryEnabled),
    );
    // Watch with selector on key fields to reduce unnecessary rebuilds.
    // LibraryCollectionsState doesn't implement == so watching without
    // selector rebuilds on every provider notification.
    ref.watch(
      libraryCollectionsProvider.select(
        (s) => (
          s.wishlistCount,
          s.lovedCount,
          s.favoriteArtistCount,
          s.playlistCount,
          s.hasPlaylistTracks,
          s.isLoaded,
        ),
      ),
    );
    final collectionState = ref.read(libraryCollectionsProvider);
    final historyViewMode = ref.watch(
      settingsProvider.select((s) => s.historyViewMode),
    );
    final historyFilterMode = ref.watch(
      settingsProvider.select((s) => s.historyFilterMode),
    );
    final colorScheme = Theme.of(context).colorScheme;
    final topPadding = normalizedHeaderTopPadding(context);
    final countsRequest = _QueueLibraryCountsRequest(
      searchQuery: _searchQuery,
      filterSource: _filterSource,
      filterQuality: _filterQuality,
      filterFormat: _filterFormat,
      filterMetadata: _filterMetadata,
      localLibraryEnabled: localLibraryEnabled,
    );
    final countsValue = ref.watch(_queueLibraryCountsProvider(countsRequest));
    final queueCounts = _resolveQueueLibraryCounts(countsValue, countsRequest);

    _QueueLibraryPageRequest pageRequest(String filterMode) =>
        _QueueLibraryPageRequest(
          filterMode: filterMode,
          limit: _libraryPageSize,
          offset: _libraryPageOffsetFor(filterMode),
          searchQuery: _searchQuery,
          filterSource: _filterSource,
          filterQuality: _filterQuality,
          filterFormat: _filterFormat,
          filterMetadata: _filterMetadata,
          sortMode: _sortMode,
          localLibraryEnabled: localLibraryEnabled,
        );

    final activePageRequest = pageRequest(historyFilterMode);
    final activePageValue = ref.watch(
      _queueLibraryPageProvider(activePageRequest),
    );

    _QueueLibraryPageData pageData(String filterMode) {
      final request = filterMode == historyFilterMode
          ? activePageRequest
          : pageRequest(filterMode);
      return _resolveQueueLibraryPageData(
        filterMode == historyFilterMode ? activePageValue : null,
        request,
      );
    }

    _FilterContentData getFilterData(String filterMode) {
      return pageData(filterMode).toFilterContentData(
        collectionState,
        totalTrackCount: switch (filterMode) {
          'singles' => queueCounts.singleTrackCount,
          'albums' => 0,
          _ => queueCounts.allTrackCount,
        },
        totalAlbumCount: filterMode == 'albums' ? queueCounts.albumCount : null,
      );
    }

    final currentPageData = pageData(historyFilterMode);
    final currentLoadedCount = historyFilterMode == 'albums'
        ? currentPageData.groupedAlbums.length +
              currentPageData.groupedLocalAlbums.length
        : currentPageData.items.length;
    final currentTotalCount = switch (historyFilterMode) {
      'albums' => queueCounts.albumCount,
      'singles' => queueCounts.singleTrackCount,
      _ => queueCounts.allTrackCount,
    };
    final hasMoreLibrary = currentLoadedCount < currentTotalCount;
    final isLibraryPageLoading =
        countsValue.isLoading || activePageValue.isLoading;
    final hasAnyLibraryItems =
        queueCounts.allTrackCount > 0 || queueCounts.albumCount > 0;
    final hasLibraryContent =
        historyTotalCount > 0 ||
        (localLibraryEnabled && localLibraryTotalCount > 0);
    final hasActiveSearch =
        _searchQuery.isNotEmpty || _searchController.text.trim().isNotEmpty;
    final shouldShowLibraryControls =
        hasLibraryContent || hasAnyLibraryItems || hasActiveSearch;
    _scheduleBlankLibraryRepair(
      hasQueueItems: hasQueueItems,
      hasLibraryContent: hasLibraryContent,
      hasAnyLibraryItems: hasAnyLibraryItems,
      isLibraryPageLoading: isLibraryPageLoading,
    );

    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final bottomInset = context.navBarBottomInset;
    final selectionItems = getFilterData(
      historyFilterMode,
    ).filteredUnifiedItems;
    if (_isSelectionMode || _isPlaylistSelectionMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isSelectionMode) {
          _syncSelectionOverlay(
            items: selectionItems,
            bottomPadding: bottomPadding,
          );
        }
        if (_isPlaylistSelectionMode) {
          _syncPlaylistSelectionOverlay(
            playlists: collectionState.playlists,
            bottomPadding: bottomPadding,
          );
        }
      });
    }

    return PopScope(
      canPop: !_isSelectionMode && !_isPlaylistSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (_isPlaylistSelectionMode) {
            _exitPlaylistSelectionMode();
          } else if (_isSelectionMode) {
            _exitSelectionMode();
          }
        }
      },
      child: Stack(
        children: [
          // ScrollConfiguration disables stretch overscroll to fix _StretchController exception
          // This is a known Flutter issue with NestedScrollView + Material 3 stretch indicator
          ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(overscroll: false),
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar(
                  expandedHeight: 120 + topPadding,
                  collapsedHeight: kToolbarHeight,
                  floating: false,
                  pinned: true,
                  backgroundColor: colorScheme.surface,
                  surfaceTintColor: Colors.transparent,
                  automaticallyImplyLeading: false,
                  flexibleSpace: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxHeight = 120 + topPadding;
                      final minHeight = kToolbarHeight + topPadding;
                      final expandRatio =
                          ((constraints.maxHeight - minHeight) /
                                  (maxHeight - minHeight))
                              .clamp(0.0, 1.0);

                      return FlexibleSpaceBar(
                        expandedTitleScale: 1.0,
                        titlePadding: const EdgeInsets.only(
                          left: 24,
                          bottom: 16,
                        ),
                        title: Text(
                          context.l10n.navLibrary,
                          style: TextStyle(
                            fontSize: 20 + (14 * expandRatio),
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                if (shouldShowLibraryControls || hasQueueItems)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: GestureDetector(
                        onTap: () {},
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          autofocus: false,
                          canRequestFocus: true,
                          decoration: InputDecoration(
                            hintText: context.l10n.historySearchHint,
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    tooltip: context.l10n.dialogClear,
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      _clearSearch();
                                      FocusScope.of(context).unfocus();
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: settingsGroupColor(context),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28),
                              borderSide: BorderSide(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28),
                              borderSide: BorderSide(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28),
                              borderSide: BorderSide(
                                color: colorScheme.primary,
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                          ),
                          onChanged: _onSearchChanged,
                          onTapOutside: (_) {
                            FocusScope.of(context).unfocus();
                          },
                        ),
                      ),
                    ),
                  ),

                if (shouldShowLibraryControls)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Builder(
                        builder: (context) {
                          int filteredAllCount;
                          int filteredAlbumCount;
                          int filteredSingleCount;

                          filteredAllCount = queueCounts.allTrackCount;
                          filteredAlbumCount = queueCounts.albumCount;
                          filteredSingleCount = queueCounts.singleTrackCount;

                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _FilterChip(
                                  label: context.l10n.historyFilterAll,
                                  count: filteredAllCount,
                                  isSelected: historyFilterMode == 'all',
                                  onTap: () {
                                    _animateToFilterPage(0);
                                  },
                                ),
                                const SizedBox(width: 8),
                                _FilterChip(
                                  label: context.l10n.historyFilterAlbums,
                                  count: filteredAlbumCount,
                                  isSelected: historyFilterMode == 'albums',
                                  onTap: () {
                                    _animateToFilterPage(1);
                                  },
                                ),
                                const SizedBox(width: 8),
                                _FilterChip(
                                  label: context.l10n.historyFilterSingles,
                                  count: filteredSingleCount,
                                  isSelected: historyFilterMode == 'singles',
                                  onTap: () {
                                    _animateToFilterPage(2);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
              body: PageView.builder(
                controller: _filterPageController!,
                physics: const ClampingScrollPhysics(),
                onPageChanged: _onFilterPageChanged,
                itemCount: _filterModes.length,
                itemBuilder: (context, index) {
                  final filterMode = _filterModes[index];
                  final filterData = getFilterData(filterMode);
                  return _buildFilterContent(
                    context: context,
                    colorScheme: colorScheme,
                    filterMode: filterMode,
                    historyViewMode: historyViewMode,
                    hasQueueItems: hasQueueItems,
                    filterData: filterData,
                    collectionState: collectionState,
                    hasMoreLibrary: filterMode == historyFilterMode
                        ? hasMoreLibrary
                        : false,
                    isPageLoading: isLibraryPageLoading,
                    bottomInset: bottomInset,
                  );
                },
              ),
            ),
          ), // ScrollConfiguration
        ],
      ),
    );
  }

  List<UnifiedLibraryItem> _getUnifiedItems({
    required String filterMode,
    required List<DownloadHistoryItem> historyItems,
    required List<LocalLibraryItem> localLibraryItems,
    required Map<String, int> localAlbumCounts,
  }) {
    if (filterMode == 'albums') return const [];

    final query = _searchQuery;
    final cached = _unifiedItemsCache[filterMode];
    if (cached != null &&
        identical(cached.historyItems, historyItems) &&
        identical(cached.localItems, localLibraryItems) &&
        identical(cached.localAlbumCounts, localAlbumCounts) &&
        cached.query == query) {
      return cached.items;
    }

    final unifiedDownloaded = _unifiedDownloadedItems(historyItems);

    List<LocalLibraryItem> localItemsForMerge;
    if (filterMode == 'all') {
      localItemsForMerge = _filterLocalItems(localLibraryItems, query);
    } else {
      final localSingles = _localSingleItems(
        localLibraryItems,
        localAlbumCounts,
      );
      localItemsForMerge = _filterLocalItems(localSingles, query);
    }

    final unifiedLocal = _unifiedLocalItems(localItemsForMerge);
    final downloadedPathKeys = _downloadedPathKeys(historyItems);

    final dedupedUnifiedLocal = <UnifiedLibraryItem>[];
    for (final item in unifiedLocal) {
      final localSource = item.localItem;
      final localPathKeys = localSource != null
          ? _localPathMatchKeys(localSource)
          : buildPathMatchKeys(item.filePath);
      final overlapsDownloaded = localPathKeys.any(downloadedPathKeys.contains);
      if (!overlapsDownloaded) {
        dedupedUnifiedLocal.add(item);
      }
    }

    final merged = <UnifiedLibraryItem>[
      ...unifiedDownloaded,
      ...dedupedUnifiedLocal,
    ]..sort((a, b) => b.addedAt.compareTo(a.addedAt));

    _unifiedItemsCache[filterMode] = _UnifiedCacheEntry(
      historyItems: historyItems,
      localItems: localLibraryItems,
      localAlbumCounts: localAlbumCounts,
      query: query,
      items: merged,
    );

    return merged;
  }

  // ignore: unused_element
  _FilterContentData _computeFilterContentData({
    required String filterMode,
    required List<DownloadHistoryItem> allHistoryItems,
    required List<_GroupedAlbum> filteredGroupedAlbums,
    required List<_GroupedLocalAlbum> filteredGroupedLocalAlbums,
    required Map<String, int> albumCounts,
    required Map<String, int> localAlbumCounts,
    required List<LocalLibraryItem> localLibraryItems,
    required LibraryCollectionsState collectionState,
  }) {
    final historyItems = _resolveHistoryItems(
      filterMode: filterMode,
      allHistoryItems: allHistoryItems,
      albumCounts: albumCounts,
    );
    final showFilteringIndicator = _shouldShowFilteringIndicator(
      allHistoryItems: allHistoryItems,
      filterMode: filterMode,
    );

    final unifiedItems = _getUnifiedItems(
      filterMode: filterMode,
      historyItems: historyItems,
      localLibraryItems: localLibraryItems,
      localAlbumCounts: localAlbumCounts,
    );
    final filtered = _applyAdvancedFilters(unifiedItems);

    // Remove tracks that are already in any playlist so they don't appear
    // in the main tracks list.  When a track is removed from a playlist (or
    // the playlist is deleted) it will automatically reappear here because it
    // will no longer be in the set.
    final filteredUnifiedItems = !collectionState.hasPlaylistTracks
        ? filtered
        : filtered
              .where(
                (item) =>
                    !collectionState.isTrackInAnyPlaylist(item.collectionKey),
              )
              .toList(growable: false);

    return _FilterContentData(
      historyItems: historyItems,
      unifiedItems: unifiedItems,
      filteredUnifiedItems: filteredUnifiedItems,
      filteredGroupedAlbums: filteredGroupedAlbums,
      filteredGroupedLocalAlbums: filteredGroupedLocalAlbums,
      showFilteringIndicator: showFilteringIndicator,
    );
  }

  Widget _buildQueueHeaderSliver(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return Consumer(
      builder: (context, ref, child) {
        final queueCount = ref.watch(
          downloadQueueLookupProvider.select((lookup) {
            var count = 0;
            for (final id in lookup.itemIds) {
              final entry = lookup.byItemId[id];
              if (entry != null && entry.status != DownloadStatus.completed) {
                count++;
              }
            }
            return count;
          }),
        );
        final failedCount = ref.watch(
          downloadQueueProvider.select((state) => state.failedCount),
        );
        final isProcessing = ref.watch(
          downloadQueueProvider.select((state) => state.isProcessing),
        );
        final isPaused = ref.watch(
          downloadQueueProvider.select((state) => state.isPaused),
        );
        return SliverToBoxAdapter(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => SizeTransition(
              sizeFactor: animation,
              alignment: Alignment.topCenter,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: queueCount == 0
                ? const SizedBox(
                    width: double.infinity,
                    key: ValueKey('dl_header_empty'),
                  )
                : Padding(
                    key: const ValueKey('dl_header'),
                    padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.downloading_rounded,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.l10n.queueDownloadingCount(queueCount),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        if (failedCount > 0 && !isProcessing)
                          IconButton(
                            onPressed: () => ref
                                .read(downloadQueueProvider.notifier)
                                .retryAllFailed(),
                            icon: const Icon(Icons.replay_rounded, size: 20),
                            tooltip: context.l10n.queueRetryAllFailed(
                              failedCount,
                            ),
                            color: colorScheme.primary,
                            visualDensity: VisualDensity.compact,
                          ),
                        IconButton(
                          onPressed: () => ref
                              .read(downloadQueueProvider.notifier)
                              .togglePause(),
                          icon: Icon(
                            isPaused
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded,
                            size: 20,
                          ),
                          tooltip: isPaused
                              ? context.l10n.actionResume
                              : context.l10n.actionPause,
                          color: colorScheme.onSurfaceVariant,
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          onPressed: () =>
                              _showClearAllDialog(context, ref, colorScheme),
                          icon: const Icon(Icons.clear_all_rounded, size: 20),
                          tooltip: context.l10n.queueClearAll,
                          color: colorScheme.error,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  Future<void> _confirmCancelDownload(
    BuildContext context,
    DownloadItem item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.cancelDownloadTitle),
        content: Text(context.l10n.cancelDownloadContent(item.track.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.cancelDownloadKeep),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.dialogCancel),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(downloadQueueProvider.notifier).dismissItem(item.id);
    }
  }

  Future<void> _showDownloadErrorDialog(
    BuildContext context,
    DownloadItem item,
  ) async {
    final colorScheme = Theme.of(context).colorScheme;
    final isRateLimit = item.errorType == DownloadErrorType.rateLimit;
    final isFolderAccessLost =
        item.errorMessage == safPermissionLostErrorMessage ||
        item.errorMessage == downloadFolderAccessLostErrorMessage;
    final title = isRateLimit
        ? context.l10n.queueRateLimitTitle
        : context.l10n.updateDownloadFailed;
    final message = isRateLimit
        ? context.l10n.queueRateLimitMessage
        : (item.errorMessage.trim().isNotEmpty
              ? _localizedDownloadError(context, item.errorMessage)
              : context.l10n.updateDownloadFailed);
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.track.name,
                style: Theme.of(
                  ctx,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              SelectableText(
                message,
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('remove'),
            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            child: Text(context.l10n.dialogRemove),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.dialogCancel),
          ),
          if (isFolderAccessLost)
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop('reselect'),
              child: Text(context.l10n.downloadFolderReselect),
            )
          else
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop('retry'),
              child: Text(context.l10n.dialogRetry),
            ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'retry') {
      ref.read(downloadQueueProvider.notifier).retryItem(item.id);
    } else if (action == 'remove') {
      ref.read(downloadQueueProvider.notifier).removeItem(item.id);
    } else if (action == 'reselect') {
      final reselected = await _reselectDownloadFolder();
      if (reselected && mounted) {
        ref.read(downloadQueueProvider.notifier).retryItem(item.id);
      }
    }
  }

  /// Reopen the platform folder picker to restore download folder access,
  /// then persist the new location. Returns true when a folder was saved.
  Future<bool> _reselectDownloadFolder() async {
    if (Platform.isAndroid) {
      final result = await PlatformBridge.pickSafTree();
      if (result == null) return false;
      final treeUri = result['tree_uri'] as String? ?? '';
      final displayName = result['display_name'] as String? ?? '';
      if (treeUri.isEmpty) return false;
      final notifier = ref.read(settingsProvider.notifier);
      notifier.setStorageMode('saf');
      notifier.setDownloadTreeUri(
        treeUri,
        displayName: displayName.isNotEmpty ? displayName : treeUri,
      );
      return true;
    }
    if (Platform.isIOS) {
      IosPickedDirectory? picked;
      try {
        picked = await PlatformBridge.pickIosDirectory();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.snackbarFolderPickerFailed(e.toString()),
              ),
            ),
          );
        }
        return false;
      }
      if (picked == null) return false;
      final validation = validateIosPath(picked.path);
      if (!validation.isValid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                validation.errorReason ?? context.l10n.setupIcloudNotSupported,
              ),
            ),
          );
        }
        return false;
      }
      ref
          .read(settingsProvider.notifier)
          .setDownloadDirectory(picked.path, iosBookmark: picked.bookmark);
      return true;
    }
    return false;
  }
}

class _AnimatedLibrarySliverGrid extends StatefulWidget {
  final double maxCrossAxisExtent;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;
  final SliverChildDelegate delegate;

  const _AnimatedLibrarySliverGrid({
    required this.maxCrossAxisExtent,
    required this.mainAxisSpacing,
    required this.crossAxisSpacing,
    required this.childAspectRatio,
    required this.delegate,
  });

  @override
  State<_AnimatedLibrarySliverGrid> createState() =>
      _AnimatedLibrarySliverGridState();
}

class _AnimatedLibrarySliverGridState extends State<_AnimatedLibrarySliverGrid>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curve;
  late double _beginExtent;
  late double _endExtent;

  @override
  void initState() {
    super.initState();
    _beginExtent = widget.maxCrossAxisExtent;
    _endExtent = widget.maxCrossAxisExtent;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
    )..value = 1;
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  }

  @override
  void didUpdateWidget(covariant _AnimatedLibrarySliverGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.maxCrossAxisExtent - _endExtent).abs() < 0.1) return;
    _beginExtent = _currentExtent;
    _endExtent = widget.maxCrossAxisExtent;
    _controller.forward(from: 0);
  }

  double get _currentExtent =>
      _beginExtent + ((_endExtent - _beginExtent) * _curve.value);

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SliverGrid(
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: _currentExtent,
            mainAxisSpacing: widget.mainAxisSpacing,
            crossAxisSpacing: widget.crossAxisSpacing,
            childAspectRatio: widget.childAspectRatio,
          ),
          delegate: widget.delegate,
        );
      },
    );
  }
}
