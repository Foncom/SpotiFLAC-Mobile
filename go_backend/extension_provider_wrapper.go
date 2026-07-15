package gobackend

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/dop251/goja"
)

type extensionProviderWrapper struct {
	extension *loadedExtension
	vm        *goja.Runtime
}

func newExtensionProviderWrapper(ext *loadedExtension) *extensionProviderWrapper {
	return &extensionProviderWrapper{
		extension: ext,
		vm:        ext.VM,
	}
}

func (p *extensionProviderWrapper) lockReadyVM() error {
	vm, err := p.extension.lockReadyVM()
	if err != nil {
		return err
	}
	p.vm = vm
	return nil
}

// extCallOpts configures a shared extension script invocation. It covers the
// skeleton common to most extensionProviderWrapper methods: perf tracking, VM
// locking, optional download/request cancellation binding, running the
// script, and translating timeouts/cancellation into the right error.
type extCallOpts struct {
	perfName  string
	script    string
	timeout   time.Duration
	itemID    string // optional: binds download-cancel + active-item tracking
	requestID string // optional: binds request-cancel via context (customSearch only)
	// beforeRun runs after lock+cancel setup, right before the script executes
	// (used to stash query/options as globals instead of embedding them in the
	// script source). Its returned cleanup, if any, runs after the script call.
	beforeRun func() func()
	// timeoutMessage overrides the default "<perfName> timeout: extension took
	// too long to respond".
	timeoutMessage string
	// rawError returns non-timeout script errors unwrapped instead of
	// "<perfName> failed: %w".
	rawError bool
}

// callExtensionScript locks the extension's VM, runs opts.script, and hands
// the raw result to parse while the VM lock is still held. parse is where
// each caller does its type-specific parsing, perf.recordParse/setItems, and
// any ProviderID stamping.
func callExtensionScript[T any](p *extensionProviderWrapper, opts extCallOpts, parse func(perf *extensionCallPerf, result goja.Value) (T, error)) (T, error) {
	var zero T

	perf := newExtensionCallPerf(p.extension.ID, opts.perfName)
	defer perf.finish()
	initStartedAt := time.Now()
	if err := p.lockReadyVM(); err != nil {
		return zero, err
	}
	perf.recordInit(time.Since(initStartedAt))
	defer p.extension.VMMu.Unlock()

	if opts.itemID != "" {
		if p.extension.runtime != nil {
			p.extension.runtime.setActiveDownloadItemID(opts.itemID)
			defer p.extension.runtime.clearActiveDownloadItemID()
		}
		initDownloadCancel(opts.itemID)
		defer clearDownloadCancel(opts.itemID)
		if isDownloadCancelled(opts.itemID) {
			return zero, ErrDownloadCancelled
		}
	}

	ctx := context.Background()
	if opts.requestID != "" {
		if p.extension.runtime != nil {
			p.extension.runtime.setActiveRequestID(opts.requestID)
			defer p.extension.runtime.clearActiveRequestID()
		}
		ctx = initExtensionRequestCancel(opts.requestID)
		defer clearExtensionRequestCancel(opts.requestID)
		if isExtensionRequestCancelled(opts.requestID) {
			return zero, ErrExtensionRequestCancelled
		}
	}

	if opts.beforeRun != nil {
		if cleanup := opts.beforeRun(); cleanup != nil {
			defer cleanup()
		}
	}

	jsStartedAt := time.Now()
	result, err := RunWithTimeoutContextAndRecover(ctx, p.vm, opts.script, opts.timeout)
	perf.recordJS(time.Since(jsStartedAt))
	perf.recordPayload(result)
	if err != nil {
		if IsRuntimeUnsafeError(err) {
			quarantineRuntimeLocked(p.extension, p.vm)
		}
		if opts.requestID != "" && isExtensionRequestCancelled(opts.requestID) {
			return zero, ErrExtensionRequestCancelled
		}
		if opts.itemID != "" && isDownloadCancelled(opts.itemID) {
			return zero, ErrDownloadCancelled
		}
		if opts.requestID != "" && errors.Is(err, ErrExtensionRequestCancelled) {
			return zero, ErrExtensionRequestCancelled
		}
		if IsTimeoutError(err) {
			if opts.timeoutMessage != "" {
				return zero, errors.New(opts.timeoutMessage)
			}
			return zero, fmt.Errorf("%s timeout: extension took too long to respond", opts.perfName)
		}
		if opts.rawError {
			return zero, err
		}
		return zero, fmt.Errorf("%s failed: %w", opts.perfName, err)
	}
	if opts.itemID != "" && isDownloadCancelled(opts.itemID) {
		return zero, ErrDownloadCancelled
	}
	if opts.requestID != "" && isExtensionRequestCancelled(opts.requestID) {
		return zero, ErrExtensionRequestCancelled
	}

	return parse(perf, result)
}

