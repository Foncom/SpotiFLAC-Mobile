import 'package:flutter_test/flutter_test.dart';
import 'package:spotiflac_android/providers/download_history_provider.dart';

DownloadHistoryItem _historyItem({
  required String id,
  required String filePath,
  required DateTime downloadedAt,
  String albumName = 'Album',
}) {
  return DownloadHistoryItem(
    id: id,
    trackName: 'Same Song',
    artistName: 'Same Artist',
    albumName: albumName,
    filePath: filePath,
    service: 'test',
    downloadedAt: downloadedAt,
    spotifyId: 'spotify:track:same',
    isrc: 'SAMEISRC',
  );
}

void main() {
  group('download history identity', () {
    test('same track metadata does not merge files from different albums', () {
      final first = _historyItem(
        id: 'first',
        filePath: '/music/First Album/Same Song.flac',
        downloadedAt: DateTime.utc(2026, 7, 22),
        albumName: 'First Album',
      );
      final second = _historyItem(
        id: 'second',
        filePath: '/music/Second Album/Same Song.flac',
        downloadedAt: DateTime.utc(2026, 7, 23),
        albumName: 'Second Album',
      );

      expect(historyItemsReferToSameStoredFile(first, second), isFalse);
    });

    test('equivalent paths still update one stored file record', () {
      final original = _historyItem(
        id: 'original',
        filePath: '/music/Album/Same Song.flac',
        downloadedAt: DateTime.utc(2026, 7, 22),
      );
      final converted = _historyItem(
        id: 'converted',
        filePath: '/music/Album/Same Song.opus',
        downloadedAt: DateTime.utc(2026, 7, 23),
      );

      expect(historyItemsReferToSameStoredFile(original, converted), isTrue);
    });

    test('duplicate track identities keep the newest lookup item', () {
      final newest = _historyItem(
        id: 'newest',
        filePath: '/music/New Album/Same Song.flac',
        downloadedAt: DateTime.utc(2026, 7, 23),
        albumName: 'New Album',
      );
      final older = _historyItem(
        id: 'older',
        filePath: '/music/Old Album/Same Song.flac',
        downloadedAt: DateTime.utc(2026, 7, 22),
        albumName: 'Old Album',
      );

      final state = DownloadHistoryState(
        items: [newest, older],
        lookupItems: [newest, older],
        totalCount: 2,
      );

      expect(state.getBySpotifyId('spotify:track:same')?.id, 'newest');
      expect(state.getByIsrc('SAMEISRC')?.id, 'newest');
      expect(
        state.findByTrackAndArtist('Same Song', 'Same Artist')?.id,
        'newest',
      );
      expect(state.items, hasLength(2));
    });
  });

  group('startup orphan reconciliation', () {
    test('requires consecutive missing checks before confirmation', () {
      final firstMissing = reconcileStartupOrphanSuspects(
        checkedIds: {'track'},
        missingIds: {'track'},
        previousSuspectIds: {},
      );
      expect(firstMissing.confirmedIds, isEmpty);
      expect(firstMissing.pendingIds, {'track'});

      final recovered = reconcileStartupOrphanSuspects(
        checkedIds: {'track'},
        missingIds: {},
        previousSuspectIds: firstMissing.pendingIds,
      );
      expect(recovered.confirmedIds, isEmpty);
      expect(recovered.pendingIds, isEmpty);

      final missingAgain = reconcileStartupOrphanSuspects(
        checkedIds: {'track'},
        missingIds: {'track'},
        previousSuspectIds: recovered.pendingIds,
      );
      expect(missingAgain.confirmedIds, isEmpty);
      expect(missingAgain.pendingIds, {'track'});

      final consecutiveMissing = reconcileStartupOrphanSuspects(
        checkedIds: {'track'},
        missingIds: {'track'},
        previousSuspectIds: missingAgain.pendingIds,
      );
      expect(consecutiveMissing.confirmedIds, {'track'});
      expect(consecutiveMissing.pendingIds, isEmpty);
    });

    test('ignores unchecked stale suspects', () {
      final decision = reconcileStartupOrphanSuspects(
        checkedIds: {'checked'},
        missingIds: {'unchecked'},
        previousSuspectIds: {'unchecked'},
      );

      expect(decision.confirmedIds, isEmpty);
      expect(decision.pendingIds, isEmpty);
    });
  });
}
