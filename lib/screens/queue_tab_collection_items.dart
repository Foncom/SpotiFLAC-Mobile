part of 'queue_tab.dart';

extension _QueueTabCollectionItemWidgets on _QueueTabState {
  Widget _buildDownloadGridItem(
    BuildContext context,
    DownloadItem item,
    ColorScheme colorScheme,
  ) {
    final radius = BorderRadius.circular(8);
    final isDownloading = item.status == DownloadStatus.downloading;
    final isFinalizing = item.status == DownloadStatus.finalizing;
    final isQueued = item.status == DownloadStatus.queued;
    final isFailed = item.status == DownloadStatus.failed;
    final progress = item.progress.clamp(0.0, 1.0);
    final pct = (progress * 100).round();

    final cover = item.track.coverUrl != null
        ? CachedCoverImage(
            imageUrl: item.track.coverUrl!,
            borderRadius: radius,
            fadeInDuration: const Duration(milliseconds: 180),
          )
        : Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: radius,
            ),
            child: Icon(Icons.music_note, color: colorScheme.onSurfaceVariant),
          );

    final onTap = isFailed
        ? () => _showDownloadErrorDialog(context, item)
        : item.status == DownloadStatus.skipped
        ? () => ref.read(downloadQueueProvider.notifier).removeItem(item.id)
        : () => _confirmCancelDownload(context, item);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(borderRadius: radius, child: cover),
                if (isDownloading || isFinalizing || isQueued)
                  ClipRRect(
                    borderRadius: radius,
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.45),
                    ),
                  ),
                if (isDownloading || isFinalizing || isQueued)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 34,
                          height: 34,
                          child: CircularProgressIndicator(
                            value: (isFinalizing || isQueued || progress <= 0)
                                ? null
                                : progress,
                            strokeWidth: 3,
                            color: Colors.white,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.25,
                            ),
                          ),
                        ),
                        if (isDownloading && progress > 0) ...[
                          const SizedBox(height: 6),
                          Text(
                            '$pct%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                if (isFailed)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.error_outline,
                        color: colorScheme.error,
                        size: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.track.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
          Text(
            item.track.artistName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBridgeGridItem(
    BuildContext context,
    Track track,
    ColorScheme colorScheme,
  ) {
    final radius = BorderRadius.circular(8);
    final cover = track.coverUrl != null
        ? CachedCoverImage(imageUrl: track.coverUrl!, borderRadius: radius)
        : Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: radius,
            ),
            child: Icon(Icons.music_note, color: colorScheme.onSurfaceVariant),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(borderRadius: radius, child: cover),
              if (track.hasAudioQuality)
                Positioned(
                  left: 4,
                  top: 4,
                  child: AudioQualityBadge(
                    label: track.audioQuality!,
                    colorScheme: colorScheme,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          track.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
        ),
        Text(
          track.artistName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildBridgeListItem(
    BuildContext context,
    Track track,
    ColorScheme colorScheme,
  ) {
    final coverSize = _queueCoverSize();
    final radius = BorderRadius.circular(8);
    final cover = track.coverUrl != null
        ? CachedCoverImage(
            imageUrl: track.coverUrl!,
            width: coverSize,
            height: coverSize,
            borderRadius: radius,
          )
        : Container(
            width: coverSize,
            height: coverSize,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: radius,
            ),
            child: Icon(Icons.music_note, color: colorScheme.onSurfaceVariant),
          );
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            cover,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track.artistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionListItem({
    required BuildContext context,
    required ColorScheme colorScheme,
    IconData? icon,
    Color? iconColor,
    Color? iconBgColor,
    Widget? coverWidget,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    final cover =
        coverWidget ??
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: iconBgColor ?? colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon ?? Icons.folder,
            color: iconColor ?? Colors.white,
            size: 28,
          ),
        );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(width: 56, height: 56, child: cover),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollectionGridItem({
    required BuildContext context,
    required ColorScheme colorScheme,
    IconData? icon,
    Color? iconColor,
    Color? iconBgColor,
    Widget? coverWidget,
    required String title,
    required int count,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    final cover =
        coverWidget ??
        Container(
          decoration: BoxDecoration(
            color: iconBgColor ?? colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon ?? Icons.folder,
            color: iconColor ?? Colors.white,
            size: 40,
          ),
        );

    return Semantics(
      button: true,
      label: context.l10n.a11yOpenItemCount(title, count),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: cover,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
            ),
            Text(
              context.l10n.itemCount(count),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_CollectionEntry> _getVisibleCollectionEntries(
    LibraryCollectionsState collectionState,
  ) {
    final entries = <_CollectionEntry>[];
    if (collectionState.wishlistCount > 0) {
      entries.add(_CollectionEntry.wishlist);
    }
    if (collectionState.lovedCount > 0) {
      entries.add(_CollectionEntry.loved);
    }
    if (collectionState.favoriteArtistCount > 0) {
      entries.add(_CollectionEntry.favoriteArtists);
    }
    for (var i = 0; i < collectionState.playlists.length; i++) {
      entries.add(_CollectionEntry.playlist(i));
    }
    return entries;
  }

  Widget _buildAllTabGridCollectionItem({
    required BuildContext context,
    required ColorScheme colorScheme,
    required _CollectionEntry entry,
    required LibraryCollectionsState collectionState,
    List<UnifiedLibraryItem> filteredUnifiedItems = const [],
  }) {
    switch (entry.type) {
      case _CollectionEntryType.wishlist:
        return _buildCollectionGridItem(
          context: context,
          colorScheme: colorScheme,
          icon: Icons.add_circle_outline,
          iconColor: Colors.white,
          iconBgColor: const Color(0xFF1DB954),
          title: context.l10n.collectionWishlist,
          count: collectionState.wishlistCount,
          onTap: _openWishlistFolder,
        );
      case _CollectionEntryType.loved:
        return _buildCollectionGridItem(
          context: context,
          colorScheme: colorScheme,
          icon: Icons.favorite,
          iconColor: Colors.white,
          iconBgColor: const Color(0xFF8C67AC),
          title: context.l10n.collectionLoved,
          count: collectionState.lovedCount,
          onTap: _openLovedFolder,
        );
      case _CollectionEntryType.favoriteArtists:
        return _buildCollectionGridItem(
          context: context,
          colorScheme: colorScheme,
          icon: Icons.person,
          iconColor: Colors.white,
          iconBgColor: const Color(0xFFE91E63),
          title: context.l10n.collectionFavoriteArtists,
          count: collectionState.favoriteArtistCount,
          onTap: _openFavoriteArtistsFolder,
        );
      case _CollectionEntryType.playlist:
        final playlist = collectionState.playlists[entry.playlistIndex];
        final isSelected = _selectedPlaylistIds.contains(playlist.id);
        return DragTarget<UnifiedLibraryItem>(
          onWillAcceptWithDetails: (_) => !_isPlaylistSelectionMode,
          onAcceptWithDetails: (details) {
            _onTrackDroppedOnPlaylist(
              context,
              details.data,
              playlist.id,
              playlist.name,
              allItems: filteredUnifiedItems,
            );
          },
          builder: (context, candidateData, rejectedData) {
            final isHovering = candidateData.isNotEmpty;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: isHovering
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.primary, width: 2),
                      color: colorScheme.primary.withValues(alpha: 0.1),
                    )
                  : null,
              child: Stack(
                children: [
                  _buildCollectionGridItem(
                    context: context,
                    colorScheme: colorScheme,
                    coverWidget: _buildPlaylistCover(
                      context,
                      playlist,
                      colorScheme,
                    ),
                    title: playlist.name,
                    count: playlist.tracks.length,
                    onTap: _isPlaylistSelectionMode
                        ? () => _togglePlaylistSelection(playlist.id)
                        : () => _openPlaylistById(playlist.id),
                    onLongPress: _isPlaylistSelectionMode
                        ? () => _togglePlaylistSelection(playlist.id)
                        : () => _enterPlaylistSelectionMode(playlist.id),
                  ),
                  if (_isPlaylistSelectionMode)
                    Positioned(
                      left: 0,
                      top: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colorScheme.primary.withValues(alpha: 0.3)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_isPlaylistSelectionMode)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IgnorePointer(
                        child: AnimatedSelectionCheckbox(
                          visible: true,
                          selected: isSelected,
                          colorScheme: colorScheme,
                          size: 20,
                          unselectedColor: colorScheme.surface.withValues(
                            alpha: 0.85,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
    }
  }

  Widget _buildAllTabListCollectionItem({
    required BuildContext context,
    required ColorScheme colorScheme,
    required _CollectionEntry entry,
    required LibraryCollectionsState collectionState,
    List<UnifiedLibraryItem> filteredUnifiedItems = const [],
  }) {
    switch (entry.type) {
      case _CollectionEntryType.wishlist:
        return _buildCollectionListItem(
          context: context,
          colorScheme: colorScheme,
          icon: Icons.add_circle_outline,
          iconColor: Colors.white,
          iconBgColor: const Color(0xFF1DB954),
          title: context.l10n.collectionWishlist,
          subtitle:
              '${context.l10n.collectionFoldersTitle} • ${collectionState.wishlistCount} ${collectionState.wishlistCount == 1 ? 'track' : 'tracks'}',
          onTap: _openWishlistFolder,
        );
      case _CollectionEntryType.loved:
        return _buildCollectionListItem(
          context: context,
          colorScheme: colorScheme,
          icon: Icons.favorite,
          iconColor: Colors.white,
          iconBgColor: const Color(0xFF8C67AC),
          title: context.l10n.collectionLoved,
          subtitle:
              '${context.l10n.collectionFoldersTitle} • ${collectionState.lovedCount} ${collectionState.lovedCount == 1 ? 'track' : 'tracks'}',
          onTap: _openLovedFolder,
        );
      case _CollectionEntryType.favoriteArtists:
        return _buildCollectionListItem(
          context: context,
          colorScheme: colorScheme,
          icon: Icons.person,
          iconColor: Colors.white,
          iconBgColor: const Color(0xFFE91E63),
          title: context.l10n.collectionFavoriteArtists,
          subtitle:
              '${context.l10n.collectionFoldersTitle} • ${context.l10n.collectionArtistCount(collectionState.favoriteArtistCount)}',
          onTap: _openFavoriteArtistsFolder,
        );
      case _CollectionEntryType.playlist:
        final playlist = collectionState.playlists[entry.playlistIndex];
        final isSelected = _selectedPlaylistIds.contains(playlist.id);
        return DragTarget<UnifiedLibraryItem>(
          onWillAcceptWithDetails: (_) => !_isPlaylistSelectionMode,
          onAcceptWithDetails: (details) {
            _onTrackDroppedOnPlaylist(
              context,
              details.data,
              playlist.id,
              playlist.name,
              allItems: filteredUnifiedItems,
            );
          },
          builder: (context, candidateData, rejectedData) {
            final isHovering = candidateData.isNotEmpty;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: isHovering
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.primary, width: 2),
                      color: colorScheme.primary.withValues(alpha: 0.1),
                    )
                  : null,
              child: Row(
                children: [
                  if (_isPlaylistSelectionMode)
                    GestureDetector(
                      onTap: () => _togglePlaylistSelection(playlist.id),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: AnimatedSelectionCheckbox(
                          visible: true,
                          selected: isSelected,
                          colorScheme: colorScheme,
                          size: 24,
                        ),
                      ),
                    ),
                  Expanded(
                    child: _buildCollectionListItem(
                      context: context,
                      colorScheme: colorScheme,
                      coverWidget: _buildPlaylistCover(
                        context,
                        playlist,
                        colorScheme,
                        56,
                      ),
                      title: playlist.name,
                      subtitle:
                          '${playlist.tracks.length} ${playlist.tracks.length == 1 ? 'track' : 'tracks'}',
                      onTap: _isPlaylistSelectionMode
                          ? () => _togglePlaylistSelection(playlist.id)
                          : () => _openPlaylistById(playlist.id),
                      onLongPress: _isPlaylistSelectionMode
                          ? () => _togglePlaylistSelection(playlist.id)
                          : () => _enterPlaylistSelectionMode(playlist.id),
                    ),
                  ),
                ],
              ),
            );
          },
        );
    }
  }

}
