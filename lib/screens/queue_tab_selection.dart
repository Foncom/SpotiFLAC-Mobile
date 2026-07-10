part of 'queue_tab.dart';

extension _QueueTabSelectionActions on _QueueTabState {
  void _enterSelectionMode(String itemId) {
    HapticFeedback.mediumImpact();
    _setState(() {
      _isPlaylistSelectionMode = false;
      _selectedPlaylistIds.clear();
      _isSelectionMode = true;
      _selectedIds.add(itemId);
    });
    _hidePlaylistSelectionOverlay();
  }

  void _exitSelectionMode() {
    _setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
    _hideSelectionOverlay();
  }

  void _toggleSelection(String itemId) {
    var shouldHideOverlay = false;
    _setState(() {
      if (_selectedIds.contains(itemId)) {
        _selectedIds.remove(itemId);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
          shouldHideOverlay = true;
        }
      } else {
        _selectedIds.add(itemId);
      }
    });
    if (shouldHideOverlay) {
      _hideSelectionOverlay();
    }
  }

  void _selectAll(List<UnifiedLibraryItem> items) {
    _setState(() {
      _selectedIds.addAll(items.map((e) => e.id));
    });
  }

  void _hideSelectionOverlay() {
    _selectionOverlayEntry?.remove();
    _selectionOverlayEntry = null;
  }

  void _syncSelectionOverlay({
    required List<UnifiedLibraryItem> items,
    required double bottomPadding,
  }) {
    if (!mounted) return;
    if (_suppressSelectionOverlay ||
        !_isSelectionMode ||
        _isPlaylistSelectionMode) {
      _hideSelectionOverlay();
      return;
    }

    _selectionOverlayItems = items;
    _selectionOverlayBottomPadding = bottomPadding;

    if (_selectionOverlayEntry != null) {
      _selectionOverlayEntry!.markNeedsBuild();
      return;
    }

    final overlay = Overlay.of(context, rootOverlay: true);
    _selectionOverlayEntry = OverlayEntry(
      builder: (overlayContext) {
        final colorScheme = Theme.of(context).colorScheme;
        return Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _AnimatedOverlayBottomBar(
            child: Material(
              color: Colors.transparent,
              child: _buildSelectionBottomBar(
                context,
                colorScheme,
                _selectionOverlayItems,
                _selectionOverlayBottomPadding,
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_selectionOverlayEntry!);
  }

  void _hidePlaylistSelectionOverlay() {
    _playlistSelectionOverlayEntry?.remove();
    _playlistSelectionOverlayEntry = null;
  }

  void _syncPlaylistSelectionOverlay({
    required List<UserPlaylistCollection> playlists,
    required double bottomPadding,
  }) {
    if (!mounted) return;
    if (_suppressSelectionOverlay ||
        !_isPlaylistSelectionMode ||
        _isSelectionMode) {
      _hidePlaylistSelectionOverlay();
      return;
    }

    _playlistSelectionOverlayItems = playlists;
    _playlistSelectionOverlayBottomPadding = bottomPadding;

    if (_playlistSelectionOverlayEntry != null) {
      _playlistSelectionOverlayEntry!.markNeedsBuild();
      return;
    }

    final overlay = Overlay.of(context, rootOverlay: true);
    _playlistSelectionOverlayEntry = OverlayEntry(
      builder: (overlayContext) {
        final colorScheme = Theme.of(context).colorScheme;
        return Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _AnimatedOverlayBottomBar(
            child: Material(
              color: Colors.transparent,
              child: _buildPlaylistSelectionBottomBar(
                context,
                colorScheme,
                _playlistSelectionOverlayItems,
                _playlistSelectionOverlayBottomPadding,
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_playlistSelectionOverlayEntry!);
  }

  void _enterPlaylistSelectionMode(String playlistId) {
    HapticFeedback.mediumImpact();
    _setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
      _isPlaylistSelectionMode = true;
      _selectedPlaylistIds.add(playlistId);
    });
    _hideSelectionOverlay();
  }

  void _exitPlaylistSelectionMode() {
    _setState(() {
      _isPlaylistSelectionMode = false;
      _selectedPlaylistIds.clear();
    });
    _hidePlaylistSelectionOverlay();
  }

  void _togglePlaylistSelection(String playlistId) {
    var shouldHideOverlay = false;
    _setState(() {
      if (_selectedPlaylistIds.contains(playlistId)) {
        _selectedPlaylistIds.remove(playlistId);
        if (_selectedPlaylistIds.isEmpty) {
          _isPlaylistSelectionMode = false;
          shouldHideOverlay = true;
        }
      } else {
        _selectedPlaylistIds.add(playlistId);
      }
    });
    if (shouldHideOverlay) {
      _hidePlaylistSelectionOverlay();
    }
  }

  void _selectAllPlaylists(List<UserPlaylistCollection> playlists) {
    _setState(() {
      _selectedPlaylistIds.addAll(playlists.map((e) => e.id));
    });
  }

  Future<void> _downloadAllSelectedPlaylists(BuildContext context) async {
    final collectionsState = ref.read(libraryCollectionsProvider);
    final selectedPlaylists = collectionsState.playlists
        .where((p) => _selectedPlaylistIds.contains(p.id))
        .toList();

    final totalTracks = selectedPlaylists.fold<int>(
      0,
      (sum, p) => sum + p.tracks.length,
    );

    if (totalTracks == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.snackbarSelectedPlaylistsEmpty)),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.dialogDownloadAllTitle),
        content: Text(
          ctx.l10n.dialogDownloadPlaylistsMessage(
            totalTracks,
            selectedPlaylists.length,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.dialogCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.dialogDownload),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final settings = ref.read(settingsProvider);
    final extensionState = ref.read(extensionProvider);
    final queueNotifier = ref.read(downloadQueueProvider.notifier);

    void enqueueAll({String? qualityOverride, String? service}) {
      final svc =
          service ??
          resolveEffectiveDownloadService(
            settings.defaultService,
            extensionState,
          );
      if (svc.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.extensionsNoDownloadProvider)),
          );
        }
        return;
      }
      for (final playlist in selectedPlaylists) {
        final tracks = playlist.tracks.map((e) => e.track).toList();
        queueNotifier.addMultipleToQueue(
          tracks,
          svc,
          qualityOverride: qualityOverride,
          playlistName: playlist.name,
        );
      }
    }

    if (settings.askQualityBeforeDownload) {
      DownloadServicePicker.show(
        context,
        trackName: context.l10n.tracksCount(totalTracks),
        artistName: context.l10n.playlistsCount(selectedPlaylists.length),
        onSelect: (quality, service) {
          enqueueAll(qualityOverride: quality, service: service);
          if (!mounted) return;
          _exitPlaylistSelectionMode();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.snackbarAddedTracksToQueue(totalTracks),
              ),
            ),
          );
        },
      );
    } else {
      enqueueAll();
      _exitPlaylistSelectionMode();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.snackbarAddedTracksToQueue(totalTracks)),
        ),
      );
    }
  }

  Future<void> _deleteSelectedPlaylists(BuildContext context) async {
    final count = _selectedPlaylistIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.collectionDeletePlaylist),
        content: Text(ctx.l10n.collectionDeletePlaylistsMessage(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.dialogCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(ctx.l10n.dialogDelete),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final notifier = ref.read(libraryCollectionsProvider.notifier);
    for (final id in _selectedPlaylistIds.toList()) {
      await notifier.deletePlaylist(id);
    }

    if (!context.mounted) return;
    _exitPlaylistSelectionMode();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.collectionPlaylistsDeleted(count))),
    );
  }

  Widget _buildPlaylistSelectionBottomBar(
    BuildContext context,
    ColorScheme colorScheme,
    List<UserPlaylistCollection> playlists,
    double bottomPadding,
  ) {
    final selectedCount = _selectedPlaylistIds.length;
    final allSelected =
        selectedCount == playlists.length && playlists.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding > 0 ? 8 : 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: _exitPlaylistSelectionMode,
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.selectionSelected(selectedCount),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          allSelected
                              ? context.l10n.selectionAllPlaylistsSelected
                              : context.l10n.selectionTapPlaylistsToSelect,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),

                  TextButton.icon(
                    onPressed: () {
                      if (allSelected) {
                        _exitPlaylistSelectionMode();
                      } else {
                        _selectAllPlaylists(playlists);
                      }
                    },
                    icon: Icon(
                      allSelected ? Icons.deselect : Icons.select_all,
                      size: 20,
                    ),
                    label: Text(
                      allSelected
                          ? context.l10n.actionDeselect
                          : context.l10n.actionSelectAll,
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.primary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: selectedCount > 0
                      ? () => _downloadAllSelectedPlaylists(context)
                      : null,
                  icon: const Icon(Icons.download_rounded),
                  label: Text(
                    selectedCount > 0
                        ? context.l10n.bulkDownloadPlaylistsButton(
                            selectedCount,
                          )
                        : context.l10n.bulkDownloadSelectPlaylists,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: selectedCount > 0
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHighest,
                    foregroundColor: selectedCount > 0
                        ? colorScheme.onPrimary
                        : colorScheme.onSurfaceVariant,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: selectedCount > 0
                      ? () => _deleteSelectedPlaylists(context)
                      : null,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(
                    selectedCount > 0
                        ? context.l10n.selectionDeletePlaylistsCount(
                            selectedCount,
                          )
                        : context.l10n.selectionSelectPlaylistsToDelete,
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
          ),
        ),
      ),
    );
  }

  String _getQualityBadgeText(String quality) {
    final q = quality.trim().toLowerCase();
    if (q.contains('bit')) {
      return quality.split('/').first;
    }

    final bitrateTextMatch = RegExp(
      r'(\d+)\s*k(?:bps)?',
      caseSensitive: false,
    ).firstMatch(quality);
    if (bitrateTextMatch != null) {
      return '${bitrateTextMatch.group(1)}k';
    }

    final bitrateIdMatch = RegExp(r'_(\d+)$').firstMatch(q);
    if (bitrateIdMatch != null) {
      return '${bitrateIdMatch.group(1)}k';
    }

    return quality.split(' ').first;
  }

  Future<void> _deleteSelected(List<UnifiedLibraryItem> allItems) async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.dialogDeleteSelectedTitle),
        content: Text(context.l10n.dialogDeleteSelectedMessage(count)),
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
      final localLibraryDb = LibraryDatabase.instance;
      final itemsById = {for (final item in allItems) item.id: item};

      int deletedCount = 0;
      for (final id in _selectedIds) {
        final item = itemsById[id];
        if (item != null) {
          try {
            final cleanPath = _cleanFilePath(item.filePath);
            await deleteFile(cleanPath);
          } catch (_) {}

          if (item.source == LibraryItemSource.downloaded) {
            historyNotifier.removeFromHistory(item.historyItem!.id);
          } else {
            await localLibraryDb.deleteByPath(item.filePath);
          }
          deletedCount++;
        }
      }

      if (allItems.any(
        (i) =>
            _selectedIds.contains(i.id) && i.source == LibraryItemSource.local,
      )) {
        ref.read(localLibraryProvider.notifier).reloadFromStorage();
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

  String _cleanFilePath(String? filePath) {
    return DownloadedEmbeddedCoverResolver.cleanFilePath(filePath);
  }

  Future<int?> _readFileModTimeMillis(String? filePath) async {
    return DownloadedEmbeddedCoverResolver.readFileModTimeMillis(filePath);
  }

}
