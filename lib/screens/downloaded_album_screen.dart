import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:spotiflac_android/services/cover_cache_manager.dart';
import 'package:spotiflac_android/services/platform_bridge.dart';
import 'package:spotiflac_android/services/batch_track_actions.dart';
import 'package:spotiflac_android/models/unified_library_item.dart';
import 'package:spotiflac_android/l10n/l10n.dart';
import 'package:spotiflac_android/utils/cover_art_utils.dart';
import 'package:spotiflac_android/utils/file_access.dart';
import 'package:spotiflac_android/utils/image_cache_utils.dart';
import 'package:spotiflac_android/utils/nav_bar_inset.dart';
import 'package:spotiflac_android/providers/download_queue_provider.dart';
import 'package:spotiflac_android/providers/playback_provider.dart';
import 'package:spotiflac_android/providers/music_player_provider.dart';
import 'package:spotiflac_android/screens/track_metadata_screen.dart';
import 'package:spotiflac_android/services/downloaded_embedded_cover_resolver.dart';
import 'package:spotiflac_android/widgets/animation_utils.dart';
import 'package:spotiflac_android/widgets/selection_action_button.dart';
import 'package:spotiflac_android/widgets/selection_bottom_bar.dart';
import 'package:spotiflac_android/widgets/disc_separator_chip.dart';
import 'package:spotiflac_android/widgets/album_detail_header.dart';

class DownloadedAlbumScreen extends ConsumerStatefulWidget {
  final String albumName;
  final String artistName;
  final String? coverUrl;

  const DownloadedAlbumScreen({
    super.key,
    required this.albumName,
    required this.artistName,
    this.coverUrl,
  });

  @override
  ConsumerState<DownloadedAlbumScreen> createState() =>
      _DownloadedAlbumScreenState();
}

class _DownloadedAlbumScreenState extends ConsumerState<DownloadedAlbumScreen> {
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  bool _showTitleInAppBar = false;
  final ScrollController _scrollController = ScrollController();
  bool _embeddedCoverRefreshScheduled = false;
  List<DownloadHistoryItem>? _albumTracksSourceCache;
  List<DownloadHistoryItem>? _albumTracksCache;
  List<DownloadHistoryItem>? _discGroupingSourceCache;
  Map<int, List<DownloadHistoryItem>>? _discGroupingCache;
  List<int>? _sortedDiscNumbersCache;
  List<DownloadHistoryItem>? _commonQualitySourceCache;
  String? _commonQualityCache;
  List<DownloadHistoryItem>? _embeddedCoverSourceCache;
  String? _embeddedCoverPathCache;
  bool _embeddedCoverPathResolved = false;