func (p *extensionProviderWrapper) SearchTracks(query string, limit int) (*ExtSearchResult, error) {
	return p.SearchTracksForItemID(query, limit, "")
}

func (p *extensionProviderWrapper) SearchTracksForItemID(query string, limit int, itemID string) (*ExtSearchResult, error) {
	if !p.extension.Manifest.IsMetadataProvider() {
		return nil, fmt.Errorf("extension '%s' is not a metadata provider", p.extension.ID)
	}
	if !p.extension.Enabled {
		return nil, fmt.Errorf("extension '%s' is disabled", p.extension.ID)
	}

	script := fmt.Sprintf(`
		(function() {
			if (typeof extension !== 'undefined' && typeof extension.searchTracks === 'function') {
				return extension.searchTracks(%q, %d);
			}
			return null;
		})()
	`, query, limit)

	return callExtensionScript(p, extCallOpts{
		perfName: "searchTracks",
		script:   script,
		timeout:  DefaultJSTimeout,
		itemID:   itemID,
	}, func(perf *extensionCallPerf, result goja.Value) (*ExtSearchResult, error) {
		if result == nil || goja.IsUndefined(result) || goja.IsNull(result) {
			return nil, fmt.Errorf("searchTracks returned null")
		}
		parseStartedAt := time.Now()
		searchResult, err := parseExtensionSearchResult(p.vm, result)
		perf.recordParse(time.Since(parseStartedAt))
		if err != nil {
			return nil, fmt.Errorf("failed to parse search result: %w", err)
		}
		perf.setItems(len(searchResult.Tracks))

		for i := range searchResult.Tracks {
			searchResult.Tracks[i].ProviderID = p.extension.ID
		}

		return &searchResult, nil
	})
}

func (p *extensionProviderWrapper) GetTrack(trackID string) (*ExtTrackMetadata, error) {
	if !p.extension.Manifest.IsMetadataProvider() {
		return nil, fmt.Errorf("extension '%s' is not a metadata provider", p.extension.ID)
	}
	if !p.extension.Enabled {
		return nil, fmt.Errorf("extension '%s' is disabled", p.extension.ID)
	}

	script := fmt.Sprintf(`
		(function() {
			if (typeof extension !== 'undefined' && typeof extension.getTrack === 'function') {
				return extension.getTrack(%q);
			}
			return null;
		})()
	`, trackID)

	return callExtensionScript(p, extCallOpts{
		perfName: "getTrack",
		script:   script,
		timeout:  DefaultJSTimeout,
	}, func(perf *extensionCallPerf, result goja.Value) (*ExtTrackMetadata, error) {
		if result == nil || goja.IsUndefined(result) || goja.IsNull(result) {
			return nil, fmt.Errorf("getTrack returned null")
		}
		parseStartedAt := time.Now()
		track := parseExtensionTrackValue(p.vm, result)
		perf.recordParse(time.Since(parseStartedAt))
		perf.setItems(1)
		track.ProviderID = p.extension.ID
		return &track, nil
	})
}

func (p *extensionProviderWrapper) GetAlbum(albumID string) (*ExtAlbumMetadata, error) {
	if !p.extension.Manifest.IsMetadataProvider() {
		return nil, fmt.Errorf("extension '%s' is not a metadata provider", p.extension.ID)
	}
	if !p.extension.Enabled {
		return nil, fmt.Errorf("extension '%s' is disabled", p.extension.ID)
	}

	script := fmt.Sprintf(`
		(function() {
			if (typeof extension !== 'undefined' && typeof extension.getAlbum === 'function') {
				return extension.getAlbum(%q);
			}
			return null;
		})()
	`, albumID)

	return callExtensionScript(p, extCallOpts{
		perfName: "getAlbum",
		script:   script,
		timeout:  DefaultJSTimeout,
	}, func(perf *extensionCallPerf, result goja.Value) (*ExtAlbumMetadata, error) {
		if result == nil || goja.IsUndefined(result) || goja.IsNull(result) {
			return nil, fmt.Errorf("getAlbum returned null")
		}
		parseStartedAt := time.Now()
		album, err := parseExtensionAlbumValue(p.vm, result)
		perf.recordParse(time.Since(parseStartedAt))
		if err != nil {
			return nil, fmt.Errorf("failed to parse album: %w", err)
		}
		perf.setItems(len(album.Tracks))

		album.ProviderID = p.extension.ID
		for i := range album.Tracks {
			album.Tracks[i].ProviderID = p.extension.ID
		}
		return &album, nil
	})
}

