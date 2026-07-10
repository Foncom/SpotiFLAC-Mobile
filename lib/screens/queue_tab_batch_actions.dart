part of 'queue_tab.dart';

extension _QueueTabBatchActions on _QueueTabState {
  Future<void> _safeDeleteTempFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<void> _cleanupTempFileAndParentDir(String path) async {
    await _safeDeleteTempFile(path);
    try {
      final parent = File(path).parent;
      if (await parent.exists()) {
        await parent.delete();
      }
    } catch (_) {}
  }

  Future<bool> _applyQueueFfmpegReEnrichResult(
    LocalLibraryItem item,
    Map<String, dynamic> result,
  ) async {
    final tempPath = result['temp_path'] as String?;
    final safUri = result['saf_uri'] as String?;
    final ffmpegTarget = _hasTextValue(tempPath) ? tempPath! : item.filePath;
    final downloadedCoverPath = result['cover_path'] as String?;
    String? effectiveCoverPath = downloadedCoverPath;
    String? extractedCoverPath;

    if (!_hasTextValue(effectiveCoverPath)) {
      try {
        final tempDir = await Directory.systemTemp.createTemp(
          'reenrich_cover_',
        );
        final coverOutput = '${tempDir.path}${Platform.pathSeparator}cover.jpg';
        final extracted = await PlatformBridge.extractCoverToFile(
          ffmpegTarget,
          coverOutput,
        );
        if (extracted['error'] == null) {
          effectiveCoverPath = coverOutput;
          extractedCoverPath = coverOutput;
        } else {
          try {
            await tempDir.delete(recursive: true);
          } catch (_) {}
        }
      } catch (_) {}
    }

    final metadata = (result['metadata'] as Map<String, dynamic>?)?.map(
      (k, v) => MapEntry(k, v.toString()),
    );

    final format = item.format?.toLowerCase();
    final lowerPath = item.filePath.toLowerCase();
    final isMp3 = format == 'mp3' || lowerPath.endsWith('.mp3');
    final isM4A =
        format == 'm4a' ||
        format == 'aac' ||
        lowerPath.endsWith('.m4a') ||
        lowerPath.endsWith('.aac');
    final isOpus =
        format == 'opus' ||
        format == 'ogg' ||
        lowerPath.endsWith('.opus') ||
        lowerPath.endsWith('.ogg');

    final artistTagMode = ref.read(settingsProvider).artistTagMode;
    String? ffmpegResult;
    if (isMp3) {
      ffmpegResult = await FFmpegService.embedMetadataToMp3(
        mp3Path: ffmpegTarget,
        coverPath: effectiveCoverPath,
        metadata: metadata,
        preserveMetadata: true,
      );
    } else if (isM4A) {
      ffmpegResult = await FFmpegService.embedMetadataToM4a(
        m4aPath: ffmpegTarget,
        coverPath: effectiveCoverPath,
        metadata: metadata,
        preserveMetadata: true,
      );
    } else if (isOpus) {
      ffmpegResult = await FFmpegService.embedMetadataToOpus(
        opusPath: ffmpegTarget,
        coverPath: effectiveCoverPath,
        metadata: metadata,
        artistTagMode: artistTagMode,
        preserveMetadata: true,
      );
    }

    if (ffmpegResult != null &&
        _hasTextValue(tempPath) &&
        _hasTextValue(safUri)) {
      final ok = await PlatformBridge.writeTempToSaf(ffmpegResult, safUri!);
      if (!ok) {
        if (_hasTextValue(downloadedCoverPath)) {
          await _safeDeleteTempFile(downloadedCoverPath!);
        }
        if (_hasTextValue(extractedCoverPath)) {
          await _cleanupTempFileAndParentDir(extractedCoverPath!);
        }
        await _safeDeleteTempFile(tempPath!);
        return false;
      }
      await writeReEnrichSafSidecarLrc(safUri: safUri, reEnrichResult: result);
    }

    if (_hasTextValue(downloadedCoverPath)) {
      await _safeDeleteTempFile(downloadedCoverPath!);
    }
    if (_hasTextValue(extractedCoverPath)) {
      await _cleanupTempFileAndParentDir(extractedCoverPath!);
    }
    if (_hasTextValue(tempPath)) {
      await _safeDeleteTempFile(tempPath!);
    }

    if (ffmpegResult != null) {
      // Filesystem .lrc sidecar. SAF sidecar is written only after
      // writeTempToSaf succeeds.
      await writeReEnrichSidecarLrc(
        audioFilePath: item.filePath,
        reEnrichResult: result,
      );
    }

    return ffmpegResult != null;
  }

