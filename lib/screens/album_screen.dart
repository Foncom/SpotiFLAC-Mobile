import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:spotiflac_android/services/cover_cache_manager.dart';
import 'package:spotiflac_android/l10n/l10n.dart';
import 'package:spotiflac_android/models/track.dart';
import 'package:spotiflac_android/providers/download_queue_provider.dart';
import 'package:spotiflac_android/providers/extension_provider.dart';
import 'package:spotiflac_android/providers/settings_provider.dart';
import 'package:spotiflac_android/providers/recent_access_provider.dart';
import 'package:spotiflac_android/providers/local_library_provider.dart';
import 'package:spotiflac_android/services/platform_bridge.dart';
import 'package:spotiflac_android/utils/image_cache_utils.dart';
import 'package:spotiflac_android/utils/string_utils.dart';
import 'package:spotiflac_android/utils/cover_art_utils.dart';
import 'package:spotiflac_android/widgets/error_card.dart';
import 'package:spotiflac_android/widgets/album_detail_header.dart';
import 'package:spotiflac_android/utils/nav_bar_inset.dart';
import 'package:spotiflac_android/utils/provider_resource_ids.dart';
import 'package:spotiflac_android/widgets/download_service_picker.dart';
import 'package:spotiflac_android/widgets/animation_utils.dart';
import 'package:spotiflac_android/providers/library_collections_provider.dart';
import 'package:spotiflac_android/widgets/playlist_picker_sheet.dart';
import 'package:spotiflac_android/utils/clickable_metadata.dart';
import 'package:spotiflac_android/widgets/cross_extension_share_sheet.dart';
import 'package:spotiflac_android/widgets/track_list_tile.dart';
import 'package:spotiflac_android/widgets/motion_header_banner.dart';

class _AlbumCache {
  static final Map<String, _CacheEntry> _cache = {};
  static const Duration _ttl = Duration(minutes: 10);

  static List<Track>? get(String albumId) {
    final entry = _cache[albumId];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _cache.remove(albumId);
      return null;
    }
    return entry.tracks;
  }

  static void set(String albumId, List<Track> tracks) {
    _cache[albumId] = _CacheEntry(tracks, DateTime.now().add(_ttl));
  }
}

class _CacheEntry {
  final List<Track> tracks;
  final DateTime expiresAt;
  _CacheEntry(this.tracks, this.expiresAt);
}

class AlbumScreen extends ConsumerStatefulWidget {
  final String albumId;
  final String albumName;
  final String? coverUrl;
  final String? headerVideoUrl;
  final String? headerImageUrl;
  final List<String>? audioTraits;
  final List<Track>? tracks;
  final String? extensionId;
  final String? artistId;
  final String? artistName;

  const AlbumScreen({
    super.key,
    required this.albumId,
    required this.albumName,
    this.coverUrl,
    this.headerVideoUrl,
    this.headerImageUrl,
    this.audioTraits,
    this.tracks,
    this.extensionId,
    this.artistId,
    this.artistName,
  });