func (p *extensionProviderWrapper) GetPlaylist(playlistID string) (*ExtAlbumMetadata, error) {
	if !p.extension.Manifest.IsMetadataProvider() {
		return nil, fmt.Errorf("extension '%s' is not a metadata provider", p.extension.ID)
	}
	if !p.extension.Enabled {
		return nil, fmt.Errorf("extension '%s' is disabled", p.extension.ID)
	}

	script := fmt.Sprintf(`
		(function() {
			if (typeof extension !== 'undefined' && typeof extension.getPlaylist === 'function') {
				return extension.getPlaylist(%q);
			}
			if (typeof extension !== 'undefined' && typeof extension.getAlbum === 'function') {
				return extension.getAlbum(%q);
			}
			return null;
		})()
	`, playlistID, playlistID)

	return callExtensionScript(p, extCallOpts{
		perfName: "getPlaylist",
		script:   script,
		timeout:  DefaultJSTimeout,
	}, func(perf *extensionCallPerf, result goja.Value) (*ExtAlbumMetadata, error) {
		if result == nil || goja.IsUndefined(result) || goja.IsNull(result) {
			return nil, fmt.Errorf("getPlaylist returned null")
		}
		parseStartedAt := time.Now()
		playlist, err := parseExtensionAlbumValue(p.vm, result)
		perf.recordParse(time.Since(parseStartedAt))
		if err != nil {
			return nil, fmt.Errorf("failed to parse playlist: %w", err)
		}
		perf.setItems(len(playlist.Tracks))

		playlist.ProviderID = p.extension.ID
		for i := range playlist.Tracks {
			playlist.Tracks[i].ProviderID = p.extension.ID
		}
		return &playlist, nil
	})
}

func (p *extensionProviderWrapper) GetArtist(artistID string) (*ExtArtistMetadata, error) {
	if !p.extension.Manifest.IsMetadataProvider() {
		return nil, fmt.Errorf("extension '%s' is not a metadata provider", p.extension.ID)
	}
	if !p.extension.Enabled {
		return nil, fmt.Errorf("extension '%s' is disabled", p.extension.ID)
	}

	script := fmt.Sprintf(`
		(function() {
			if (typeof extension !== 'undefined' && typeof extension.getArtist === 'function') {
				return extension.getArtist(%q);
			}
			return null;
		})()
	`, artistID)

	return callExtensionScript(p, extCallOpts{
		perfName: "getArtist",
		script:   script,
		timeout:  DefaultJSTimeout,
	}, func(perf *extensionCallPerf, result goja.Value) (*ExtArtistMetadata, error) {
		if result == nil || goja.IsUndefined(result) || goja.IsNull(result) {
			return nil, fmt.Errorf("getArtist returned null")
		}
		parseStartedAt := time.Now()
		artist, err := parseExtensionArtistValue(p.vm, result)
		perf.recordParse(time.Since(parseStartedAt))
		if err != nil {
			return nil, fmt.Errorf("failed to parse artist: %w", err)
		}
		perf.setItems(len(artist.Albums) + len(artist.Releases) + len(artist.TopTracks))

		artist.ProviderID = p.extension.ID
		for i := range artist.Releases {
			artist.Releases[i].ProviderID = p.extension.ID
			for j := range artist.Releases[i].Tracks {
				artist.Releases[i].Tracks[j].ProviderID = p.extension.ID
			}
		}
		return &artist, nil
	})
}

func (p *extensionProviderWrapper) EnrichTrack(track *ExtTrackMetadata) (*ExtTrackMetadata, error) {
	return p.EnrichTrackForItemID(track, "")
}

