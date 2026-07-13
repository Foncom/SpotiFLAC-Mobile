package gobackend

import (
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

func resetCoverCache() {
	coverMu.Lock()
	coverCache = map[string]*coverCacheEntry{}
	coverInflight = map[string]*coverInflightCall{}
	coverCacheBytes = 0
	coverMu.Unlock()
}

func TestFetchCoverCachedSingleflight(t *testing.T) {
	orig := coverFetch
	defer func() { coverFetch = orig }()
	resetCoverCache()

	var calls int32
	entered := make(chan struct{})
	release := make(chan struct{})
	coverFetch = func(string) ([]byte, error) {
		if atomic.AddInt32(&calls, 1) == 1 {
			close(entered)
		}
		<-release
		return []byte("coverbytes"), nil
	}

	const url = "https://cdn.example/cover_max.jpg"
	var wg sync.WaitGroup
	wg.Add(1)
	go func() {
		defer wg.Done()
		if _, err := fetchCoverCached(url); err != nil {
			t.Errorf("leader fetch error: %v", err)
		}
	}()

	<-entered // leader has registered inflight and is blocked in coverFetch

	wg.Add(1)
	go func() {
		defer wg.Done()
		if _, err := fetchCoverCached(url); err != nil {
			t.Errorf("follower fetch error: %v", err)
		}
	}()

	close(release)
	wg.Wait()

	if got := atomic.LoadInt32(&calls); got != 1 {
		t.Fatalf("expected 1 fetch for concurrent requests, got %d", got)
	}
}

func TestFetchCoverCachedTTLExpiry(t *testing.T) {
	orig := coverFetch
	defer func() { coverFetch = orig }()
	resetCoverCache()

	var calls int32
	coverFetch = func(string) ([]byte, error) {
		atomic.AddInt32(&calls, 1)
		return []byte("data"), nil
	}

	const url = "https://cdn.example/ttl.jpg"
	if _, err := fetchCoverCached(url); err != nil {
		t.Fatalf("first fetch error: %v", err)
	}
	// second call served from cache
	if _, err := fetchCoverCached(url); err != nil {
		t.Fatalf("second fetch error: %v", err)
	}
	if got := atomic.LoadInt32(&calls); got != 1 {
		t.Fatalf("expected cache hit, got %d fetches", got)
	}

	// expire the entry and confirm a refetch
	coverMu.Lock()
	coverCache[url].expiresAt = time.Now().Add(-time.Minute)
	coverMu.Unlock()

	if _, err := fetchCoverCached(url); err != nil {
		t.Fatalf("third fetch error: %v", err)
	}
	if got := atomic.LoadInt32(&calls); got != 2 {
		t.Fatalf("expected refetch after TTL expiry, got %d fetches", got)
	}
}