  Future<bool> _reEnrichQueueLocalTrack(
    LocalLibraryItem item, {
    List<String>? updateFields,
  }) async {
    final durationMs = (item.duration ?? 0) * 1000;
    final settings = ref.read(settingsProvider);
    final artistTagMode = settings.artistTagMode;
    await ref.read(settingsProvider.notifier).syncLyricsSettingsToBackend();
    final request = <String, dynamic>{
      'file_path': item.filePath,
      'cover_url': '',
      'max_quality': true,
      'embed_lyrics': settings.embedLyrics,
      'lyrics_mode': settings.lyricsMode,
      'artist_tag_mode': artistTagMode,
      'spotify_id': '',
      'track_name': item.trackName,
      'artist_name': item.artistName,
      'album_name': item.albumName,
      'album_artist': item.albumArtist ?? '',
      'track_number': item.trackNumber ?? 0,
      'disc_number': item.discNumber ?? 0,
      'release_date': item.releaseDate ?? '',
      'isrc': item.isrc ?? '',
      'genre': item.genre ?? '',
      'label': '',
      'copyright': '',
      'duration_ms': durationMs,
      'search_online': true,
      // ignore: use_null_aware_elements
      if (updateFields != null) 'update_fields': updateFields,
    };

    final result = await PlatformBridge.reEnrichFile(request);
    final method = result['method'] as String?;
    if (method == 'native') {
      // Filesystem .lrc sidecar (SAF sidecar handled natively in Kotlin).
      await writeReEnrichSidecarLrc(
        audioFilePath: item.filePath,
        reEnrichResult: result,
      );
      return true;
    }
    if (method == 'ffmpeg') {
      return _applyQueueFfmpegReEnrichResult(item, result);
    }
    return false;
  }

  List<LocalLibraryItem> _selectedFlacEligibleLocalItems(
    List<UnifiedLibraryItem> allItems,
  ) {
    final selectedItems = _selectedItemsFromAll(allItems);
    return selectedItems
        .map((item) => item.localItem)
        .whereType<LocalLibraryItem>()
        .where(LocalTrackRedownloadService.isFlacUpgradeEligible)
        .toList(growable: false);
  }