// EnrichTrackForItemID is excluded from the shared callExtensionScript helper:
// unlike the other providers it must return the original track (not an error)
// on every failure path, which doesn't fit the helper's error-returning shape.
func (p *extensionProviderWrapper) EnrichTrackForItemID(track *ExtTrackMetadata, itemID string) (*ExtTrackMetadata, error) {
	if !p.extension.Manifest.IsMetadataProvider() {
		return track, nil
	}

	if !p.extension.Enabled {
		return track, nil
	}
	perf := newExtensionCallPerf(p.extension.ID, "enrichTrack")
	defer perf.finish()
	initStartedAt := time.Now()
	if err := p.lockReadyVM(); err != nil {
		GoLog("[Extension] EnrichTrack init error for %s: %v\n", p.extension.ID, err)
		return track, nil
	}
	perf.recordInit(time.Since(initStartedAt))
	defer p.extension.VMMu.Unlock()
	if itemID != "" {
		if p.extension.runtime != nil {
			p.extension.runtime.setActiveDownloadItemID(itemID)
			defer p.extension.runtime.clearActiveDownloadItemID()
		}
		initDownloadCancel(itemID)
		defer clearDownloadCancel(itemID)
		if isDownloadCancelled(itemID) {
			return track, ErrDownloadCancelled
		}
	}

	trackJSON, err := json.Marshal(track)
	if err != nil {
		GoLog("[Extension] EnrichTrack: failed to marshal track: %v\n", err)
		return track, nil
	}

	script := fmt.Sprintf(`
		(function() {
			if (typeof extension !== 'undefined' && typeof extension.enrichTrack === 'function') {
				var track = %s;
				return extension.enrichTrack(track);
			}
			return null;
		})()
	`, string(trackJSON))

	jsStartedAt := time.Now()
	result, err := RunWithTimeoutAndRecover(p.vm, script, DefaultJSTimeout)
	perf.recordJS(time.Since(jsStartedAt))
	perf.recordPayload(result)
	if err != nil {
		if IsRuntimeUnsafeError(err) {
			quarantineRuntimeLocked(p.extension, p.vm)
		}
		if isDownloadCancelled(itemID) {
			return track, ErrDownloadCancelled
		}
		if IsTimeoutError(err) {
			GoLog("[Extension] EnrichTrack timeout for %s\n", p.extension.ID)
		} else {
			GoLog("[Extension] EnrichTrack error for %s: %v\n", p.extension.ID, err)
		}
		return track, nil
	}
	if isDownloadCancelled(itemID) {
		return track, ErrDownloadCancelled
	}

	if result == nil || goja.IsUndefined(result) || goja.IsNull(result) {
		return track, nil
	}

	parseStartedAt := time.Now()
	enrichedTrack := parseExtensionTrackValue(p.vm, result)
	perf.recordParse(time.Since(parseStartedAt))
	perf.setItems(1)
	enrichedTrack.ProviderID = track.ProviderID

	return &enrichedTrack, nil
}

func (p *extensionProviderWrapper) CheckAvailabilityForItemID(isrc, trackName, artistName, spotifyID, deezerID, tidalID, qobuzID string, durationMS int, itemID string) (*ExtAvailabilityResult, error) {
	if !p.extension.Manifest.IsDownloadProvider() {
		return nil, fmt.Errorf("extension '%s' is not a download provider", p.extension.ID)
	}
	if !p.extension.Enabled {
		return nil, fmt.Errorf("extension '%s' is disabled", p.extension.ID)
	}

	script := fmt.Sprintf(`
		(function() {
			if (typeof extension !== 'undefined' && typeof extension.checkAvailability === 'function') {
				return extension.checkAvailability(%q, %q, %q, {
					spotify_id: %q,
					deezer_id: %q,
					tidal_id: %q,
					qobuz_id: %q,
					duration_ms: %d
				});
			}
			return null;
		})()
	`, isrc, trackName, artistName, spotifyID, deezerID, tidalID, qobuzID, durationMS)

	return callExtensionScript(p, extCallOpts{
		perfName: "checkAvailability",
		script:   script,
		timeout:  DefaultJSTimeout,
		itemID:   itemID,
		beforeRun: func() func() {
			// Drop any stale flag so the post-run check below only sees
			// verification requested by THIS call.
			if p.extension.runtime != nil {
				p.extension.runtime.consumeVerificationRequired()
			}
			return nil
		},
	}, func(perf *extensionCallPerf, result goja.Value) (*ExtAvailabilityResult, error) {
		if result == nil || goja.IsUndefined(result) || goja.IsNull(result) {
			return &ExtAvailabilityResult{Available: false, Reason: "not implemented"}, nil
		}
		parseStartedAt := time.Now()
		availability := parseExtensionAvailabilityValue(p.vm, result)
		perf.recordParse(time.Since(parseStartedAt))
		perf.setItems(1)
		// A signed-session call inside checkAvailability required
		// verification. Extensions often swallow that and report a plain
		// "not available", which would silently skip this provider's
		// challenge; surface it as an error so the fallback loop pauses and
		// opens the challenge instead.
		if !availability.Available && p.extension.runtime != nil {
			if p.extension.runtime.consumeVerificationRequired() != "" {
				return nil, fmt.Errorf(
					"VERIFY_REQUIRED: extension '%s' needs signed-session verification",
					p.extension.ID,
				)
			}
		}
		return &availability, nil
	})
}