  String get _albumLookupKey =>
      '${widget.albumName.toLowerCase()}|${widget.artistName.toLowerCase()}';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DownloadedAlbumScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.albumName != widget.albumName ||
        oldWidget.artistName != widget.artistName) {
      _albumTracksSourceCache = null;
      _albumTracksCache = null;
      _invalidateDerivedTrackCaches();
    }
  }

  void _onScroll() {
    final expandedHeight = _calculateExpandedHeight(context);
    final shouldShow =
        _scrollController.offset > (expandedHeight - kToolbarHeight - 20);
    if (shouldShow != _showTitleInAppBar) {
      setState(() => _showTitleInAppBar = shouldShow);
    }
  }

  double _calculateExpandedHeight(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    return (mediaSize.height * 0.6).clamp(400.0, 580.0);
  }

  List<DownloadHistoryItem> _getAlbumTracks(
    List<DownloadHistoryItem> allItems,
  ) {
    final cached = _albumTracksCache;
    if (cached != null && identical(allItems, _albumTracksSourceCache)) {
      return cached;
    }

    final tracks =
        allItems.where((item) {
          final itemArtist =
              (item.albumArtist != null && item.albumArtist!.isNotEmpty)
              ? item.albumArtist!
              : item.artistName;
          final itemKey =
              '${item.albumName.toLowerCase()}|${itemArtist.toLowerCase()}';
          return itemKey == _albumLookupKey;
        }).toList()..sort((a, b) {
          final aDisc = a.discNumber ?? 1;
          final bDisc = b.discNumber ?? 1;
          if (aDisc != bDisc) return aDisc.compareTo(bDisc);
          final aNum = a.trackNumber ?? 999;
          final bNum = b.trackNumber ?? 999;
          if (aNum != bNum) return aNum.compareTo(bNum);
          return a.trackName.compareTo(b.trackName);
        });

    _albumTracksSourceCache = allItems;
    _albumTracksCache = tracks;
    _invalidateDerivedTrackCaches();
    return tracks;
  }

  void _invalidateDerivedTrackCaches() {
    _discGroupingSourceCache = null;
    _discGroupingCache = null;
    _sortedDiscNumbersCache = null;
    _commonQualitySourceCache = null;
    _commonQualityCache = null;
    _embeddedCoverSourceCache = null;
    _embeddedCoverPathCache = null;
    _embeddedCoverPathResolved = false;
  }

  Map<int, List<DownloadHistoryItem>> _getDiscGroups(
    List<DownloadHistoryItem> tracks,
  ) {
    final cached = _discGroupingCache;
    if (cached != null && identical(tracks, _discGroupingSourceCache)) {
      return cached;
    }

    final discMap = <int, List<DownloadHistoryItem>>{};
    for (final track in tracks) {
      final discNumber = track.discNumber ?? 1;
      discMap.putIfAbsent(discNumber, () => []).add(track);
    }
    _discGroupingSourceCache = tracks;
    _discGroupingCache = discMap;
    _sortedDiscNumbersCache = discMap.keys.toList()..sort();
    return discMap;
  }

  List<int> _getSortedDiscNumbers(List<DownloadHistoryItem> tracks) {
    _getDiscGroups(tracks);
    return _sortedDiscNumbersCache ?? const [];
  }

  void _enterSelectionMode(String itemId) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isSelectionMode = true;
      _selectedIds.add(itemId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String itemId) {
    setState(() {
      if (_selectedIds.contains(itemId)) {
        _selectedIds.remove(itemId);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(itemId);
      }
    });
  }

  void _selectAll(List<DownloadHistoryItem> tracks) {
    setState(() {
      _selectedIds.addAll(tracks.map((e) => e.id));
    });
  }

  Future<void> _deleteSelected(List<DownloadHistoryItem> currentTracks) async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.downloadedAlbumDeleteSelected),
        content: Text(context.l10n.downloadedAlbumDeleteMessage(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.dialogCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(context.l10n.dialogDelete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final historyNotifier = ref.read(downloadHistoryProvider.notifier);
      final idsToDelete = _selectedIds.toList();
      final tracksById = {for (final track in currentTracks) track.id: track};

      int deletedCount = 0;
      for (final id in idsToDelete) {
        final item = tracksById[id];
        if (item != null) {
          try {
            await deleteFile(item.filePath);
          } catch (_) {}
          historyNotifier.removeFromHistory(id);
          deletedCount++;
        }
      }

      _exitSelectionMode();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.snackbarDeletedTracks(deletedCount)),
          ),
        );
      }
    }
  }

  Future<void> _openFile(
    DownloadHistoryItem track, {
    List<DownloadHistoryItem> queueItems = const [],
  }) async {
    try {
      await ref
          .read(playbackProvider.notifier)
          .playHistoryQueue(
            queueItems.isNotEmpty ? queueItems : [track],
            startItem: track,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.snackbarCannotOpenFile(e.toString())),
          ),
        );
      }
    }
  }

  void _onEmbeddedCoverChanged() {
    if (!mounted || _embeddedCoverRefreshScheduled) return;
    _embeddedCoverRefreshScheduled = true;
    _embeddedCoverPathResolved = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _embeddedCoverRefreshScheduled = false;
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _navigateToMetadataScreen(
    DownloadHistoryItem item, {
    required List<DownloadHistoryItem> navigationItems,
    required int navigationIndex,
  }) async {
    final navigator = Navigator.of(context);
    _precacheCover(item.coverUrl);
    final beforeModTime =
        await DownloadedEmbeddedCoverResolver.readFileModTimeMillis(
          item.filePath,
        );
    if (!mounted) return;

    final result = await navigator.push(
      slidePageRoute<bool>(
        page: TrackMetadataScreen(
          item: item,
          historyNavigationItems: navigationItems,
          navigationIndex: navigationIndex,
        ),
      ),
    );
    await DownloadedEmbeddedCoverResolver.scheduleRefreshForPath(
      item.filePath,
      beforeModTime: beforeModTime,
      force: result == true,
      onChanged: _onEmbeddedCoverChanged,
    );
  }

  void _precacheCover(String? url) {
    if (url == null || url.isEmpty) return;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return;
    }
    final dpr = MediaQuery.devicePixelRatioOf(
      context,
    ).clamp(1.0, 3.0).toDouble();
    final targetSize = (360 * dpr).round().clamp(512, 1024).toInt();
    precacheImage(
      ResizeImage(
        CachedNetworkImageProvider(
          url,
          cacheManager: CoverCacheManager.instance,
        ),
        width: targetSize,
        height: targetSize,
      ),
      context,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final bottomInset = context.navBarBottomInset;

    final tracksValue = ref.watch(
      downloadedAlbumTracksProvider(
        DownloadedAlbumTracksRequest(
          albumName: widget.albumName,
          artistName: widget.artistName,
        ),
      ),
    );
    final tracks = tracksValue.maybeWhen(
      data: (items) => _getAlbumTracks(items),
      orElse: () => const <DownloadHistoryItem>[],
    );

    if (tracks.isEmpty && tracksValue.isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.albumName)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (tracks.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.albumName)),
        body: Center(child: Text(context.l10n.noTracksFoundForAlbum)),
      );
    }

    final validIds = tracks.map((t) => t.id).toSet();
    _selectedIds.removeWhere((id) => !validIds.contains(id));
    if (_selectedIds.isEmpty && _isSelectionMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _isSelectionMode = false);
      });
    }

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isSelectionMode) {
          _exitSelectionMode();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            CustomScrollView(
              controller: _scrollController,
              slivers: [
                _buildAppBar(context, colorScheme, tracks),
                _buildTrackList(context, colorScheme, tracks),
                SliverToBoxAdapter(
                  child: SizedBox(height: _isSelectionMode ? 120 : 32),
                ),
                SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
              ],
            ),

            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              left: 0,
              right: 0,
              bottom: _isSelectionMode ? 0 : -(200 + bottomPadding),
              child: _buildSelectionBottomBar(
                context,
                colorScheme,
                tracks,
                bottomPadding,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _resolveAlbumEmbeddedCoverPath(List<DownloadHistoryItem> tracks) {
    if (_embeddedCoverPathResolved &&
        identical(tracks, _embeddedCoverSourceCache)) {
      return _embeddedCoverPathCache;
    }

    _embeddedCoverSourceCache = tracks;
    _embeddedCoverPathResolved = true;

    if (tracks.isEmpty) {
      _embeddedCoverPathCache = null;
      return null;
    }

    _embeddedCoverPathCache = DownloadedEmbeddedCoverResolver.resolve(
      tracks.first.filePath,
      onChanged: _onEmbeddedCoverChanged,
    );
    return _embeddedCoverPathCache;
  }

  Widget _buildAppBar(
    BuildContext context,
    ColorScheme colorScheme,
    List<DownloadHistoryItem> tracks,
  ) {
    final expandedHeight = _calculateExpandedHeight(context);
    final embeddedCoverPath = _resolveAlbumEmbeddedCoverPath(tracks);
    final commonQuality = _getCommonQuality(tracks);

    final cacheWidth = coverCacheWidthForViewport(context);
    final Widget background = embeddedCoverPath != null
        ? Image.file(
            File(embeddedCoverPath),
            fit: BoxFit.cover,
            cacheWidth: cacheWidth,
            gaplessPlayback: true,
            filterQuality: FilterQuality.low,
            errorBuilder: (_, _, _) => Container(color: colorScheme.surface),
          )
        : widget.coverUrl != null
        ? CachedNetworkImage(
            imageUrl: highResCoverUrl(widget.coverUrl) ?? widget.coverUrl!,
            fit: BoxFit.cover,
            memCacheWidth: cacheWidth,
            cacheManager: CoverCacheManager.instance,
            placeholder: (_, _) => Container(color: colorScheme.surface),
            errorWidget: (_, _, _) => Container(color: colorScheme.surface),
          )
        : Container(
            color: colorScheme.surfaceContainerHighest,
            child: Icon(
              Icons.album,
              size: 80,
              color: colorScheme.onSurfaceVariant,
            ),
          );

    return AlbumDetailHeader(
      title: widget.albumName,
      expandedHeight: expandedHeight,
      showTitleInAppBar: _showTitleInAppBar,
      background: background,
      blurAndScrimBackground:
          embeddedCoverPath != null || widget.coverUrl != null,
      coverBuilder: (context, coverSize) => _buildSquareCover(
        context,
        colorScheme,
        embeddedCoverPath,
        coverSize,
        cacheWidth,
      ),
      subtitle: Text(
        widget.artistName,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      meta: tracks.isNotEmpty
          ? _buildDownloadedHeaderMeta(context, tracks, commonQuality)
          : null,
      actions: tracks.isNotEmpty
          ? AlbumPlayActions(
              playLabel: context.l10n.tooltipPlay,
              shuffleTooltip: context.l10n.actionShuffle,
              onPlay: () => _playAll(tracks),
              onShuffle: () => _shuffleAll(tracks),
            )
          : null,
    );
  }

  Widget _buildSquareCover(
    BuildContext context,
    ColorScheme colorScheme,
    String? embeddedCoverPath,
    double coverSize,
    int cacheWidth,
  ) {
    Widget placeholder() => Container(
      color: colorScheme.surfaceContainerHighest,
      child: Icon(Icons.album, size: 48, color: colorScheme.onSurfaceVariant),
    );

    if (embeddedCoverPath != null) {
      return Image.file(
        File(embeddedCoverPath),
        fit: BoxFit.cover,
        width: coverSize,
        height: coverSize,
        cacheWidth: cacheWidth,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => placeholder(),
      );
    }

    final coverUrl = widget.coverUrl;
    if (coverUrl != null && coverUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: highResCoverUrl(coverUrl) ?? coverUrl,
        fit: BoxFit.cover,
        width: coverSize,
        height: coverSize,
        memCacheWidth: cacheWidth,
        cacheManager: CoverCacheManager.instance,
        placeholder: (_, _) => placeholder(),
        errorWidget: (_, _, _) => placeholder(),
      );
    }

    return placeholder();
  }

  Widget _metaWhiteItem(IconData? icon, String label) {
    const textStyle = TextStyle(
      color: Colors.white,
      fontSize: 13,
      fontWeight: FontWeight.w500,
    );
    if (icon == null) return Text(label, style: textStyle);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Colors.white),
        const SizedBox(width: 4),
        Text(label, style: textStyle),
      ],
    );
  }

  Widget _buildDownloadedHeaderMeta(
    BuildContext context,
    List<DownloadHistoryItem> tracks,
    String? commonQuality,
  ) {
    final totalSeconds = tracks.fold<int>(
      0,
      (sum, t) => sum + ((t.duration ?? 0) > 0 ? t.duration! : 0),
    );
    final totalMinutes = (totalSeconds / 60).round();

    final parts = <Widget>[];
    void add(Widget w) {
      if (parts.isNotEmpty) {
        parts.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '•',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        );
      }
      parts.add(w);
    }

    add(
      _metaWhiteItem(
        null,
        context.l10n.downloadedAlbumDownloadedCount(tracks.length),
      ),
    );
    if (totalMinutes > 0) add(_metaWhiteItem(null, '$totalMinutes min'));
    if (commonQuality != null && commonQuality.isNotEmpty) {
      add(_metaWhiteItem(Icons.graphic_eq, commonQuality));
    }

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 4,
      children: parts,
    );
  }

  Future<void> _playAll(List<DownloadHistoryItem> tracks) async {
    if (tracks.isEmpty) return;
    await ref.read(musicPlayerControllerProvider).setShuffle(false);
    await _openFile(tracks.first, queueItems: tracks);
  }

  Future<void> _shuffleAll(List<DownloadHistoryItem> tracks) async {
    if (tracks.isEmpty) return;
    await ref.read(musicPlayerControllerProvider).setShuffle(true);
    await _openFile(
      tracks[Random().nextInt(tracks.length)],
      queueItems: tracks,
    );
  }

  String? _getCommonQuality(List<DownloadHistoryItem> tracks) {
    if (identical(tracks, _commonQualitySourceCache)) {
      return _commonQualityCache;
    }

    if (tracks.isEmpty) {
      _commonQualitySourceCache = tracks;
      _commonQualityCache = null;
      return null;
    }
    final firstQuality = tracks.first.quality;
    if (firstQuality == null) {
      _commonQualitySourceCache = tracks;
      _commonQualityCache = null;
      return null;
    }
    for (final track in tracks) {
      if (track.quality != firstQuality) {
        _commonQualitySourceCache = tracks;
        _commonQualityCache = null;
        return null;
      }
    }
    _commonQualitySourceCache = tracks;
    _commonQualityCache = firstQuality;
    return firstQuality;
  }

  Widget _buildTrackList(
    BuildContext context,
    ColorScheme colorScheme,
    List<DownloadHistoryItem> tracks,
  ) {
    final discMap = _getDiscGroups(tracks);

    if (discMap.length <= 1) {
      return SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final track = tracks[index];
          return KeyedSubtree(
            key: ValueKey(track.id),
            child: StaggeredListItem(
              index: index,
              child: _buildTrackItem(
                context,
                colorScheme,
                track,
                tracks,
                index,
              ),
            ),
          );
        }, childCount: tracks.length),
      );
    }

    final discNumbers = _getSortedDiscNumbers(tracks);
    final List<Widget> children = [];
    var revealIndex = 0;

    for (final discNumber in discNumbers) {
      final discTracks = discMap[discNumber];
      if (discTracks == null || discTracks.isEmpty) continue;

      children.add(DiscSeparatorChip(discNumber: discNumber));

      for (final track in discTracks) {
        final navigationIndex = tracks.indexOf(track);
        children.add(
          KeyedSubtree(
            key: ValueKey(track.id),
            child: StaggeredListItem(
              index: revealIndex++,
              child: _buildTrackItem(
                context,
                colorScheme,
                track,
                tracks,
                navigationIndex,
              ),
            ),
          ),
        );
      }
    }

    return SliverList(delegate: SliverChildListDelegate(children));
  }

  Widget _buildTrackItem(
    BuildContext context,
    ColorScheme colorScheme,
    DownloadHistoryItem track,
    List<DownloadHistoryItem> navigationItems,
    int navigationIndex,
  ) {
    final isSelected = _selectedIds.contains(track.id);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Card(
        elevation: 0,
        color: isSelected
            ? colorScheme.primaryContainer.withValues(alpha: 0.3)
            : Colors.transparent,
        margin: const EdgeInsets.symmetric(vertical: 2),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onTap: _isSelectionMode
              ? () => _toggleSelection(track.id)
              : () => _navigateToMetadataScreen(
                  track,
                  navigationItems: navigationItems,
                  navigationIndex: navigationIndex,
                ),
          onLongPress: _isSelectionMode
              ? null
              : () => _enterSelectionMode(track.id),
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isSelectionMode) ...[
                AnimatedSelectionCheckbox(
                  visible: true,
                  selected: isSelected,
                  colorScheme: colorScheme,
                  size: 24,
                ),
                const SizedBox(width: 12),
              ],
              SizedBox(
                width: 24,
                child: Text(
                  track.trackNumber?.toString() ?? '-',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          title: Text(
            track.trackName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            track.artistName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          trailing: _isSelectionMode
              ? null
              : IconButton(
                  tooltip: context.l10n.tooltipPlay,
                  onPressed: () =>
                      _openFile(track, queueItems: navigationItems),
                  icon: Icon(Icons.play_arrow, color: colorScheme.primary),
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.primaryContainer.withValues(
                      alpha: 0.3,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _shareSelected(List<DownloadHistoryItem> allTracks) async {
    final tracksById = {for (final t in allTracks) t.id: t};
    final safUris = <String>[];
    final filesToShare = <XFile>[];

    for (final id in _selectedIds) {
      final item = tracksById[id];
      if (item == null) continue;
      final path = item.filePath;
      if (isContentUri(path)) {
        if (await fileExists(path)) safUris.add(path);
      } else if (await fileExists(path)) {
        filesToShare.add(XFile(path));
      }
    }

    if (safUris.isEmpty && filesToShare.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.selectionShareNoFiles)),
        );
      }
      return;
    }

    if (safUris.isNotEmpty) {
      try {
        if (safUris.length == 1) {
          await PlatformBridge.shareContentUri(safUris.first);
        } else {
          await PlatformBridge.shareMultipleContentUris(safUris);
        }
      } catch (_) {}
    }

    if (filesToShare.isNotEmpty) {
      await SharePlus.instance.share(ShareParams(files: filesToShare));
    }
  }

  List<UnifiedLibraryItem> _selectedUnifiedItems(
    List<DownloadHistoryItem> tracks,
  ) {
    final tracksById = {for (final t in tracks) t.id: t};
    return [
      for (final t in _selectedIds.map((id) => tracksById[id]))
        if (t != null) UnifiedLibraryItem.fromDownloadHistory(t),
    ];
  }

  Widget _buildSelectionBottomBar(
    BuildContext context,
    ColorScheme colorScheme,
    List<DownloadHistoryItem> tracks,
    double bottomPadding,
  ) {
    final selectedCount = _selectedIds.length;
    final allSelected = selectedCount == tracks.length && tracks.isNotEmpty;

    return SelectionBottomBar(
      selectedCount: selectedCount,
      allSelected: allSelected,
      onClose: _exitSelectionMode,
      onToggleSelectAll: () {
        if (allSelected) {
          _exitSelectionMode();
        } else {
          _selectAll(tracks);
        }
      },
      bottomPadding: bottomPadding,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 8.0;
            final itemWidth = (constraints.maxWidth - spacing) / 2;
            final actions = <Widget>[
              SelectionActionButton(
                icon: Icons.share_outlined,
                label: context.l10n.selectionShareCount(selectedCount),
                onPressed: selectedCount > 0
                    ? () => _shareSelected(tracks)
                    : null,
                colorScheme: colorScheme,
              ),
              SelectionActionButton(
                icon: Icons.swap_horiz,
                label: context.l10n.selectionConvertCount(selectedCount),
                onPressed: selectedCount > 0
                    ? () => showBatchConvertSheet(
                        context,
                        ref,
                        _selectedUnifiedItems(tracks),
                        onExitSelectionMode: _exitSelectionMode,
                      )
                    : null,
                colorScheme: colorScheme,
              ),
              SelectionActionButton(
                icon: Icons.graphic_eq,
                label: context.l10n.selectionReplayGainCount(selectedCount),
                onPressed: selectedCount > 0
                    ? () => runBatchReplayGain(
                        context,
                        _selectedUnifiedItems(tracks),
                        onExitSelectionMode: _exitSelectionMode,
                      )
                    : null,
                colorScheme: colorScheme,
              ),
            ];

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final action in actions)
                  SizedBox(width: itemWidth, child: action),
              ],
            );
          },
        ),

        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: selectedCount > 0 ? () => _deleteSelected(tracks) : null,
            icon: const Icon(Icons.delete_outline),
            label: Text(
              selectedCount > 0
                  ? context.l10n.downloadedAlbumDeleteCount(selectedCount)
                  : context.l10n.downloadedAlbumSelectToDelete,
            ),
            style: FilledButton.styleFrom(
              backgroundColor: selectedCount > 0
                  ? colorScheme.error
                  : colorScheme.surfaceContainerHighest,
              foregroundColor: selectedCount > 0
                  ? colorScheme.onError
                  : colorScheme.onSurfaceVariant,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
