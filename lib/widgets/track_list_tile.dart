import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotiflac_android/models/track.dart';
import 'package:spotiflac_android/providers/download_queue_provider.dart';
import 'package:spotiflac_android/providers/local_library_provider.dart';
import 'package:spotiflac_android/providers/settings_provider.dart';
import 'package:spotiflac_android/utils/clickable_metadata.dart';
import 'package:spotiflac_android/utils/local_playback.dart';
import 'package:spotiflac_android/widgets/audio_quality_badges.dart';
import 'package:spotiflac_android/widgets/in_library_badge.dart';
import 'package:spotiflac_android/widgets/preview_button.dart';
import 'package:spotiflac_android/widgets/track_collection_quick_actions.dart';

/// Track row shared by the album and playlist screens. Tap plays the local
/// copy when one exists and otherwise triggers [onDownload]; long-press opens
/// the track options sheet. Callers supply [leading] (track number, cover
/// art, ...) and choose whether the artist name links to the artist screen.
class TrackListTile extends ConsumerWidget {
  final Track track;
  final bool isInHistory;
  final VoidCallback onDownload;
  final Widget leading;
  final bool clickableArtist;

  const TrackListTile({
    super.key,
    required this.track,
    required this.isInHistory,
    required this.onDownload,
    required this.leading,
    this.clickableArtist = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    final queueItem = ref.watch(
      downloadQueueLookupProvider.select(
        (lookup) => lookup.byTrackId[track.id],
      ),
    );

    final showLocalLibraryIndicator = ref.watch(
      settingsProvider.select(
        (s) => s.localLibraryEnabled && s.localLibraryShowDuplicates,
      ),
    );
    final isInLocalLibrary = showLocalLibraryIndicator
        ? ref.watch(
            localLibraryProvider.select(
              (state) => state.existsInLibrary(
                isrc: track.isrc,
                trackName: track.name,
                artistName: track.artistName,
              ),
            ),
          )
        : false;

    final isQueued = queueItem != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Card(
        elevation: 0,
        color: Colors.transparent,
        margin: const EdgeInsets.symmetric(vertical: 2),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          leading: leading,
          title: Text(
            track.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
          ),
          subtitle: Row(
            children: [
              Flexible(
                child: clickableArtist
                    ? ClickableArtistName(
                        artistName: track.artistName,
                        artistId: track.artistId,
                        coverUrl: track.coverUrl,
                        extensionId: track.source,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      )
                    : Text(
                        track.artistName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
              ),
              ...buildQualityBadges(
                audioQuality: track.audioQuality,
                audioModes: track.audioModes,
                colorScheme: colorScheme,
                explicit: track.isExplicit,
              ),
              if (isInLocalLibrary || isInHistory) ...[
                const SizedBox(width: 6),
                const InLibraryBadge(),
              ],
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PreviewButton(track: track),
              TrackCollectionQuickActions(track: track),
            ],
          ),
          onTap: () => _handleTap(context, ref, isQueued: isQueued),
          onLongPress: () => TrackCollectionQuickActions.showTrackOptionsSheet(
            context,
            ref,
            track,
          ),
        ),
      ),
    );
  }

  void _handleTap(
    BuildContext context,
    WidgetRef ref, {
    required bool isQueued,
  }) async {
    if (isQueued) return;

    final playedLocal = await playLocalIfAvailable(context, ref, track);
    if (playedLocal) {
      return;
    }

    onDownload();
  }
}