const ExtDownloadTimeout = DownloadTimeout

// Download is excluded from the shared callExtensionScript helper: it runs in
// an isolated VM/runtime (not p.vm/p.extension.VMMu) with a progress
// callback, which the helper's lock+perf model doesn't cover.
func (p *extensionProviderWrapper) Download(trackID, quality, outputPath, itemID string, onProgress func(percent int)) (*ExtDownloadResult, error) {
	if !p.extension.Manifest.IsDownloadProvider() {
		return nil, fmt.Errorf("extension '%s' is not a download provider", p.extension.ID)
	}

	if !p.extension.Enabled {
		return nil, fmt.Errorf("extension '%s' is disabled", p.extension.ID)
	}
	perf := newExtensionCallPerf(p.extension.ID, "download")
	defer perf.finish()
	initStartedAt := time.Now()
	vm, runtime, err := acquireIsolatedExtensionRuntime(p.extension)
	perf.recordInit(time.Since(initStartedAt))
	if err != nil {
		return &ExtDownloadResult{
			Success:      false,
			ErrorMessage: err.Error(),
			ErrorType:    "init_error",
		}, nil
	}
	vmHealthy := false
	cleanupSafe := true
	defer func() {
		releaseIsolatedExtensionRuntime(p.extension, vm, runtime, vmHealthy, cleanupSafe)
	}()
	if runtime != nil {
		runtime.setActiveDownloadItemID(itemID)
		defer runtime.clearActiveDownloadItemID()
	}
	if itemID != "" {
		initDownloadCancel(itemID)
		defer clearDownloadCancel(itemID)
		SetItemPreparing(itemID)
	}

	vm.Set("__onProgress", func(call goja.FunctionCall) goja.Value {
		if len(call.Arguments) > 0 {
			percent := int(call.Arguments[0].ToInteger())
			if percent < 0 {
				percent = 0
			}
			if percent > 100 {
				percent = 100
			}
			if onProgress != nil {
				onProgress(percent)
			}
		}
		return goja.Undefined()
	})

	script := fmt.Sprintf(`
		(function() {
			if (typeof extension !== 'undefined' && typeof extension.download === 'function') {
				return extension.download(%q, %q, %q, __onProgress);
			}
			return null;
		})()
	`, trackID, quality, outputPath)

	if runtime != nil {
		// Drop any stale flag (pooled runtimes survive across downloads) so
		// the post-run check only sees verification from THIS call.
		runtime.consumeVerificationRequired()
	}

	jsStartedAt := time.Now()
	result, err := RunWithTimeoutAndRecover(vm, script, ExtDownloadTimeout)
	perf.recordJS(time.Since(jsStartedAt))
	perf.recordPayload(result)
	vmHealthy = err == nil
	cleanupSafe = !IsRuntimeUnsafeError(err)
	if err != nil {
		errMsg := err.Error()
		errType := "script_error"
		if IsTimeoutError(err) {
			errMsg = "download timeout: extension took too long to complete"
			errType = "timeout"
		}
		return &ExtDownloadResult{
			Success:      false,
			ErrorMessage: errMsg,
			ErrorType:    errType,
		}, nil
	}

	if result == nil || goja.IsUndefined(result) || goja.IsNull(result) {
		return &ExtDownloadResult{
			Success:      false,
			ErrorMessage: "download returned null",
			ErrorType:    "not_implemented",
		}, nil
	}

	parseStartedAt := time.Now()
	downloadResult := parseExtensionDownloadResultValue(vm, result)
	perf.recordParse(time.Since(parseStartedAt))
	perf.setItems(1)
	downloadResult.Decryption = normalizeDownloadDecryptionInfo(
		downloadResult.Decryption,
		downloadResult.DecryptionKey,
	)
	downloadResult.DecryptionKey = normalizedDownloadDecryptionKey(
		downloadResult.Decryption,
		downloadResult.DecryptionKey,
	)

	// A signed-session call inside download() required verification but the
	// script reported a generic failure; tag the result so the fallback loop
	// pauses and opens this provider's challenge instead of skipping it.
	if runtime != nil && !downloadResult.Success {
		if runtime.consumeVerificationRequired() != "" &&
			!strings.EqualFold(downloadResult.ErrorType, "verification_required") {
			downloadResult.ErrorType = "verification_required"
			if downloadResult.ErrorMessage == "" {
				downloadResult.ErrorMessage = "Verification required"
			}
		}
	}

	return &downloadResult, nil
}

