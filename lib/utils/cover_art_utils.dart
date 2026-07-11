/// Deezer CDN cover size pattern: /WxH-q-p-o-n.jpg
final RegExp _deezerCoverSizeRegex = RegExp(
  r'/(\d+)x(\d+)-(\d+)-(\d+)-(\d+)-(\d+)\.jpg$',
);

/// Upgrades a Spotify/Deezer cover URL to a display-quality resolution
/// (Spotify 300px → 640px, Deezer → 1000x1000 preserving quality params).
/// Non-matching URLs pass through unchanged.
String? highResCoverUrl(String? url) {
  if (url == null) return null;
  if (url.contains('ab67616d00001e02')) {
    return url.replaceAll('ab67616d00001e02', 'ab67616d0000b273');
  }
  if (url.contains('cdn-images.dzcdn.net') &&
      _deezerCoverSizeRegex.hasMatch(url)) {
    return url.replaceAllMapped(
      _deezerCoverSizeRegex,
      (m) => '/1000x1000-${m[3]}-${m[4]}-${m[5]}-${m[6]}.jpg',
    );
  }
  return url;
}