  @override
  ConsumerState<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends ConsumerState<AlbumScreen> {
  List<Track>? _tracks;
  bool _isLoading = false;
  String? _error;
  bool _showTitleInAppBar = false;
  String? _artistId;
  String? _albumType;
  int? _albumTotalTracks;
  String? _headerVideoUrl;
  String? _headerImageUrl;
  List<String> _audioTraits = const [];
  bool _tallHeader = false;
  final ScrollController _scrollController = ScrollController();


  String _effectiveMetadataProviderIdFromAlbumId() {
    if (widget.extensionId != null && widget.extensionId!.isNotEmpty) {
      return widget.extensionId!;
    }
    return resolveEffectiveMetadataProvider(
      legacyProviderIdFromResourceId(widget.albumId) ?? 'spotify',
      ref.read(extensionProvider),
    );
  }


  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final providerId = _effectiveMetadataProviderIdFromAlbumId();
      ref
          .read(recentAccessProvider.notifier)
          .recordAlbumAccess(
            id: widget.albumId,
            name: widget.albumName,
            artistName:
                widget.artistName ??
                widget.tracks?.firstOrNull?.albumArtist ??
                widget.tracks?.firstOrNull?.artistName,
            imageUrl: widget.coverUrl,
            providerId: providerId,
          );
    });

    if (widget.tracks != null && widget.tracks!.isNotEmpty) {
      _tracks = widget.tracks;
    } else {
      _tracks = _AlbumCache.get(widget.albumId);
    }
    _artistId = widget.artistId;
    _albumType = _tracks?.firstOrNull?.albumType;
    _albumTotalTracks = _tracks?.firstOrNull?.totalTracks;
    _headerVideoUrl = widget.headerVideoUrl;
    _headerImageUrl = widget.headerImageUrl;
    _audioTraits = widget.audioTraits ?? const [];

    if (_tracks == null || _tracks!.isEmpty) {
      _fetchTracks();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final expandedHeight = _calculateExpandedHeight(context, tall: _tallHeader);
    final shouldShow =
        _scrollController.offset > (expandedHeight - kToolbarHeight - 20);
    if (shouldShow != _showTitleInAppBar) {
      setState(() => _showTitleInAppBar = shouldShow);
    }
  }

  double _calculateExpandedHeight(BuildContext context, {bool tall = false}) {
    final mediaSize = MediaQuery.sizeOf(context);
    if (tall) {
      return (mediaSize.height * 0.68).clamp(440.0, 660.0);
    }
    return (mediaSize.height * 0.6).clamp(400.0, 580.0);
  }

  String _formatReleaseDate(String date) {
    if (date.length >= 10) {
      final parts = date.substring(0, 10).split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
    } else if (date.length >= 7) {
      final parts = date.split('-');
      if (parts.length >= 2) {
        return '${parts[1]}/${parts[0]}';
      }
    }
    return date;
  }

  Future<void> _fetchTracks() async {
    setState(() => _isLoading = true);
    try {
      final directProviderId = _directMetadataProviderId();
      if (directProviderId != null) {
        final metadata = await PlatformBridge.getProviderMetadata(
          directProviderId,
          'album',
          _metadataResourceId(directProviderId),
        );
        final trackList = metadata['track_list'] as List<dynamic>;
        final albumInfo = metadata['album_info'] as Map<String, dynamic>?;
        final artistId = (albumInfo?['artist_id'] ?? albumInfo?['artistId'])
            ?.toString();
        final albumType = normalizeOptionalString(
          albumInfo?['album_type']?.toString(),
        );
        final totalTracks = albumInfo?['total_tracks'] as int?;
        final headerVideo = albumInfo?['header_video']?.toString();
        final headerImage = albumInfo?['header_image']?.toString();
        final audioTraits = (albumInfo?['audio_traits'] as List?)
            ?.map((e) => e.toString())
            .toList();
        final tracks = trackList
            .map(
              (t) => _parseTrack(
                t as Map<String, dynamic>,
                albumTypeFallback: albumType,
                totalTracksFallback: totalTracks,
              ),
            )
            .toList();

        _AlbumCache.set(widget.albumId, tracks);

        if (mounted) {
          setState(() {
            _tracks = tracks;
            _artistId = artistId;
            _albumType = albumType;
            _albumTotalTracks = totalTracks;
            _headerVideoUrl = (headerVideo != null && headerVideo.isNotEmpty)
                ? headerVideo
                : _headerVideoUrl;
            _headerImageUrl = (headerImage != null && headerImage.isNotEmpty)
                ? headerImage
                : _headerImageUrl;
            _audioTraits = (audioTraits != null && audioTraits.isNotEmpty)
                ? audioTraits
                : _audioTraits;
            _isLoading = false;
          });
        }
        return;
      } else {
        final url = 'https://open.spotify.com/album/${widget.albumId}';
        final result = await PlatformBridge.handleURLWithExtension(url);
        if (result == null || result['tracks'] == null) {
          throw StateError('Failed to load album metadata from extension');
        }

        final trackList = result['tracks'] as List<dynamic>;
        final albumInfo = result['album'] as Map<String, dynamic>?;
        final artistId = (albumInfo?['artist_id'] ?? albumInfo?['artistId'])
            ?.toString();
        final albumType = normalizeOptionalString(
          albumInfo?['album_type']?.toString(),
        );
        final totalTracks = albumInfo?['total_tracks'] as int?;
        final headerVideo =
            (albumInfo?['header_video'] ?? result['header_video'])?.toString();
        final headerImage =
            (albumInfo?['header_image'] ?? result['header_image'])?.toString();
        final audioTraits =
            ((albumInfo?['audio_traits'] ?? result['audio_traits']) as List?)
                ?.map((e) => e.toString())
                .toList();
        final tracks = trackList
            .map(
              (t) => _parseTrack(
                t as Map<String, dynamic>,
                albumTypeFallback: albumType,
                totalTracksFallback: totalTracks,
              ),
            )
            .toList();

        _AlbumCache.set(widget.albumId, tracks);

        if (mounted) {
          setState(() {
            _tracks = tracks;
            _artistId = artistId;
            _albumType = albumType;
            _albumTotalTracks = totalTracks;
            _headerVideoUrl = (headerVideo != null && headerVideo.isNotEmpty)
                ? headerVideo
                : _headerVideoUrl;
            _headerImageUrl = (headerImage != null && headerImage.isNotEmpty)
                ? headerImage
                : _headerImageUrl;
            _audioTraits = (audioTraits != null && audioTraits.isNotEmpty)
                ? audioTraits
                : _audioTraits;
            _isLoading = false;
          });
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String? _directMetadataProviderId() {
    final providerId = _effectiveMetadataProviderIdFromAlbumId();
    return providerId.isEmpty ? null : providerId;
  }

  String _metadataResourceId(String providerId) {
    return stripPrefixedResourceId(widget.albumId);
  }

  Widget _metaInlineItem(IconData? icon, String label) {
    const textStyle = TextStyle(
      color: Colors.white,
      fontSize: 13,
      fontWeight: FontWeight.w500,
    );
    if (icon == null) {
      return Text(label, style: textStyle);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Colors.white),
        const SizedBox(width: 4),
        Text(label, style: textStyle),
      ],
    );
  }

  List<Widget> _audioTraitInline() {
    final traits = _audioTraits
        .map((t) => t.toLowerCase().trim())
        .where((t) => t.isNotEmpty)
        .toSet();
    if (traits.isEmpty) return const [];

    bool has(List<String> keys) => keys.any(traits.contains);

    final items = <Widget>[];
    if (has(['atmos', 'dolby_atmos', 'dolby-atmos'])) {
      items.add(_metaInlineItem(Icons.surround_sound, 'Dolby Atmos'));
    } else if (has(['spatial'])) {
      items.add(_metaInlineItem(Icons.surround_sound, 'Spatial Audio'));
    }

    if (has(['hi-res-lossless', 'hi_res_lossless', 'hires-lossless'])) {
      items.add(_metaInlineItem(Icons.graphic_eq, 'Hi-Res Lossless'));
    } else if (has(['lossless'])) {
      items.add(_metaInlineItem(Icons.graphic_eq, 'Lossless'));
    }

    return items;
  }

  Widget _buildHeaderMeta(BuildContext context, String? releaseDate) {
    final items = <Widget>[];

    void add(Widget widget) {
      if (items.isNotEmpty) {
        items.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '•',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        );
      }
      items.add(widget);
    }

    final year = _releaseYear(releaseDate);
    if (year != null) {
      add(_metaInlineItem(null, year));
    }
    for (final trait in _audioTraitInline()) {
      add(trait);
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 20),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 0,
        runSpacing: 4,
        children: items,
      ),
    );
  }

  String? _releaseYear(String? date) {
    if (date == null || date.isEmpty) return null;
    final match = RegExp(r'(\d{4})').firstMatch(date);
    return match?.group(1);
  }

  Track _parseTrack(
    Map<String, dynamic> data, {
    String? albumTypeFallback,
    int? totalTracksFallback,
  }) {
    return Track(
      id: data['spotify_id'] as String? ?? '',
      name: data['name'] as String? ?? '',
      artistName: data['artists'] as String? ?? '',
      albumName: data['album_name'] as String? ?? '',
      albumArtist: data['album_artist'] as String?,
      artistId:
          (data['artist_id'] ?? data['artistId'])?.toString() ?? _artistId,
      albumId: data['album_id']?.toString() ?? widget.albumId,
      coverUrl: normalizeCoverReference(data['images']?.toString()),
      isrc: data['isrc'] as String?,
      duration: ((data['duration_ms'] as int? ?? 0) / 1000).round(),
      trackNumber: data['track_number'] as int?,
      discNumber: data['disc_number'] as int?,
      totalDiscs: data['total_discs'] as int?,
      releaseDate: data['release_date'] as String?,
      albumType:
          normalizeOptionalString(data['album_type']?.toString()) ??
          albumTypeFallback ??
          _albumType,
      totalTracks:
          data['total_tracks'] as int? ??
          totalTracksFallback ??
          _albumTotalTracks,
      composer: data['composer']?.toString(),
      audioQuality: data['audio_quality']?.toString(),
      audioModes: data['audio_modes']?.toString(),
      previewUrl: data['preview_url']?.toString(),
      explicit: parseExplicitFlag(data['explicit']),
    );
  }

  String? _recommendedDownloadService() {
    return _directMetadataProviderId();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tracks = _tracks ?? [];
    final pageBackgroundColor = colorScheme.surface;
    final bottomInset = context.navBarBottomInset;

    return Scaffold(
      backgroundColor: pageBackgroundColor,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildAppBar(context, colorScheme, pageBackgroundColor),
          _buildInfoCard(context, colorScheme),
          if (_isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: AlbumTrackListSkeleton(itemCount: 10),
              ),
            ),
          if (_error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ErrorCard(error: _error!, colorScheme: colorScheme),
              ),
            ),
          if (!_isLoading && _error == null && tracks.isNotEmpty) ...[
            _buildTrackList(context, colorScheme, tracks),
            _buildAlbumFooter(context, colorScheme, tracks),
          ],
          SliverToBoxAdapter(child: SizedBox(height: 32 + bottomInset)),
        ],
      ),
    );
  }

  Widget _buildAppBar(
    BuildContext context,
    ColorScheme colorScheme,
    Color pageBackgroundColor,
  ) {
    final tracks = _tracks ?? [];
    final artistName =
        widget.artistName ??
        (tracks.isNotEmpty
            ? (tracks.first.albumArtist ?? tracks.first.artistName)
            : null);
    final releaseDate = tracks.isNotEmpty ? tracks.first.releaseDate : null;

    final motionUrl = _headerVideoUrl ?? widget.headerVideoUrl;
    final hasMotion =
        motionUrl != null &&
        motionUrl.trim().isNotEmpty &&
        Uri.tryParse(motionUrl)?.hasAuthority == true;
    final coverThumbUrl = widget.coverUrl ?? _headerImageUrl;
    final showSquareCover = !hasMotion;
    _tallHeader = false;
    final expandedHeight = _calculateExpandedHeight(context);
    final cacheWidth = coverCacheWidthForViewport(context);
    final headerBgUrl =
        _headerImageUrl ?? widget.headerImageUrl ?? widget.coverUrl;
    final Widget headerBgImage = headerBgUrl != null
        ? CachedNetworkImage(
            imageUrl: highResCoverUrl(headerBgUrl) ?? headerBgUrl,
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
      backgroundColor: pageBackgroundColor,
      background: hasMotion
          ? MotionHeaderBanner(videoUrl: motionUrl, fallback: headerBgImage)
          : headerBgImage,
      blurAndScrimBackground: showSquareCover,
      coverBuilder: showSquareCover
          ? (context, coverSize) => coverThumbUrl != null
                ? CachedNetworkImage(
                    imageUrl: highResCoverUrl(coverThumbUrl) ?? coverThumbUrl,
                    fit: BoxFit.cover,
                    width: coverSize,
                    height: coverSize,
                    memCacheWidth: cacheWidth,
                    cacheManager: CoverCacheManager.instance,
                    placeholder: (_, _) =>
                        Container(color: colorScheme.surfaceContainerHighest),
                    errorWidget: (_, _, _) => Container(
                      color: colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.album,
                        size: 48,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : Container(
                    color: colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.album,
                      size: 48,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  )
          : null,
      subtitle: (artistName != null && artistName.isNotEmpty)
          ? ClickableArtistName(
              artistName: artistName,
              artistId: _artistId,
              coverUrl: widget.coverUrl,
              extensionId: widget.extensionId,
              style: TextStyle(
                color: colorScheme.primary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      meta: _buildHeaderMeta(context, releaseDate),
      actions: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLoveAllButton(),
          const SizedBox(width: 12),
          Flexible(
            child: FilledButton.icon(
              onPressed: tracks.isEmpty ? null : () => _downloadAll(context),
              icon: const Icon(Icons.download, size: 18),
              label: Text(
                context.l10n.downloadAllCount(tracks.length),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.45),
                disabledForegroundColor: Colors.black54,
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _buildAddToPlaylistButton(context),
        ],
      ),
      appBarActions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: IconButton(
            tooltip: context.l10n.openInOtherServices,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.open_in_new_rounded, color: Colors.white),
            ),
            onPressed: () => _showShareSheet(context, tracks, artistName),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context, ColorScheme colorScheme) {
    return const SliverToBoxAdapter(child: SizedBox.shrink());
  }

  Widget _buildAlbumFooter(
    BuildContext context,
    ColorScheme colorScheme,
    List<Track> tracks,
  ) {
    final releaseDate = tracks.isNotEmpty ? tracks.first.releaseDate : null;
    final totalSeconds = tracks.fold<int>(
      0,
      (sum, t) => sum + (t.duration > 0 ? t.duration : 0),
    );
    final totalMinutes = (totalSeconds / 60).round();

    final lines = <String>[];
    if (releaseDate != null && releaseDate.isNotEmpty) {
      lines.add(_formatReleaseDate(releaseDate));
    }
    final countText = context.l10n.tracksCount(tracks.length);
    lines.add(totalMinutes > 0 ? '$countText • $totalMinutes min' : countText);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  line,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackList(
    BuildContext context,
    ColorScheme colorScheme,
    List<Track> tracks,
  ) {
    final historyLookups = tracks
        .map(historyLookupForTrack)
        .toList(growable: false);
    final existingHistoryKeys = ref
        .watch(
          downloadHistoryBatchExistsProvider(
            HistoryBatchLookupRequest(historyLookups),
          ),
        )
        .maybeWhen(data: (keys) => keys, orElse: () => const <String>{});
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final track = tracks[index];
        final isInHistory = existingHistoryKeys.contains(
          historyLookups[index].lookupKey,
        );
        return KeyedSubtree(
          key: ValueKey(track.id),
          child: StaggeredListItem(
            index: index,
            child: TrackListTile(
              track: track,
              isInHistory: isInHistory,
              onDownload: () => _downloadTrack(context, track),
              clickableArtist: true,
              leading: SizedBox(
                width: 32,
                child: Center(
                  child: Text(
                    '${track.trackNumber ?? 0}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }, childCount: tracks.length),
    );
  }

  void _downloadTrack(BuildContext context, Track track) {
    final settings = ref.read(settingsProvider);
    if (settings.askQualityBeforeDownload) {
      DownloadServicePicker.show(
        context,
        trackName: track.name,
        artistName: track.artistName,
        coverUrl: track.coverUrl,
        recommendedService: _recommendedDownloadService(),
        onSelect: (quality, service) {
          ref
              .read(downloadQueueProvider.notifier)
              .addToQueue(track, service, qualityOverride: quality);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.snackbarAddedToQueue(track.name)),
            ),
          );
        },
      );
    } else {
      final extensionState = ref.read(extensionProvider);
      final service = resolveEffectiveDownloadService(
        settings.defaultService,
        extensionState,
      );
      if (service.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.extensionsNoDownloadProvider)),
        );
        return;
      }
      ref.read(downloadQueueProvider.notifier).addToQueue(track, service);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.snackbarAddedToQueue(track.name))),
      );
    }
  }

  Future<void> _downloadAll(BuildContext context) async {
    final tracks = _tracks;
    if (tracks == null || tracks.isEmpty) return;

    final historyLookups = tracks
        .map(historyLookupForTrack)
        .toList(growable: false);
    final existingHistoryKeys = await ref.read(
      downloadHistoryBatchExistsProvider(
        HistoryBatchLookupRequest(historyLookups),
      ).future,
    );
    if (!context.mounted) return;
    final settings = ref.read(settingsProvider);
    final localLibState =
        (settings.localLibraryEnabled && settings.localLibraryShowDuplicates)
        ? ref.read(localLibraryProvider)
        : null;
    final tracksToQueue = <Track>[];
    int skippedCount = 0;

    for (var i = 0; i < tracks.length; i++) {
      final track = tracks[i];
      final isInHistory = existingHistoryKeys.contains(
        historyLookups[i].lookupKey,
      );
      final isInLocal =
          localLibState?.existsInLibrary(
            isrc: track.isrc,
            trackName: track.name,
            artistName: track.artistName,
          ) ??
          false;

      if (isInHistory || isInLocal) {
        skippedCount++;
      } else {
        tracksToQueue.add(track);
      }
    }

    if (tracksToQueue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.discographySkippedDownloaded(0, skippedCount),
          ),
        ),
      );
      return;
    }

    if (settings.askQualityBeforeDownload) {
      DownloadServicePicker.show(
        context,
        trackName: '${tracksToQueue.length} tracks',
        artistName: widget.albumName,
        recommendedService: _recommendedDownloadService(),
        onSelect: (quality, service) {
          ref
              .read(downloadQueueProvider.notifier)
              .addMultipleToQueue(
                tracksToQueue,
                service,
                qualityOverride: quality,
              );
          _showQueuedSnackbar(context, tracksToQueue.length, skippedCount);
        },
      );
    } else {
      final extensionState = ref.read(extensionProvider);
      final service = resolveEffectiveDownloadService(
        settings.defaultService,
        extensionState,
      );
      if (service.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.extensionsNoDownloadProvider)),
        );
        return;
      }
      ref
          .read(downloadQueueProvider.notifier)
          .addMultipleToQueue(tracksToQueue, service);
      _showQueuedSnackbar(context, tracksToQueue.length, skippedCount);
    }
  }

  void _showQueuedSnackbar(BuildContext context, int added, int skipped) {
    final message = skipped > 0
        ? context.l10n.discographySkippedDownloaded(added, skipped)
        : context.l10n.snackbarAddedTracksToQueue(added);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildLoveAllButton() {
    final collectionsState = ref.watch(libraryCollectionsProvider);
    final tracks = _tracks;
    final allLoved =
        tracks != null &&
        tracks.isNotEmpty &&
        tracks.every((t) => collectionsState.isLoved(t));

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.15),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: IconButton(
        onPressed: tracks == null || tracks.isEmpty
            ? null
            : () => _loveAll(tracks),
        icon: Icon(
          allLoved ? Icons.favorite : Icons.favorite_border,
          size: 22,
          color: allLoved ? Colors.redAccent : Colors.white,
        ),
        tooltip: allLoved
            ? context.l10n.trackOptionRemoveFromLoved
            : context.l10n.tooltipLoveAll,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildAddToPlaylistButton(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.15),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: IconButton(
        onPressed: _tracks == null || _tracks!.isEmpty
            ? null
            : () => showAddTracksToPlaylistSheet(context, ref, _tracks!),
        icon: const Icon(Icons.add, size: 22, color: Colors.white),
        tooltip: context.l10n.tooltipAddToPlaylist,
        padding: EdgeInsets.zero,
      ),
    );
  }

  void _showShareSheet(
    BuildContext context,
    List<Track> tracks,
    String? artistName,
  ) {
    final sourceExtensionId = _directMetadataProviderId() ?? '';
    final resolvedArtists =
        artistName ??
        tracks.firstOrNull?.albumArtist ??
        tracks.firstOrNull?.artistName ??
        '';

    CrossExtensionShareSheet.show(
      context,
      name: widget.albumName,
      artists: resolvedArtists,
      type: 'album',
      sourceExtensionId: sourceExtensionId,
    );
  }

  Future<void> _loveAll(List<Track> tracks) async {
    final notifier = ref.read(libraryCollectionsProvider.notifier);
    final state = ref.read(libraryCollectionsProvider);
    final allLoved = tracks.every((t) => state.isLoved(t));

    if (allLoved) {
      for (final track in tracks) {
        final key = trackCollectionKey(track);
        await notifier.removeFromLoved(key);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.snackbarRemovedTracksFromLoved(tracks.length),
            ),
          ),
        );
      }
    } else {
      int addedCount = 0;
      for (final track in tracks) {
        if (!state.isLoved(track)) {
          await notifier.toggleLoved(track);
          addedCount++;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.snackbarAddedTracksToLoved(addedCount)),
          ),
        );
      }
    }
  }

}