func (p *extensionProviderWrapper) CustomSearch(query string, options map[string]any) ([]ExtTrackMetadata, error) {
	return p.customSearch(query, options, "", "")
}

func (p *extensionProviderWrapper) CustomSearchForRequestID(query string, options map[string]any, requestID string) ([]ExtTrackMetadata, error) {
	return p.customSearch(query, options, "", requestID)
}

func (p *extensionProviderWrapper) customSearch(query string, options map[string]any, itemID, requestID string) ([]ExtTrackMetadata, error) {
	if !p.extension.Manifest.HasCustomSearch() {
		return nil, fmt.Errorf("extension '%s' does not support custom search", p.extension.ID)
	}
	if !p.extension.Enabled {
		return nil, fmt.Errorf("extension '%s' is disabled", p.extension.ID)
	}
	if options == nil {
		options = map[string]any{}
	}

	// Avoid embedding user input directly into JS source. Some inputs can trigger
	// parser/runtime edge cases on specific devices/Goja builds.
	const queryVar = "__sf_custom_search_query"
	const optionsVar = "__sf_custom_search_options"

	const script = `
		(function() {
			if (typeof extension !== 'undefined' && typeof extension.customSearch === 'function') {
				return extension.customSearch(__sf_custom_search_query, __sf_custom_search_options);
			}
			return null;
		})()
	`

	return callExtensionScript(p, extCallOpts{
		perfName:  "customSearch",
		script:    script,
		timeout:   DefaultJSTimeout,
		itemID:    itemID,
		requestID: requestID,
		beforeRun: func() func() {
			global := p.vm.GlobalObject()
			_ = global.Set(queryVar, query)
			_ = global.Set(optionsVar, options)
			return func() {
				global.Delete(queryVar)
				global.Delete(optionsVar)
			}
		},
	}, func(perf *extensionCallPerf, result goja.Value) ([]ExtTrackMetadata, error) {
		if result == nil || goja.IsUndefined(result) || goja.IsNull(result) {
			return []ExtTrackMetadata{}, nil
		}
		parseStartedAt := time.Now()
		tracks, err := parseExtensionTrackArray(p.vm, result)
		perf.recordParse(time.Since(parseStartedAt))
		if err != nil {
			return nil, fmt.Errorf("failed to parse search result: %w", err)
		}
		perf.setItems(len(tracks))

		for i := range tracks {
			tracks[i].ProviderID = p.extension.ID
		}

		return tracks, nil
	})
}

type ExtURLHandleResult struct {
	Type        string             `json:"type"`
	Track       *ExtTrackMetadata  `json:"track,omitempty"`
	Tracks      []ExtTrackMetadata `json:"tracks,omitempty"`
	Album       *ExtAlbumMetadata  `json:"album,omitempty"`
	Artist      *ExtArtistMetadata `json:"artist,omitempty"`
	Name        string             `json:"name,omitempty"`
	CoverURL    string             `json:"cover_url,omitempty"`
	HeaderImage string             `json:"header_image,omitempty"`
	HeaderVideo string             `json:"header_video,omitempty"`
}

