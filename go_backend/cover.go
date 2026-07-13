package gobackend

import (
	"fmt"
	"io"
	"net/http"
	"regexp"
	"strings"
	"sync"
	"time"
)

const (
	spotifySize300 = "ab67616d00001e02"
	spotifySize640 = "ab67616d0000b273"
	spotifySizeMax = "ab67616d000082c1"
)

// Deezer CDN supports these sizes: 56, 250, 500, 1000, 1400, 1800
var deezerSizeRegex = regexp.MustCompile(`/(\d+)x(\d+)-\d+-\d+-\d+-\d+\.jpg$`)

var tidalSizeRegex = regexp.MustCompile(`/\d+x\d+\.jpg$`)

var qobuzSizeRegex = regexp.MustCompile(`_\d+\.jpg$`)

func convertSmallToMedium(imageURL string) string {
	if strings.Contains(imageURL, spotifySize300) {
		return strings.Replace(imageURL, spotifySize300, spotifySize640, 1)
	}
	return imageURL
}

func downloadCoverToMemory(coverURL string, maxQuality bool) ([]byte, error) {
	if coverURL == "" {
		return nil, fmt.Errorf("no cover URL provided")
	}

	GoLog("[Cover] Original URL: %s", coverURL)

	downloadURL := convertSmallToMedium(coverURL)
	if downloadURL != coverURL {
		GoLog("[Cover] Upgraded 300x300 → 640x640")
	}

	if maxQuality {
		maxURL := upgradeToMaxQuality(downloadURL)
		if maxURL != downloadURL {
			downloadURL = maxURL
			if strings.Contains(coverURL, "scdn.co") || strings.Contains(coverURL, "spotifycdn") {
				GoLog("[Cover] Spotify: upgraded to max resolution (~2000x2000)")
			}
		}
	}

	GoLog("[Cover] Final URL: %s", downloadURL)

	data, err := fetchCoverCached(downloadURL)
	if err != nil {
		return nil, err
	}
	// Cached bytes are shared across goroutines and must never be mutated;
	// hand callers their own copy.
	return append([]byte(nil), data...), nil
}

const (
	coverCacheMaxBytes = 24 * 1024 * 1024
	coverCacheTTL      = 15 * time.Minute
)

type coverCacheEntry struct {
	data      []byte
	expiresAt time.Time
}

type coverInflightCall struct {
	wg   sync.WaitGroup
	data []byte
	err  error
}

var (
	coverMu         sync.Mutex
	coverCache      = map[string]*coverCacheEntry{}
	coverCacheBytes int
	coverInflight   = map[string]*coverInflightCall{}
	coverFetch      = fetchCoverBytes
)

// fetchCoverCached returns cover bytes for a final URL, collapsing concurrent
// requests for the same URL into a single fetch (singleflight) and caching
// results in memory for the duration of an album batch. The returned slice is
// shared; callers must copy before mutating.
func fetchCoverCached(downloadURL string) ([]byte, error) {
	coverMu.Lock()
	if e, ok := coverCache[downloadURL]; ok {
		if time.Now().Before(e.expiresAt) {
			data := e.data
			coverMu.Unlock()
			return data, nil
		}
		delete(coverCache, downloadURL)
		coverCacheBytes -= len(e.data)
	}
	if call, ok := coverInflight[downloadURL]; ok {
		coverMu.Unlock()
		call.wg.Wait()
		return call.data, call.err
	}
	call := &coverInflightCall{}
	call.wg.Add(1)
	coverInflight[downloadURL] = call
	coverMu.Unlock()

	data, err := coverFetch(downloadURL)
	call.data, call.err = data, err
	if err == nil {
		coverCachePut(downloadURL, data)
	}
	call.wg.Done()

	coverMu.Lock()
	delete(coverInflight, downloadURL)
	coverMu.Unlock()

	return data, err
}

func coverCachePut(downloadURL string, data []byte) {
	if len(data) == 0 || len(data) > coverCacheMaxBytes {
		return
	}
	coverMu.Lock()
	defer coverMu.Unlock()
	if e, ok := coverCache[downloadURL]; ok {
		coverCacheBytes -= len(e.data)
	}
	coverCache[downloadURL] = &coverCacheEntry{data: data, expiresAt: time.Now().Add(coverCacheTTL)}
	coverCacheBytes += len(data)
	for coverCacheBytes > coverCacheMaxBytes && len(coverCache) > 1 {
		var oldestKey string
		var oldest time.Time
		first := true
		for k, e := range coverCache {
			if first || e.expiresAt.Before(oldest) {
				oldest, oldestKey, first = e.expiresAt, k, false
			}
		}
		coverCacheBytes -= len(coverCache[oldestKey].data)
		delete(coverCache, oldestKey)
	}
}

func fetchCoverBytes(downloadURL string) ([]byte, error) {
	client := NewHTTPClientWithTimeout(DefaultTimeout)

	req, err := http.NewRequest("GET", downloadURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	resp, err := DoRequestWithUserAgent(client, req)
	if err != nil {
		return nil, fmt.Errorf("failed to download cover: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("cover download failed: HTTP %d", resp.StatusCode)
	}

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read cover data: %w", err)
	}

	sizeKB := len(data) / 1024
	var resolution string
	if sizeKB > 200 {
		resolution = "~2000x2000 (hi-res)"
	} else if sizeKB > 50 {
		resolution = "~640x640"
	} else {
		resolution = "~300x300"
	}
	GoLog("[Cover] Downloaded %d KB (%s)", sizeKB, resolution)

	return data, nil
}

func upgradeToMaxQuality(coverURL string) string {
	if strings.Contains(coverURL, spotifySize640) {
		return strings.Replace(coverURL, spotifySize640, spotifySizeMax, 1)
	}

	if strings.Contains(coverURL, "cdn-images.dzcdn.net") {
		return upgradeDeezerCover(coverURL)
	}

	if strings.Contains(coverURL, "resources.tidal.com") {
		return upgradeTidalCover(coverURL)
	}

	if strings.Contains(coverURL, "static.qobuz.com") {
		return upgradeQobuzCover(coverURL)
	}

	return coverURL
}

func upgradeDeezerCover(coverURL string) string {
	if !strings.Contains(coverURL, "cdn-images.dzcdn.net") {
		return coverURL
	}

	upgraded := deezerSizeRegex.ReplaceAllString(coverURL, "/1800x1800-000000-80-0-0.jpg")
	if upgraded != coverURL {
		GoLog("[Cover] Deezer: upgraded to 1800x1800")
	}
	return upgraded
}

func upgradeTidalCover(coverURL string) string {
	if !strings.Contains(coverURL, "resources.tidal.com") {
		return coverURL
	}

	upgraded := tidalSizeRegex.ReplaceAllString(coverURL, "/origin.jpg")
	if upgraded != coverURL {
		GoLog("[Cover] Tidal: upgraded to origin resolution")
	}
	return upgraded
}

func upgradeQobuzCover(coverURL string) string {
	if !strings.Contains(coverURL, "static.qobuz.com") {
		return coverURL
	}

	upgraded := qobuzSizeRegex.ReplaceAllString(coverURL, "_max.jpg")
	if upgraded != coverURL {
		GoLog("[Cover] Qobuz: upgraded to max resolution")
	}
	return upgraded
}

func GetCoverFromSpotify(imageURL string, maxQuality bool) string {
	if imageURL == "" {
		return ""
	}

	result := convertSmallToMedium(imageURL)

	if maxQuality {
		result = upgradeToMaxQuality(result)
	}

	return result
}
