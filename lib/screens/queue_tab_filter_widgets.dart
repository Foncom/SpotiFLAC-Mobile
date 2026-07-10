part of 'queue_tab.dart';

extension _QueueTabFilterWidgets on _QueueTabState {
  Widget _buildFilterContent({
    required BuildContext context,
    required ColorScheme colorScheme,
    required String filterMode,
    required String historyViewMode,
    required bool hasQueueItems,
    required _FilterContentData filterData,
    required LibraryCollectionsState collectionState,
    required bool hasMoreLibrary,
    required bool isPageLoading,
    double bottomInset = 0,
  }) {
    final historyItems = filterData.historyItems;
    final showFilteringIndicator = filterData.showFilteringIndicator;
    final filteredGroupedAlbums = filterData.filteredGroupedAlbums;
    final filteredGroupedLocalAlbums = filterData.filteredGroupedLocalAlbums;
    final unifiedItems = filterData.unifiedItems;
    final allFilteredUnifiedItems = filterData.filteredUnifiedItems;
    final totalTrackCount = filterData.totalTrackCount;
    final totalAlbumCount = filterData.totalAlbumCount;

    final activeDownloadIds = filterMode == 'albums'
        ? const <String>[]
        : ref
              .watch(
                downloadQueueLookupProvider.select((lookup) {
                  final ids = <String>[];
                  for (final id in lookup.itemIds) {
                    final entry = lookup.byItemId[id];
                    if (entry != null &&
                        entry.status != DownloadStatus.completed) {
                      ids.add(id);
                    }
                  }
                  return _QueueItemIdsSnapshot(ids);
                }),
              )
              .ids
              .reversed
              .toList(growable: false);

    final libIdSet = <String>{
      for (final item in allFilteredUnifiedItems) item.id,
    };
    List<String> bridgeIds = const [];
    if (filterMode != 'albums' && _completionBridge.isNotEmpty) {
      final now = DateTime.now();
      final stale = <String>[];
      final pending = <String>[];
      final hasActiveDownloads = activeDownloadIds.isNotEmpty;
      _completionBridge.forEach((id, _) {
        final landed = libIdSet.contains('dl_$id');
        final addedAt = _completionBridgeAt[id];
        final expired =
            addedAt == null || now.difference(addedAt).inSeconds >= 6;
        if (activeDownloadIds.contains(id)) {
          // Re-queued (retry): the live row takes over from the bridge.
          stale.add(id);
        } else if (hasActiveDownloads) {
          // Keep just-completed tracks pinned in the lead zone while the
          // rest of the batch is still downloading, so they don't jump
          // below the remaining queue the moment they finish.
          pending.add(id);
        } else if (landed || expired) {
          stale.add(id);
        } else {
          pending.add(id);
        }
      });
      bridgeIds = pending;
      if (stale.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          var changed = false;
          for (final id in stale) {
            if (_completionBridge.remove(id) != null) changed = true;
            _completionBridgeAt.remove(id);
            _bridgePrecacheStarted.remove(id);
          }
          if (changed) _setState(() {});
        });
      }
      final toPrecache = pending
          .where((id) => !_bridgePrecacheStarted.contains(id))
          .toList(growable: false);
      if (toPrecache.isNotEmpty) {
        final historyItems = ref.read(downloadHistoryProvider).items;
        for (final id in toPrecache) {
          DownloadHistoryItem? historyItem;
          for (final h in historyItems) {
            if (h.id == id) {
              historyItem = h;
              break;
            }
          }
          if (historyItem == null) continue;
          _bridgePrecacheStarted.add(id);
          final coverUrl = historyItem.coverUrl;
          final embeddedPath = _resolveDownloadedEmbeddedCoverPath(
            historyItem.filePath,
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            try {
              if (embeddedPath != null) {
                precacheImage(FileImage(File(embeddedPath)), context);
              }
              if (coverUrl != null && coverUrl.isNotEmpty) {
                precacheImage(
                  CachedNetworkImageProvider(
                    coverUrl,
                    cacheManager: CoverCacheManager.instance,
                  ),
                  context,
                );
              }
            } catch (_) {}
          });
        }
      }
    }

    // Tracks pinned as completion-bridge cells render in the lead zone;
    // hide their history rows so they don't appear twice.
    List<UnifiedLibraryItem> filteredUnifiedItems = allFilteredUnifiedItems;
    if (bridgeIds.isNotEmpty) {
      final pinnedHistoryIds = <String>{for (final id in bridgeIds) 'dl_$id'};
      filteredUnifiedItems = allFilteredUnifiedItems
          .where((item) => !pinnedHistoryIds.contains(item.id))
          .toList(growable: false);
    }

    final downloadedNavigationItems = <DownloadHistoryItem>[];
    final downloadedNavigationIndexByUnifiedId = <String, int>{};
    final localNavigationItems = <LocalLibraryItem>[];
    final localNavigationIndexByUnifiedId = <String, int>{};

    for (final item in filteredUnifiedItems) {
      final historyItem = item.historyItem;
      if (historyItem != null) {
        downloadedNavigationIndexByUnifiedId[item.id] =
            downloadedNavigationItems.length;
        downloadedNavigationItems.add(historyItem);
      }

      final localItem = item.localItem;
      if (localItem != null) {
        localNavigationIndexByUnifiedId[item.id] = localNavigationItems.length;
        localNavigationItems.add(localItem);
      }
    }

    final leadCount = activeDownloadIds.length + bridgeIds.length;
    final collectionEntries = filterMode == 'all'
        ? _getVisibleCollectionEntries(collectionState)
        : const <_CollectionEntry>[];
    final collectionCount = collectionEntries.length;

    Widget leadGridCell(int index) {
      if (index < activeDownloadIds.length) {
        final id = activeDownloadIds[index];
        return _QueueItemSliverRow(
          key: ValueKey('dlgrid_$id'),
          itemId: id,
          colorScheme: colorScheme,
          itemBuilder: _buildDownloadGridItem,
        );
      }
      final bridgeId = bridgeIds[index - activeDownloadIds.length];
      return KeyedSubtree(
        key: ValueKey('dlgrid_bridge_$bridgeId'),
        child: _buildBridgeGridItem(
          context,
          _completionBridge[bridgeId]!,
          colorScheme,
        ),
      );
    }

    Widget leadListCell(int index) {
      if (index < activeDownloadIds.length) {
        final id = activeDownloadIds[index];
        return _QueueItemSliverRow(
          key: ValueKey('dllist_$id'),
          itemId: id,
          colorScheme: colorScheme,
          itemBuilder: _buildQueueItem,
        );
      }
      final bridgeId = bridgeIds[index - activeDownloadIds.length];
      return KeyedSubtree(
        key: ValueKey('dllist_bridge_$bridgeId'),
        child: _buildBridgeListItem(
          context,
          _completionBridge[bridgeId]!,
          colorScheme,
        ),
      );
    }

    final content = CustomScrollView(
      slivers: [
        if (totalTrackCount > 0 && filterMode == 'all')
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Text(
                    context.l10n.queueTrackCount(totalTrackCount),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (!_isSelectionMode)
                    _buildFilterButton(context, unifiedItems),
                  if (!_isSelectionMode && filteredUnifiedItems.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => _showCreatePlaylistDialog(context),
                      icon: const Icon(Icons.add, size: 20),
                      label: Text(context.l10n.collectionCreatePlaylist),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ),
          ),

        if ((filteredGroupedAlbums.isNotEmpty ||
                filteredGroupedLocalAlbums.isNotEmpty) &&
            filterMode == 'albums')
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Text(
                    context.l10n.queueAlbumCount(totalAlbumCount),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  _buildFilterButton(context, unifiedItems),
                ],
              ),
            ),
          ),

        if (filteredGroupedAlbums.isEmpty &&
            filteredGroupedLocalAlbums.isEmpty &&
            filterMode == 'albums' &&
            (historyItems.isNotEmpty || unifiedItems.isNotEmpty))
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  const Spacer(),
                  _buildFilterButton(context, unifiedItems),
                ],
              ),
            ),
          ),

        if (filterMode == 'all' &&
            totalTrackCount == 0 &&
            !showFilteringIndicator &&
            (_activeFilterCount > 0 || unifiedItems.isNotEmpty))
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  const Spacer(),
                  if (!_isSelectionMode)
                    _buildFilterButton(context, unifiedItems),
                ],
              ),
            ),
          ),

        if (filterMode == 'singles' &&
            totalTrackCount == 0 &&
            !showFilteringIndicator &&
            (_activeFilterCount > 0 || unifiedItems.isNotEmpty))
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  const Spacer(),
                  if (!_isSelectionMode)
                    _buildFilterButton(context, unifiedItems),
                ],
              ),
            ),
          ),

        if (showFilteringIndicator)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    context.l10n.queueFilteringIndicator,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),

        if (filterMode == 'all') _buildQueueHeaderSliver(context, colorScheme),

        if (filterMode == 'albums' &&
            (filteredGroupedAlbums.isNotEmpty ||
                filteredGroupedLocalAlbums.isNotEmpty))
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: _AnimatedLibrarySliverGrid(
              maxCrossAxisExtent: _libraryAlbumGridExtent,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.72,
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index < filteredGroupedAlbums.length) {
                    final album = filteredGroupedAlbums[index];
                    return KeyedSubtree(
                      key: ValueKey(album.key),
                      child: _buildAlbumGridItem(context, album, colorScheme),
                    );
                  } else {
                    final localIndex = index - filteredGroupedAlbums.length;
                    final album = filteredGroupedLocalAlbums[localIndex];
                    return KeyedSubtree(
                      key: ValueKey('local_${album.key}'),
                      child: _buildLocalAlbumGridItem(
                        context,
                        album,
                        colorScheme,
                      ),
                    );
                  }
                },
                childCount:
                    filteredGroupedAlbums.length +
                    filteredGroupedLocalAlbums.length,
              ),
            ),
          ),

        if (filterMode == 'all') ...[
          if (historyViewMode == 'grid')
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: _AnimatedLibrarySliverGrid(
                maxCrossAxisExtent: _libraryGridExtent,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.66,
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index < collectionCount) {
                      return _buildAllTabGridCollectionItem(
                        context: context,
                        colorScheme: colorScheme,
                        entry: collectionEntries[index],
                        collectionState: collectionState,
                        filteredUnifiedItems: filteredUnifiedItems,
                      );
                    }
                    final afterCollections = index - collectionCount;
                    if (afterCollections < leadCount) {
                      return leadGridCell(afterCollections);
                    }
                    final trackIndex = afterCollections - leadCount;
                    if (trackIndex < filteredUnifiedItems.length) {
                      final item = filteredUnifiedItems[trackIndex];
                      return KeyedSubtree(
                        key: ValueKey(item.id),
                        child: LongPressDraggable<UnifiedLibraryItem>(
                          data: item,
                          feedback: _buildDragFeedback(
                            context,
                            item,
                            colorScheme,
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.4,
                            child: _buildUnifiedGridItem(
                              context,
                              item,
                              colorScheme,
                              downloadedNavigationItems:
                                  downloadedNavigationItems,
                              downloadedNavigationIndex:
                                  downloadedNavigationIndexByUnifiedId[item.id],
                              localNavigationItems: localNavigationItems,
                              localNavigationIndex:
                                  localNavigationIndexByUnifiedId[item.id],
                              libraryItems: filteredUnifiedItems,
                            ),
                          ),
                          child: _buildUnifiedGridItem(
                            context,
                            item,
                            colorScheme,
                            downloadedNavigationItems:
                                downloadedNavigationItems,
                            downloadedNavigationIndex:
                                downloadedNavigationIndexByUnifiedId[item.id],
                            localNavigationItems: localNavigationItems,
                            localNavigationIndex:
                                localNavigationIndexByUnifiedId[item.id],
                            libraryItems: filteredUnifiedItems,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                  childCount:
                      leadCount + collectionCount + filteredUnifiedItems.length,
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index < collectionCount) {
                    return _buildAllTabListCollectionItem(
                      context: context,
                      colorScheme: colorScheme,
                      entry: collectionEntries[index],
                      collectionState: collectionState,
                      filteredUnifiedItems: filteredUnifiedItems,
                    );
                  }
                  final afterCollections = index - collectionCount;
                  if (afterCollections < leadCount) {
                    return leadListCell(afterCollections);
                  }
                  final trackIndex = afterCollections - leadCount;
                  if (trackIndex < filteredUnifiedItems.length) {
                    final item = filteredUnifiedItems[trackIndex];
                    return KeyedSubtree(
                      key: ValueKey(item.id),
                      child: LongPressDraggable<UnifiedLibraryItem>(
                        data: item,
                        feedback: _buildDragFeedback(
                          context,
                          item,
                          colorScheme,
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.4,
                          child: _buildUnifiedLibraryItem(
                            context,
                            item,
                            colorScheme,
                            downloadedNavigationItems:
                                downloadedNavigationItems,
                            downloadedNavigationIndex:
                                downloadedNavigationIndexByUnifiedId[item.id],
                            localNavigationItems: localNavigationItems,
                            localNavigationIndex:
                                localNavigationIndexByUnifiedId[item.id],
                            libraryItems: filteredUnifiedItems,
                          ),
                        ),
                        child: _buildUnifiedLibraryItem(
                          context,
                          item,
                          colorScheme,
                          downloadedNavigationItems: downloadedNavigationItems,
                          downloadedNavigationIndex:
                              downloadedNavigationIndexByUnifiedId[item.id],
                          localNavigationItems: localNavigationItems,
                          localNavigationIndex:
                              localNavigationIndexByUnifiedId[item.id],
                          libraryItems: filteredUnifiedItems,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
                childCount:
                    leadCount + collectionCount + filteredUnifiedItems.length,
              ),
            ),
        ],

        if (filterMode == 'singles')
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Text(
                    context.l10n.queueTrackCount(totalTrackCount),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (!_isSelectionMode)
                    _buildFilterButton(context, unifiedItems),
                  if (!_isSelectionMode && filteredUnifiedItems.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => _showCreatePlaylistDialog(context),
                      icon: const Icon(Icons.add, size: 20),
                      label: Text(context.l10n.collectionCreatePlaylist),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ),
          ),

        if (filterMode == 'singles')
          _buildQueueHeaderSliver(context, colorScheme),

        if ((filteredUnifiedItems.isNotEmpty || leadCount > 0) &&
            filterMode == 'singles')
          historyViewMode == 'grid'
              ? SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: _AnimatedLibrarySliverGrid(
                    maxCrossAxisExtent: _libraryGridExtent,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.66,
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (index < leadCount) {
                        return leadGridCell(index);
                      }
                      final item = filteredUnifiedItems[index - leadCount];
                      return KeyedSubtree(
                        key: ValueKey(item.id),
                        child: _buildUnifiedGridItem(
                          context,
                          item,
                          colorScheme,
                          downloadedNavigationItems: downloadedNavigationItems,
                          downloadedNavigationIndex:
                              downloadedNavigationIndexByUnifiedId[item.id],
                          localNavigationItems: localNavigationItems,
                          localNavigationIndex:
                              localNavigationIndexByUnifiedId[item.id],
                          libraryItems: filteredUnifiedItems,
                        ),
                      );
                    }, childCount: leadCount + filteredUnifiedItems.length),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    if (index < leadCount) {
                      return leadListCell(index);
                    }
                    final item = filteredUnifiedItems[index - leadCount];
                    return KeyedSubtree(
                      key: ValueKey(item.id),
                      child: _buildUnifiedLibraryItem(
                        context,
                        item,
                        colorScheme,
                        downloadedNavigationItems: downloadedNavigationItems,
                        downloadedNavigationIndex:
                            downloadedNavigationIndexByUnifiedId[item.id],
                        localNavigationItems: localNavigationItems,
                        localNavigationIndex:
                            localNavigationIndexByUnifiedId[item.id],
                        libraryItems: filteredUnifiedItems,
                      ),
                    );
                  }, childCount: leadCount + filteredUnifiedItems.length),
                ),

        if (!hasQueueItems &&
            totalTrackCount == 0 &&
            (filterMode != 'albums' ||
                (filteredGroupedAlbums.isEmpty &&
                    filteredGroupedLocalAlbums.isEmpty)) &&
            !showFilteringIndicator &&
            !isPageLoading)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(context, colorScheme, filterMode),
          )
        else if (isPageLoading)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),

        if (hasQueueItems ||
            totalTrackCount > 0 ||
            (filterMode == 'albums' &&
                (filteredGroupedAlbums.isNotEmpty ||
                    filteredGroupedLocalAlbums.isNotEmpty)))
          SliverToBoxAdapter(
            child: SizedBox(height: _isSelectionMode ? 100 : 16),
          ),
        SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
      ],
    );

    final scrollAwareContent = NotificationListener<ScrollNotification>(
      onNotification: (notification) => _handleLibraryScrollNotification(
        notification: notification,
        filterMode: filterMode,
        hasMoreLibrary: hasMoreLibrary,
        isPageLoading: isPageLoading,
      ),
      child: content,
    );

    if (historyViewMode != 'grid') return scrollAwareContent;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onScaleStart: _handleLibraryGridScaleStart,
      onScaleUpdate: _handleLibraryGridScaleUpdate,
      onScaleEnd: _handleLibraryGridScaleEnd,
      child: scrollAwareContent,
    );
  }

  Future<void> _showClearAllDialog(
    BuildContext context,
    WidgetRef ref,
    ColorScheme colorScheme,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.queueClearAll),
        content: Text(context.l10n.queueClearAllMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.dialogCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
            child: Text(context.l10n.dialogClear),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      ref.read(downloadQueueProvider.notifier).clearAll();
    }
  }

  Widget _buildEmptyState(
    BuildContext context,
    ColorScheme colorScheme,
    String filterMode,
  ) {
    String message;
    String subtitle;
    IconData icon;

    switch (filterMode) {
      case 'albums':
        message = context.l10n.queueEmptyAlbums;
        subtitle = context.l10n.queueEmptyAlbumsSubtitle;
        icon = Icons.album;
        break;
      case 'singles':
        message = context.l10n.queueEmptySingles;
        subtitle = context.l10n.queueEmptySinglesSubtitle;
        icon = Icons.music_note;
        break;
      default:
        message = context.l10n.queueEmptyHistory;
        subtitle = context.l10n.queueEmptyHistorySubtitle;
        icon = Icons.history;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumGridItem(
    BuildContext context,
    _GroupedAlbum album,
    ColorScheme colorScheme,
  ) {
    return ValueListenableBuilder<int>(
      valueListenable: _embeddedCoverVersion,
      builder: (context, _, child) {
        final embeddedCoverPath = _resolveDownloadedEmbeddedCoverPath(
          album.sampleFilePath,
        );
        return _buildAlbumGridItemCore(
          context: context,
          albumName: album.albumName,
          artistName: album.artistName,
          trackCount: album.displayTrackCount,
          colorScheme: colorScheme,
          coverWidget: embeddedCoverPath != null
              ? Image.file(
                  File(embeddedCoverPath),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  cacheWidth: 300,
                  cacheHeight: 300,
                  errorBuilder: (context, error, stackTrace) =>
                      _albumPlaceholder(colorScheme),
                )
              : album.coverUrl != null
              ? CachedCoverImage(
                  imageUrl: album.coverUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  memCacheWidth: 300,
                  memCacheHeight: 300,
                )
              : null,
          badgeColor: colorScheme.primaryContainer,
          badgeTextColor: colorScheme.onPrimaryContainer,
          badgeIcon: Icons.music_note,
          coverUrl: album.coverUrl,
          onTap: () => _navigateToDownloadedAlbum(album),
        );
      },
    );
  }

  Widget _buildLocalAlbumGridItem(
    BuildContext context,
    _GroupedLocalAlbum album,
    ColorScheme colorScheme,
  ) {
    return _buildAlbumGridItemCore(
      context: context,
      albumName: album.albumName,
      artistName: album.artistName,
      trackCount: album.displayTrackCount,
      colorScheme: colorScheme,
      coverWidget: album.coverPath != null
          ? Image.file(
              File(album.coverPath!),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              cacheWidth: 300,
              cacheHeight: 300,
              errorBuilder: (context, error, stackTrace) =>
                  _albumPlaceholder(colorScheme),
            )
          : null,
      badgeColor: colorScheme.tertiaryContainer,
      badgeTextColor: colorScheme.onTertiaryContainer,
      badgeIcon: Icons.folder,
      onTap: () => _navigateToLocalAlbum(album),
    );
  }

  Widget _albumPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.album, color: colorScheme.onSurfaceVariant, size: 48),
      ),
    );
  }

  Widget _buildAlbumGridItemCore({
    required BuildContext context,
    required String albumName,
    required String artistName,
    required int trackCount,
    required ColorScheme colorScheme,
    required Widget? coverWidget,
    required Color badgeColor,
    required Color badgeTextColor,
    required IconData badgeIcon,
    required VoidCallback onTap,
    String? coverUrl,
  }) {
    return Semantics(
      button: true,
      label: context.l10n.a11yOpenAlbumByArtistTrackCount(
        albumName,
        artistName,
        trackCount,
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: coverWidget ?? _albumPlaceholder(colorScheme),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(badgeIcon, size: 12, color: badgeTextColor),
                          const SizedBox(width: 4),
                          Text(
                            '$trackCount',
                            style: TextStyle(
                              color: badgeTextColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              albumName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            ClickableArtistName(
              artistName: artistName,
              coverUrl: coverUrl,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasTextValue(String? value) => value != null && value.trim().isNotEmpty;

  List<UnifiedLibraryItem> _selectedItemsFromAll(
    List<UnifiedLibraryItem> allItems,
  ) {
    final itemsById = {for (final item in allItems) item.id: item};
    return _selectedIds
        .map((id) => itemsById[id])
        .whereType<UnifiedLibraryItem>()
        .toList(growable: false);
  }

  bool _isLocalOnlySelection(List<UnifiedLibraryItem> allItems) {
    final selectedItems = _selectedItemsFromAll(allItems);
    return selectedItems.isNotEmpty &&
        selectedItems.every((item) => item.localItem != null);
  }

}