func (p *extensionProviderWrapper) HandleURL(url string) (*ExtURLHandleResult, error) {
	if !p.extension.Manifest.HasURLHandler() {
		return nil, fmt.Errorf("extension '%s' does not support URL handling", p.extension.ID)
	}
	if !p.extension.Enabled {
		return nil, fmt.Errorf("extension '%s' is disabled", p.extension.ID)
	}

	script := fmt.Sprintf(`
		(function() {
			if (typeof extension !== 'undefined' && typeof extension.handleUrl === 'function') {
				return extension.handleUrl(%q);
			}
			return null;
		})()
	`, url)

	return callExtensionScript(p, extCallOpts{
		perfName: "handleUrl",
		script:   script,
		timeout:  DefaultJSTimeout,
	}, func(perf *extensionCallPerf, result goja.Value) (*ExtURLHandleResult, error) {
		if result == nil || goja.IsUndefined(result) || goja.IsNull(result) {
			return nil, fmt.Errorf("handleUrl returned null - URL not recognized")
		}
		parseStartedAt := time.Now()
		handleResult, err := parseExtensionURLHandleValue(p.vm, result)
		perf.recordParse(time.Since(parseStartedAt))
		if err != nil {
			return nil, fmt.Errorf("failed to parse URL handle result: %w", err)
		}
		urlItems := len(handleResult.Tracks)
		if handleResult.Track != nil {
			urlItems++
		}
		if handleResult.Album != nil {
			urlItems += 1 + len(handleResult.Album.Tracks)
		}
		if handleResult.Artist != nil {
			urlItems += 1 + len(handleResult.Artist.Albums) + len(handleResult.Artist.Releases) + len(handleResult.Artist.TopTracks)
		}
		perf.setItems(urlItems)

		if handleResult.Track != nil {
			handleResult.Track.ProviderID = p.extension.ID
		}
		for i := range handleResult.Tracks {
			handleResult.Tracks[i].ProviderID = p.extension.ID
		}
		if handleResult.Album != nil {
			handleResult.Album.ProviderID = p.extension.ID
			for i := range handleResult.Album.Tracks {
				handleResult.Album.Tracks[i].ProviderID = p.extension.ID
			}
		}
		if handleResult.Artist != nil {
			handleResult.Artist.ProviderID = p.extension.ID
			for i := range handleResult.Artist.Albums {
				handleResult.Artist.Albums[i].ProviderID = p.extension.ID
				for j := range handleResult.Artist.Albums[i].Tracks {
					handleResult.Artist.Albums[i].Tracks[j].ProviderID = p.extension.ID
				}
			}
			for i := range handleResult.Artist.Releases {
				handleResult.Artist.Releases[i].ProviderID = p.extension.ID
				for j := range handleResult.Artist.Releases[i].Tracks {
					handleResult.Artist.Releases[i].Tracks[j].ProviderID = p.extension.ID
				}
			}
			for i := range handleResult.Artist.TopTracks {
				handleResult.Artist.TopTracks[i].ProviderID = p.extension.ID
			}
		}

		return &handleResult, nil
	})
}

type PostProcessResult struct {
	Success     bool   `json:"success"`
	NewFilePath string `json:"new_file_path,omitempty"`
	NewFileURI  string `json:"new_file_uri,omitempty"`
	Error       string `json:"error,omitempty"`
	BitDepth    int    `json:"bit_depth,omitempty"`
	SampleRate  int    `json:"sample_rate,omitempty"`
}

type PostProcessInput struct {
	Path     string `json:"path,omitempty"`
	URI      string `json:"uri,omitempty"`
	Name     string `json:"name,omitempty"`
	MimeType string `json:"mime_type,omitempty"`
	Size     int64  `json:"size,omitempty"`
	IsSAF    bool   `json:"is_saf,omitempty"`
}

const PostProcessTimeout = 2 * time.Minute

// postProcessCommon backs both PostProcess (V1) and PostProcessV2. V1 probes
// only extension.postProcess (its original contract: V2-only extensions are
// not invoked via V1); V2 probes postProcessV2 first, then falls back to
// postProcess.
func (p *extensionProviderWrapper) postProcessCommon(input PostProcessInput, metadata map[string]any, hookID string, preferV2 bool) (*PostProcessResult, error) {
	if !p.extension.Manifest.HasPostProcessing() {
		return nil, fmt.Errorf("extension '%s' does not support post-processing", p.extension.ID)
	}
	if !p.extension.Enabled {
		return nil, fmt.Errorf("extension '%s' is disabled", p.extension.ID)
	}

	metadataJSON, _ := json.Marshal(metadata)
	inputJSON, _ := json.Marshal(input)
	filePath := input.Path

	perfName := "postProcess"
	var script string
	if preferV2 {
		perfName = "postProcessV2"
		script = fmt.Sprintf(`
			(function() {
				if (typeof extension !== 'undefined') {
					if (typeof extension.postProcessV2 === 'function') {
						return extension.postProcessV2(%s, %s, %q);
					}
					if (typeof extension.postProcess === 'function') {
						return extension.postProcess(%q, %s, %q);
					}
				}
				return null;
			})()
		`, string(inputJSON), string(metadataJSON), hookID, filePath, string(metadataJSON), hookID)
	} else {
		script = fmt.Sprintf(`
			(function() {
				if (typeof extension !== 'undefined' && typeof extension.postProcess === 'function') {
					return extension.postProcess(%q, %s, %q);
				}
				return null;
			})()
		`, filePath, string(metadataJSON), hookID)
	}

	result, err := callExtensionScript(p, extCallOpts{
		perfName:       perfName,
		script:         script,
		timeout:        PostProcessTimeout,
		timeoutMessage: "postProcess timeout: extension took too long to complete",
		rawError:       true,
	}, func(perf *extensionCallPerf, value goja.Value) (*PostProcessResult, error) {
		if value == nil || goja.IsUndefined(value) || goja.IsNull(value) {
			return &PostProcessResult{Success: false, Error: "postProcess returned null"}, nil
		}
		parseStartedAt := time.Now()
		postResult := parseExtensionPostProcessValue(p.vm, value)
		perf.recordParse(time.Since(parseStartedAt))
		perf.setItems(1)
		return &postResult, nil
	})
	if err != nil {
		return &PostProcessResult{Success: false, Error: err.Error()}, nil
	}
	return result, nil
}