  Future<void> _queueSelectedLocalAsFlac(
    List<UnifiedLibraryItem> allItems,
  ) async {
    final selectedLocalItems = _selectedFlacEligibleLocalItems(allItems);

    if (selectedLocalItems.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.queueFlacAction),
        content: Text(
          context.l10n.queueFlacConfirmMessage(selectedLocalItems.length),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.dialogCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.queueFlacAction),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final settings = ref.read(settingsProvider);
    final extensionState = ref.read(extensionProvider);
    final includeExtensions =
        settings.useExtensionProviders &&
        extensionState.extensions.any(
          (ext) => ext.enabled && ext.hasMetadataProvider,
        );
    final targetService = LocalTrackRedownloadService.preferredFlacService(
      settings,
      extensionState,
    );
    if (targetService.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.extensionsNoDownloadProvider)),
      );
      return;
    }
    final targetQuality =
        LocalTrackRedownloadService.preferredFlacQualityForService(
          targetService,
          extensionState,
        );

    final matchedTracks = <Track>[];
    var skippedCount = 0;
    final total = selectedLocalItems.length;

    var cancelled = false;
    BatchProgressDialog.show(
      context: context,
      title: context.l10n.queueFlacAction,
      total: total,
      icon: Icons.queue_music,
      onCancel: () {
        cancelled = true;
        BatchProgressDialog.dismiss(context);
      },
    );

    for (var i = 0; i < total; i++) {
      if (!mounted || cancelled) break;

      BatchProgressDialog.update(
        current: i + 1,
        detail: selectedLocalItems[i].trackName,
      );

      try {
        final resolution = await LocalTrackRedownloadService.resolveBestMatch(
          selectedLocalItems[i],
          includeExtensions: includeExtensions,
        );
        if (resolution.canQueue && resolution.match != null) {
          matchedTracks.add(resolution.match!);
        } else {
          skippedCount++;
        }
      } catch (_) {
        skippedCount++;
      }
    }

    if (!mounted) {
      return;
    }

    if (!cancelled) {
      BatchProgressDialog.dismiss(context);
    }

    if (matchedTracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.queueFlacNoReliableMatches)),
      );
      return;
    }

    ref
        .read(downloadQueueProvider.notifier)
        .addMultipleToQueue(
          matchedTracks,
          targetService,
          qualityOverride: targetQuality,
        );

    final summary = skippedCount == 0
        ? context.l10n.snackbarAddedTracksToQueue(matchedTracks.length)
        : context.l10n.queueFlacQueuedWithSkipped(
            matchedTracks.length,
            skippedCount,
          );

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(summary)));
    _setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _reEnrichSelectedLocalFromQueue(
    List<UnifiedLibraryItem> allItems,
  ) async {
    final selectedItems = _selectedItemsFromAll(allItems);
    final selectedLocalItems = selectedItems
        .map((item) => item.localItem)
        .whereType<LocalLibraryItem>()
        .toList(growable: false);

    if (selectedLocalItems.isEmpty) {
      return;
    }

    // Hide the selection overlay: set the flag (prevents build() from
    // re-inserting via postFrameCallback) and remove the entry immediately.
    _setState(() => _isSelectionMode = false);
    _hideSelectionOverlay();

    final selection = await showReEnrichFieldDialog(
      context,
      selectedCount: selectedLocalItems.length,
    );

    if (selection == null || !mounted) {
      // Cancelled — restore selection mode; the next build cycle will
      // re-create the overlay via _syncSelectionOverlay in postFrameCallback.
      if (mounted) _setState(() => _isSelectionMode = true);
      return;
    }

    final updateFields = selection.isAll ? null : selection.fields;

    var successCount = 0;
    final total = selectedLocalItems.length;

    var cancelled = false;
    BatchProgressDialog.show(
      context: context,
      title: context.l10n.trackReEnrichProgress,
      total: total,
      icon: Icons.auto_fix_high,
      onCancel: () {
        cancelled = true;
        BatchProgressDialog.dismiss(context);
      },
    );

    for (var i = 0; i < total; i++) {
      if (!mounted || cancelled) break;
      final item = selectedLocalItems[i];

      BatchProgressDialog.update(
        current: i + 1,
        detail: '${item.trackName} - ${item.artistName}',
      );

      try {
        final ok = await _reEnrichQueueLocalTrack(
          item,
          updateFields: updateFields,
        );
        if (ok) {
          successCount++;
        }
      } catch (_) {}
    }

    if (!mounted) {
      return;
    }

    final settings = ref.read(settingsProvider);
    final localLibraryPath = settings.localLibraryPath.trim();
    final iosBookmark = settings.localLibraryBookmark;
    try {
      if (localLibraryPath.isNotEmpty &&
          !ref.read(localLibraryProvider).isScanning) {
        await ref
            .read(localLibraryProvider.notifier)
            .startScan(
              localLibraryPath,
              iosBookmark: iosBookmark.isNotEmpty ? iosBookmark : null,
            );
      } else {
        await ref.read(localLibraryProvider.notifier).reloadFromStorage();
      }
    } catch (_) {
      await ref.read(localLibraryProvider.notifier).reloadFromStorage();
    }

    _exitSelectionMode();

    if (!mounted) {
      return;
    }

    if (!cancelled) {
      BatchProgressDialog.dismiss(context);
    }
    ScaffoldMessenger.of(context).clearSnackBars();
    final failedCount = total - successCount;
    final summary = failedCount <= 0
        ? '${context.l10n.trackReEnrichSuccess} ($successCount/$total)'
        : context.l10n.trackReEnrichSuccessWithFailures(
            successCount,
            total,
            failedCount,
          );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(summary)));
  }

  /// Share selected tracks via system share sheet
  Future<void> _shareSelected(List<UnifiedLibraryItem> allItems) async {
    final itemsById = {for (final item in allItems) item.id: item};
    final safUris = <String>[];
    final filesToShare = <XFile>[];

    for (final id in _selectedIds) {
      final item = itemsById[id];
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

  Future<void> _showBatchConvertSheet(
    BuildContext context,
    List<UnifiedLibraryItem> allItems,
  ) async {
    final itemsById = {for (final item in allItems) item.id: item};
    final sourceFormats = <String>{};
    final sourceBitDepths = <int?>[];
    final sourceSampleRates = <int?>[];
    for (final id in _selectedIds) {
      final item = itemsById[id];
      if (item == null) continue;
      final sourceFormat = convertibleAudioSourceFormat(
        storedFormat: item.localItem?.format ?? item.historyItem?.format,
        filePath: item.filePath,
        fileName: item.historyItem?.safFileName,
      );
      if (sourceFormat != null) sourceFormats.add(sourceFormat);
      sourceBitDepths.add(
        item.historyItem?.bitDepth ?? item.localItem?.bitDepth,
      );
      sourceSampleRates.add(
        item.historyItem?.sampleRate ?? item.localItem?.sampleRate,
      );
    }

    final formats = audioConversionTargetFormats
        .where(
          (target) => sourceFormats.any(
            (source) => canConvertAudioFormat(
              sourceFormat: source,
              targetFormat: target,
            ),
          ),
        )
        .toList();

    if (formats.isEmpty) return;

    var didStartConversion = false;

    // Resolve localized strings up front; the builder must not look up
    // Localizations via the (possibly deactivated) State context.
    final sheetTitle = context.l10n.selectionBatchConvertConfirmTitle;
    final sheetConfirmLabel = context.l10n.selectionConvertCount(
      _selectedIds.length,
    );

    _suppressSelectionOverlay = true;
    _hideSelectionOverlay();
    _hidePlaylistSelectionOverlay();

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => BatchConvertSheet(
        formats: formats,
        title: sheetTitle,
        confirmLabel: sheetConfirmLabel,
        sourceBitDepth: lowestKnownPositiveInt(sourceBitDepths),
        sourceSampleRate: lowestKnownPositiveInt(sourceSampleRates),
        onConvert: (format, bitrate, losslessQuality, losslessProcessing) {
          didStartConversion = true;
          Navigator.pop(sheetContext);
          _performBatchConversion(
            allItems: allItems,
            targetFormat: format,
            bitrate: bitrate,
            losslessQuality: losslessQuality,
            losslessProcessing: losslessProcessing,
          );
        },
      ),
    );

    // Wait out the sheet's exit animation before restoring the toolbar so it
    // doesn't pop in front of the still-closing sheet.
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted) {
      _suppressSelectionOverlay = false;
      return;
    }
    _suppressSelectionOverlay = false;
    if (didStartConversion) return;
    if (_isSelectionMode) {
      _syncSelectionOverlay(
        items: allItems,
        bottomPadding: MediaQuery.of(this.context).padding.bottom,
      );
    } else if (_isPlaylistSelectionMode) {
      _syncPlaylistSelectionOverlay(
        playlists: ref.read(libraryCollectionsProvider).playlists,
        bottomPadding: MediaQuery.of(this.context).padding.bottom,
      );
    }
  }

  /// Perform batch conversion on selected tracks
  Future<void> _performBatchConversion({
    required List<UnifiedLibraryItem> allItems,
    required String targetFormat,
    required String bitrate,
    LosslessConversionQuality losslessQuality =
        const LosslessConversionQuality(),
    LosslessConversionProcessing losslessProcessing =
        const LosslessConversionProcessing(),
  }) async {
    final itemsById = {for (final item in allItems) item.id: item};
    final selectedItems = <UnifiedLibraryItem>[];
    for (final id in _selectedIds) {
      final item = itemsById[id];
      if (item == null) continue;
      final sourceFormat = convertibleAudioSourceFormat(
        storedFormat: item.localItem?.format ?? item.historyItem?.format,
        filePath: item.filePath,
        fileName: item.historyItem?.safFileName,
      );
      if (sourceFormat == null ||
          !canConvertAudioFormat(
            sourceFormat: sourceFormat,
            targetFormat: targetFormat,
          )) {
        continue;
      }
      selectedItems.add(item);
    }

    if (selectedItems.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.selectionConvertNoConvertible)),
        );
      }
      return;
    }

    final isLossless = isLosslessConversionTarget(targetFormat);
    final losslessLabels = context.l10n.losslessConversionLabels;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.selectionBatchConvertConfirmTitle),
        content: Text(
          isLossless && losslessQuality.hasCaps
              ? context.l10n.selectionBatchConvertConfirmMessageLosslessCapped(
                  selectedItems.length,
                  targetFormat,
                  losslessQualityLabel(
                    losslessQuality,
                    originalLabel: losslessLabels.original,
                    originalQualityLabel: losslessLabels.originalQuality,
                  ),
                )
              : isLossless
              ? context.l10n.selectionBatchConvertConfirmMessageLossless(
                  selectedItems.length,
                  targetFormat,
                )
              : context.l10n.selectionBatchConvertConfirmMessage(
                  selectedItems.length,
                  targetFormat,
                  bitrate,
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.dialogCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.trackConvertFormat),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    int successCount = 0;
    final total = selectedItems.length;
    final historyDb = HistoryDatabase.instance;
    final settings = ref.read(settingsProvider);
    final shouldEmbedLyrics =
        settings.embedLyrics && settings.lyricsMode != 'external';

    var cancelled = false;
    BatchProgressDialog.show(
      context: context,
      title: context.l10n.trackConvertConverting,
      total: total,
      icon: Icons.transform,
      onCancel: () {
        cancelled = true;
        BatchProgressDialog.dismiss(context);
      },
    );

    for (int i = 0; i < total; i++) {
      if (!mounted || cancelled) break;
      final item = selectedItems[i];

      BatchProgressDialog.update(current: i + 1, detail: item.trackName);

      try {
        final metadata = <String, String>{
          'TITLE': item.trackName,
          'ARTIST': item.artistName,
          'ALBUM': item.albumName,
        };
        try {
          final result = await PlatformBridge.readFileMetadata(item.filePath);
          if (result['error'] == null) {
            mergePlatformMetadataForTagEmbed(target: metadata, source: result);
          }
        } catch (_) {}
        await ensureLyricsMetadataForConversion(
          metadata: metadata,
          sourcePath: item.filePath,
          shouldEmbedLyrics: shouldEmbedLyrics,
          trackName: item.trackName,
          artistName: item.artistName,
          spotifyId: item.historyItem?.spotifyId ?? '',
          durationMs:
              ((item.historyItem?.duration ?? item.localItem?.duration) ?? 0) *
              1000,
        );

        String? coverPath;
        try {
          final tempDir = await getTemporaryDirectory();
          final coverOutput =
              '${tempDir.path}${Platform.pathSeparator}batch_cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final coverResult = await PlatformBridge.extractCoverToFile(
            item.filePath,
            coverOutput,
          );
          if (coverResult['error'] == null) {
            coverPath = coverOutput;
          }
        } catch (_) {}

        String workingPath = item.filePath;
        final isSaf = isContentUri(item.filePath);
        String? safTempPath;

        if (isSaf) {
          safTempPath = await PlatformBridge.copyContentUriToTemp(
            item.filePath,
          );
          if (safTempPath == null) continue;
          workingPath = safTempPath;
        }

        final newPath = await FFmpegService.convertAudioFormat(
          inputPath: workingPath,
          targetFormat: targetFormat.toLowerCase(),
          bitrate: bitrate,
          metadata: metadata,
          coverPath: coverPath,
          artistTagMode: settings.artistTagMode,
          deleteOriginal: !isSaf,
          sourceBitDepth:
              item.historyItem?.bitDepth ?? item.localItem?.bitDepth,
          losslessQuality: losslessQuality,
          losslessProcessing: losslessProcessing,
        );

        if (coverPath != null) {
          try {
            await File(coverPath).delete();
          } catch (_) {}
        }

        if (newPath == null) {
          if (safTempPath != null) {
            try {
              await File(safTempPath).delete();
            } catch (_) {}
          }
          continue;
        }

        final sourceBitDepth =
            item.historyItem?.bitDepth ?? item.localItem?.bitDepth;
        final sourceSampleRate =
            item.historyItem?.sampleRate ?? item.localItem?.sampleRate;
        final isLosslessOutput = isLosslessConversionTarget(targetFormat);
        int? convertedBitDepth;
        int? convertedSampleRate;
        if (isLosslessOutput) {
          try {
            final convertedMetadata = await PlatformBridge.readFileMetadata(
              newPath,
            );
            if (convertedMetadata['error'] == null) {
              convertedBitDepth = readPositiveAudioInt(
                convertedMetadata['bit_depth'],
              );
              convertedSampleRate = readPositiveAudioInt(
                convertedMetadata['sample_rate'],
              );
            }
          } catch (_) {}
          convertedBitDepth ??= losslessQuality.effectiveBitDepth(
            sourceBitDepth,
          );
          convertedSampleRate ??= losslessQuality.effectiveSampleRate(
            sourceSampleRate,
          );
        }
        final newQuality = convertedAudioQualityLabel(
          targetFormat: targetFormat,
          bitrate: bitrate,
          labels: losslessLabels,
          losslessQuality: losslessQuality,
          actualBitDepth: convertedBitDepth,
          actualSampleRate: convertedSampleRate,
        );

        if (isSaf && item.historyItem != null) {
          final hi = item.historyItem!;
          final treeUri = hi.downloadTreeUri;
          final relativeDir = hi.safRelativeDir ?? '';
          if (treeUri != null && treeUri.isNotEmpty) {
            final oldFileName = hi.safFileName ?? '';
            final dotIdx = oldFileName.lastIndexOf('.');
            final baseName = dotIdx > 0
                ? oldFileName.substring(0, dotIdx)
                : oldFileName;
            final convTarget = convertTargetExtAndMime(targetFormat);
            final newExt = convTarget.ext;
            final mimeType = convTarget.mime;
            final newFileName = '$baseName$newExt';

            final safUri = await PlatformBridge.createSafFileFromPath(
              treeUri: treeUri,
              relativeDir: relativeDir,
              fileName: newFileName,
              mimeType: mimeType,
              srcPath: newPath,
            );

            if (safUri == null || safUri.isEmpty) {
              try {
                await File(newPath).delete();
              } catch (_) {}
              if (safTempPath != null) {
                try {
                  await File(safTempPath).delete();
                } catch (_) {}
              }
              continue;
            }

            if (!isSameContentUri(item.filePath, safUri)) {
              try {
                await PlatformBridge.safDelete(item.filePath);
              } catch (_) {}
            }

            await historyDb.updateFilePath(
              hi.id,
              safUri,
              newSafFileName: newFileName,
              newQuality: newQuality,
              newFormat: normalizedConvertedAudioFormat(targetFormat),
              newBitrate: convertedAudioBitrateKbps(
                targetFormat: targetFormat,
                bitrate: bitrate,
              ),
              newBitDepth: convertedBitDepth,
              newSampleRate: convertedSampleRate,
              clearAudioSpecs: !isLosslessOutput,
            );
          }
          try {
            await File(newPath).delete();
          } catch (_) {}
          if (safTempPath != null) {
            try {
              await File(safTempPath).delete();
            } catch (_) {}
          }
        } else if (isSaf && item.localItem != null) {
          final uri = Uri.parse(item.filePath);
          final pathSegments = uri.pathSegments;

          String? treeUri;
          String relativeDir = '';
          String oldFileName = '';

          final treeIdx = pathSegments.indexOf('tree');
          final docIdx = pathSegments.indexOf('document');
          if (treeIdx >= 0 && treeIdx + 1 < pathSegments.length) {
            final treeId = pathSegments[treeIdx + 1];
            treeUri =
                'content://${uri.authority}/tree/${Uri.encodeComponent(treeId)}';
          }
          if (docIdx >= 0 && docIdx + 1 < pathSegments.length) {
            final docPath = Uri.decodeFull(pathSegments[docIdx + 1]);
            final slashIdx = docPath.lastIndexOf('/');
            if (slashIdx >= 0) {
              oldFileName = docPath.substring(slashIdx + 1);
              final treeId = treeIdx >= 0 && treeIdx + 1 < pathSegments.length
                  ? Uri.decodeFull(pathSegments[treeIdx + 1])
                  : '';
              if (treeId.isNotEmpty && docPath.startsWith(treeId)) {
                final afterTree = docPath.substring(treeId.length);
                final trimmed = afterTree.startsWith('/')
                    ? afterTree.substring(1)
                    : afterTree;
                final lastSlash = trimmed.lastIndexOf('/');
                relativeDir = lastSlash >= 0
                    ? trimmed.substring(0, lastSlash)
                    : '';
              }
            } else {
              oldFileName = docPath;
            }
          }

          if (treeUri != null && oldFileName.isNotEmpty) {
            final dotIdx = oldFileName.lastIndexOf('.');
            final baseName = dotIdx > 0
                ? oldFileName.substring(0, dotIdx)
                : oldFileName;
            final convTarget = convertTargetExtAndMime(targetFormat);
            final newExt = convTarget.ext;
            final mimeType = convTarget.mime;
            final newFileName = '$baseName$newExt';

            final safUri = await PlatformBridge.createSafFileFromPath(
              treeUri: treeUri,
              relativeDir: relativeDir,
              fileName: newFileName,
              mimeType: mimeType,
              srcPath: newPath,
            );

            if (safUri == null || safUri.isEmpty) {
              try {
                await File(newPath).delete();
              } catch (_) {}
              if (safTempPath != null) {
                try {
                  await File(safTempPath).delete();
                } catch (_) {}
              }
              continue;
            }

            if (!isSameContentUri(item.filePath, safUri)) {
              try {
                await PlatformBridge.safDelete(item.filePath);
              } catch (_) {}
            }
            await LibraryDatabase.instance.replaceWithConvertedItem(
              item: item.localItem!,
              newFilePath: safUri,
              targetFormat: targetFormat,
              bitrate: bitrate,
              bitDepth: convertedBitDepth,
              sampleRate: convertedSampleRate,
            );
          }

          try {
            await File(newPath).delete();
          } catch (_) {}
          if (safTempPath != null) {
            try {
              await File(safTempPath).delete();
            } catch (_) {}
          }
        } else if (item.historyItem != null) {
          await historyDb.updateFilePath(
            item.historyItem!.id,
            newPath,
            newQuality: newQuality,
            newFormat: normalizedConvertedAudioFormat(targetFormat),
            newBitrate: convertedAudioBitrateKbps(
              targetFormat: targetFormat,
              bitrate: bitrate,
            ),
            newBitDepth: convertedBitDepth,
            newSampleRate: convertedSampleRate,
            clearAudioSpecs: !isLosslessOutput,
          );
        } else if (item.localItem != null) {
          await LibraryDatabase.instance.replaceWithConvertedItem(
            item: item.localItem!,
            newFilePath: newPath,
            targetFormat: targetFormat,
            bitrate: bitrate,
            bitDepth: convertedBitDepth,
            sampleRate: convertedSampleRate,
          );
        }

        successCount++;
      } catch (_) {}
    }

    ref.read(downloadHistoryProvider.notifier).reloadFromStorage();
    ref.read(localLibraryProvider.notifier).reloadFromStorage();

    _exitSelectionMode();

    if (mounted) {
      if (!cancelled) {
        BatchProgressDialog.dismiss(context);
      }
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.selectionBatchConvertSuccess(
              successCount,
              total,
              targetFormat,
            ),
          ),
        ),
      );
    }
  }

  /// Batch-scan loudness and write ReplayGain tags to the selected tracks.
  Future<void> _runBatchReplayGain(List<UnifiedLibraryItem> allItems) async {
    final itemsById = {for (final item in allItems) item.id: item};
    final selectedItems = <UnifiedLibraryItem>[];
    for (final id in _selectedIds) {
      final item = itemsById[id];
      if (item == null) continue;
      selectedItems.add(item);
    }

    if (selectedItems.isEmpty) return;

    _suppressSelectionOverlay = true;
    _hideSelectionOverlay();
    _hidePlaylistSelectionOverlay();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.replayGainBatchConfirmTitle),
        content: Text(
          ctx.l10n.replayGainBatchConfirmMessage(selectedItems.length),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.dialogCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.replayGainBatchConfirmTitle),
          ),
        ],
      ),
    );

    if (!mounted) {
      _suppressSelectionOverlay = false;
      return;
    }
    if (confirmed != true) {
      // Restore after the dialog's exit animation.
      await Future<void>.delayed(const Duration(milliseconds: 220));
      _suppressSelectionOverlay = false;
      if (!mounted) return;
      if (_isSelectionMode) {
        _syncSelectionOverlay(
          items: allItems,
          bottomPadding: MediaQuery.paddingOf(context).bottom,
        );
      }
      return;
    }
    _suppressSelectionOverlay = false;

    var cancelled = false;
    int successCount = 0;
    final total = selectedItems.length;

    BatchProgressDialog.show(
      context: context,
      title: context.l10n.replayGainBatchAnalyzing,
      total: total,
      icon: Icons.graphic_eq,
      onCancel: () {
        cancelled = true;
        BatchProgressDialog.dismiss(context);
      },
    );

    for (int i = 0; i < total; i++) {
      if (!mounted || cancelled) break;
      final item = selectedItems[i];
      BatchProgressDialog.update(current: i + 1, detail: item.trackName);
      try {
        final ok = await ReplayGainService.applyToFile(item.filePath);
        if (ok) successCount++;
      } catch (_) {}
    }

    _exitSelectionMode();

    if (!mounted) return;
    if (!cancelled) {
      BatchProgressDialog.dismiss(context);
    }
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.replayGainBatchSuccess(successCount, total)),
      ),
    );
  }

}