func (p *extensionProviderWrapper) PostProcess(filePath string, metadata map[string]any, hookID string) (*PostProcessResult, error) {
	return p.postProcessCommon(PostProcessInput{Path: filePath}, metadata, hookID, false)
}

func (p *extensionProviderWrapper) PostProcessV2(input PostProcessInput, metadata map[string]any, hookID string) (*PostProcessResult, error) {
	return p.postProcessCommon(input, metadata, hookID, true)
}

type ExtLyricsResult struct {
	Lines        []ExtLyricsLine `json:"lines"`
	SyncType     string          `json:"syncType"`
	Instrumental bool            `json:"instrumental"`
	PlainLyrics  string          `json:"plainLyrics"`
	Provider     string          `json:"provider"`
}

type ExtLyricsLine struct {
	StartTimeMs int64  `json:"startTimeMs"`
	Words       string `json:"words"`
	EndTimeMs   int64  `json:"endTimeMs"`
}

func (p *extensionProviderWrapper) FetchLyrics(trackName, artistName, albumName string, durationSec float64) (*LyricsResponse, error) {
	if !p.extension.Manifest.IsLyricsProvider() {
		return nil, fmt.Errorf("extension '%s' is not a lyrics provider", p.extension.ID)
	}
	if !p.extension.Enabled {
		return nil, fmt.Errorf("extension '%s' is disabled", p.extension.ID)
	}

	// Use global variables to avoid JS injection issues with special characters in track/artist names
	const trackVar = "__sf_lyrics_track"
	const artistVar = "__sf_lyrics_artist"
	const albumVar = "__sf_lyrics_album"
	const durationVar = "__sf_lyrics_duration"

	const script = `
		(function() {
			if (typeof extension !== 'undefined' && typeof extension.fetchLyrics === 'function') {
				return extension.fetchLyrics(__sf_lyrics_track, __sf_lyrics_artist, __sf_lyrics_album, __sf_lyrics_duration);
			}
			return null;
		})()
	`

	return callExtensionScript(p, extCallOpts{
		perfName: "fetchLyrics",
		script:   script,
		timeout:  DefaultJSTimeout,
		beforeRun: func() func() {
			global := p.vm.GlobalObject()
			_ = global.Set(trackVar, trackName)
			_ = global.Set(artistVar, artistName)
			_ = global.Set(albumVar, albumName)
			_ = global.Set(durationVar, durationSec)
			return func() {
				global.Delete(trackVar)
				global.Delete(artistVar)
				global.Delete(albumVar)
				global.Delete(durationVar)
			}
		},
	}, func(perf *extensionCallPerf, result goja.Value) (*LyricsResponse, error) {
		if result == nil || goja.IsUndefined(result) || goja.IsNull(result) {
			return nil, fmt.Errorf("fetchLyrics returned null")
		}
		parseStartedAt := time.Now()
		extResult, err := parseExtensionLyricsValue(p.vm, result)
		perf.recordParse(time.Since(parseStartedAt))
		if err != nil {
			return nil, fmt.Errorf("failed to parse lyrics result: %w", err)
		}
		perf.setItems(len(extResult.Lines))

		response := &LyricsResponse{
			SyncType:     extResult.SyncType,
			Instrumental: extResult.Instrumental,
			PlainLyrics:  extResult.PlainLyrics,
			Provider:     extResult.Provider,
			Source:       "Extension: " + p.extension.ID,
		}

		if response.Provider == "" {
			response.Provider = p.extension.Manifest.DisplayName
		}

		for _, line := range extResult.Lines {
			response.Lines = append(response.Lines, LyricsLine(line))
		}

		if len(response.Lines) == 0 && response.PlainLyrics != "" && !response.Instrumental {
			response.SyncType = "UNSYNCED"
			for _, line := range strings.Split(response.PlainLyrics, "\n") {
				if strings.TrimSpace(line) != "" {
					response.Lines = append(response.Lines, LyricsLine{
						StartTimeMs: 0,
						Words:       line,
						EndTimeMs:   0,
					})
				}
			}
		}

		return response, nil
	})
}
