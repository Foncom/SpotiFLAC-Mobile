package gobackend

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

func manifestCapabilityStringList(manifest *ExtensionManifest, key string) []string {
	if manifest == nil || manifest.Capabilities == nil {
		return nil
	}

	raw, ok := manifest.Capabilities[key]
	if !ok {
		return nil
	}

	values, ok := raw.([]any)
	if !ok {
		return nil
	}

	result := make([]string, 0, len(values))
	for _, value := range values {
		str, ok := value.(string)
		if !ok {
			continue
		}
		trimmed := strings.ToLower(strings.TrimSpace(str))
		if trimmed == "" {
			continue
		}
		result = append(result, trimmed)
	}
	return result
}

func extensionReplacesBuiltInProvider(ext *loadedExtension, providerID string) bool {
	if ext == nil {
		return false
	}

	normalized := strings.ToLower(strings.TrimSpace(providerID))
	if normalized == "" {
		return false
	}

	for _, replaced := range manifestCapabilityStringList(ext.Manifest, "replacesBuiltInProviders") {
		if replaced == normalized {
			return true
		}
	}

	return false
}

func trimKnownProviderPrefix(trackID, providerID string) string {
	trimmedID := strings.TrimSpace(trackID)
	normalizedProvider := strings.ToLower(strings.TrimSpace(providerID))
	if trimmedID == "" || normalizedProvider == "" {
		return trimmedID
	}

	prefix := normalizedProvider + ":"
	if strings.HasPrefix(strings.ToLower(trimmedID), prefix) {
		return trimmedID[len(prefix):]
	}

	return trimmedID
}

func resolvePreferredTrackIDForExtension(ext *loadedExtension, req DownloadRequest, explicitTrackID string) string {
	candidates := make([]string, 0, 8)
	appendCandidate := func(value string) {
		trimmed := strings.TrimSpace(value)
		if trimmed == "" {
			return
		}
		for _, existing := range candidates {
			if existing == trimmed {
				return
			}
		}
		candidates = append(candidates, trimmed)
	}

	appendCandidate(explicitTrackID)

	if extensionReplacesBuiltInProvider(ext, "tidal") {
		appendCandidate(req.TidalID)
		appendCandidate(trimKnownProviderPrefix(req.SpotifyID, "tidal"))
	}
	if extensionReplacesBuiltInProvider(ext, "qobuz") {
		appendCandidate(req.QobuzID)
		appendCandidate(trimKnownProviderPrefix(req.SpotifyID, "qobuz"))
	}
	if extensionReplacesBuiltInProvider(ext, "deezer") {
		appendCandidate(req.DeezerID)
		appendCandidate(trimKnownProviderPrefix(req.SpotifyID, "deezer"))
	}
	if extensionReplacesBuiltInProvider(ext, "spotify") {
		appendCandidate(trimKnownProviderPrefix(req.SpotifyID, "spotify"))
		appendCandidate(req.SpotifyID)
	}

	appendCandidate(req.SpotifyID)
	appendCandidate(req.TidalID)
	appendCandidate(req.QobuzID)
	appendCandidate(req.DeezerID)

	if len(candidates) == 0 {
		return ""
	}
	return candidates[0]
}

func normalizeDownloadResultExtension(candidates ...string) string {
	for _, candidate := range candidates {
		ext := strings.TrimSpace(strings.ToLower(candidate))
		if ext == "" {
			continue
		}
		if !strings.HasPrefix(ext, ".") {
			ext = "." + ext
		}
		if ext == ".mp4" {
			return ".m4a"
		}
		return ext
	}
	return ""
}

func normalizeExtensionDownloadResult(result *ExtDownloadResult) (DownloadResult, bool) {
	if result == nil {
		return DownloadResult{}, false
	}

	downloadResult := DownloadResult{
		FilePath:                    strings.TrimSpace(result.FilePath),
		BitDepth:                    result.BitDepth,
		SampleRate:                  result.SampleRate,
		AudioCodec:                  strings.TrimSpace(result.AudioCodec),
		Title:                       result.Title,
		Artist:                      result.Artist,
		Album:                       result.Album,
		ReleaseDate:                 result.ReleaseDate,
		TrackNumber:                 result.TrackNumber,
		TotalTracks:                 result.TotalTracks,
		DiscNumber:                  result.DiscNumber,
		TotalDiscs:                  result.TotalDiscs,
		ISRC:                        result.ISRC,
		CoverURL:                    result.CoverURL,
		Genre:                       result.Genre,
		Label:                       result.Label,
		Copyright:                   result.Copyright,
		Composer:                    result.Composer,
		LyricsLRC:                   result.LyricsLRC,
		DecryptionKey:               result.DecryptionKey,
		Decryption:                  normalizeDownloadDecryptionInfo(result.Decryption, result.DecryptionKey),
		ActualExtension:             normalizeDownloadResultExtension(result.ActualExtension, result.OutputExtension),
		ActualContainer:             strings.TrimSpace(result.ActualContainer),
		RequiresContainerConversion: result.RequiresContainerConversion,
	}

	alreadyExists := result.AlreadyExists
	if strings.HasPrefix(downloadResult.FilePath, "EXISTS:") {
		alreadyExists = true
		downloadResult.FilePath = strings.TrimPrefix(downloadResult.FilePath, "EXISTS:")
	}

	enrichResultQualityFromFile(&downloadResult)
	return downloadResult, alreadyExists
}

// overlayStr sets *dst = src when dst is empty and src is not. If field is
// non-empty it logs "<field> from enrichment: <src>" on overlay.
func overlayStr(dst *string, src, field string) {
	if src == "" || *dst != "" {
		return
	}
	*dst = src
	if field != "" {
		GoLog("[DownloadWithExtensionFallback] %s from enrichment: %s\n", field, src)
	}
}

// overlayStrTrim is overlayStr but treats a whitespace-only dst as empty too.
func overlayStrTrim(dst *string, src string) {
	if src == "" || strings.TrimSpace(*dst) != "" {
		return
	}
	*dst = src
}

// overlayInt sets *dst = src when dst is zero and src is positive. If field is
// non-empty it logs "<field> from enrichment: <src>" on overlay.
func overlayInt(dst *int, src int, field string) {
	if src <= 0 || *dst != 0 {
		return
	}
	*dst = src
	if field != "" {
		GoLog("[DownloadWithExtensionFallback] %s from enrichment: %d\n", field, src)
	}
}

func overlayExtensionDownloadMetadata(resp *DownloadResponse, result *ExtDownloadResult) {
	if resp == nil || result == nil {
		return
	}

	overlayStrTrim(&resp.Title, result.Title)
	overlayStrTrim(&resp.Artist, result.Artist)
	overlayStrTrim(&resp.Album, result.Album)
	overlayStrTrim(&resp.AlbumArtist, result.AlbumArtist)
	overlayInt(&resp.TrackNumber, result.TrackNumber, "")
	overlayInt(&resp.DiscNumber, result.DiscNumber, "")
	overlayInt(&resp.TotalTracks, result.TotalTracks, "")
	overlayInt(&resp.TotalDiscs, result.TotalDiscs, "")
	overlayStrTrim(&resp.ReleaseDate, result.ReleaseDate)
	overlayStrTrim(&resp.CoverURL, result.CoverURL)
	overlayStrTrim(&resp.ISRC, result.ISRC)
	overlayStrTrim(&resp.Genre, result.Genre)
	overlayStrTrim(&resp.Label, result.Label)
	overlayStrTrim(&resp.Copyright, result.Copyright)
	overlayStrTrim(&resp.Composer, result.Composer)
	if result.LyricsLRC != "" {
		resp.LyricsLRC = result.LyricsLRC
	}
	if result.DecryptionKey != "" {
		resp.DecryptionKey = result.DecryptionKey
	}
	if normalized := normalizeDownloadDecryptionInfo(result.Decryption, result.DecryptionKey); normalized != nil {
		resp.Decryption = normalized
	}
	if ext := normalizeDownloadResultExtension(result.ActualExtension, result.OutputExtension); ext != "" {
		resp.ActualExtension = ext
	}
	if container := strings.TrimSpace(result.ActualContainer); container != "" {
		resp.ActualContainer = container
	}
	if result.RequiresContainerConversion {
		resp.RequiresContainerConversion = true
	}
}

func applyExtensionRequestFallbacks(resp *DownloadResponse, req DownloadRequest) {
	if resp == nil {
		return
	}

	overlayStr(&resp.Album, req.AlbumName, "")
	overlayStr(&resp.AlbumArtist, req.AlbumArtist, "")
	overlayStr(&resp.ReleaseDate, req.ReleaseDate, "")
	overlayStr(&resp.ISRC, req.ISRC, "")
	overlayInt(&resp.TrackNumber, req.TrackNumber, "")
	overlayInt(&resp.TotalTracks, req.TotalTracks, "")
	overlayInt(&resp.DiscNumber, req.DiscNumber, "")
	overlayInt(&resp.TotalDiscs, req.TotalDiscs, "")
	overlayStr(&resp.CoverURL, req.CoverURL, "")
}

func shouldStopProviderFallback(availability *ExtAvailabilityResult) bool {
	return availability != nil && availability.SkipFallback
}

func fallbackRuntimeHealthStatus(ext *loadedExtension) string {
	if ext == nil || ext.Manifest == nil || len(ext.Manifest.ServiceHealth) == 0 {
		return "unknown"
	}

	status := strings.ToLower(strings.TrimSpace(CheckExtensionHealthCached(ext).Status))
	switch status {
	case "online", "degraded", "offline":
		return status
	default:
		return "unknown"
	}
}

func prioritizeFallbackProvidersByHealth(priority []string, extManager *extensionManager, sourceProvider string) []string {
	if len(priority) == 0 || extManager == nil {
		return priority
	}

	online := make([]string, 0, len(priority))
	degraded := make([]string, 0, len(priority))
	unknown := make([]string, 0, len(priority))

	for _, rawProviderID := range priority {
		providerID := strings.TrimSpace(rawProviderID)
		if providerID == "" {
			continue
		}
		if strings.EqualFold(providerID, sourceProvider) || !isExtensionFallbackAllowed(providerID) {
			unknown = append(unknown, providerID)
			continue
		}

		ext, err := extManager.GetExtension(providerID)
		if err != nil || ext == nil || !ext.Enabled || ext.Error != "" || ext.Manifest == nil || !ext.Manifest.IsDownloadProvider() {
			unknown = append(unknown, providerID)
			continue
		}

		switch fallbackRuntimeHealthStatus(ext) {
		case "online":
			online = append(online, providerID)
		case "degraded":
			degraded = append(degraded, providerID)
		case "offline":
			GoLog("[DownloadWithExtensionFallback] Skipping extension provider %s (service health offline)\n", providerID)
		default:
			unknown = append(unknown, providerID)
		}
	}

	result := make([]string, 0, len(online)+len(degraded)+len(unknown))
	result = append(result, online...)
	result = append(result, degraded...)
	result = append(result, unknown...)
	return result
}

func resolveExtensionAvailabilityReason(availability *ExtAvailabilityResult, err error) string {
	if availability != nil {
		if reason := strings.TrimSpace(availability.Reason); reason != "" {
			return reason
		}
	}
	if err != nil {
		return err.Error()
	}
	return "extension requested no further fallback"
}

func buildExtensionFallbackStoppedResponse(providerID string, availability *ExtAvailabilityResult, err error) *DownloadResponse {
	reason := resolveExtensionAvailabilityReason(availability, err)
	errorType := classifyDownloadErrorType(reason)
	if errorType == "unknown" {
		errorType = "extension_error"
	}
	return &DownloadResponse{
		Success:   false,
		Error:     fmt.Sprintf("Fallback stopped by %s: %s", providerID, reason),
		ErrorType: errorType,
		Service:   providerID,
	}
}

func shouldAbortCancelledFallback(itemID string, err error) bool {
	if errors.Is(err, ErrDownloadCancelled) {
		return true
	}
	return itemID != "" && isDownloadCancelled(itemID)
}

func normalizeExtensionDownloadErrorType(errorType, message string) string {
	normalized := strings.TrimSpace(errorType)
	classified := classifyDownloadErrorType(message)
	if classified != "" && classified != "unknown" {
		switch strings.ToLower(normalized) {
		case "", "unknown", "runtime_error", "api_error", "download_error", "extension_error":
			return classified
		}
	}
	return normalized
}

// attemptExtensionDownload runs a single provider.Download attempt: builds the
// output path, reports progress, and on success assembles the full
// DownloadResponse (overlay, request fallbacks, optional title/artist/composer
// fallback, metadata embed, ISRC index). On failure it writes into
// lastErr/lastErrType/lastRetryAfterSeconds exactly as the inline code did
// (leaving them untouched when neither branch applies) so callers can keep
// their own verification_required/stop-fallback handling and error messages.
// cancelledOuter true means the caller must return (nil, ErrDownloadCancelled).
func attemptExtensionDownload(
	req DownloadRequest,
	ext *loadedExtension,
	provider *extensionProviderWrapper,
	trackID, quality, providerLabel string,
	applyTitleFallback bool,
	lastErr *error,
	lastErrType *string,
	lastRetryAfterSeconds *int,
) (resp *DownloadResponse, cancelledOuter bool) {
	outputPath := buildOutputPathForExtension(req, ext)
	if req.ItemID != "" {
		StartItemProgress(req.ItemID)
	}

	result, err := provider.Download(trackID, quality, outputPath, req.ItemID, func(percent int) {
		if req.ItemID != "" {
			normalized := float64(percent) / 100.0
			if normalized < 0 {
				normalized = 0
			}
			if normalized > 1 {
				normalized = 1
			}
			SetItemProgress(req.ItemID, normalized, 0, 0)
		}
	})
	if req.ItemID != "" {
		if err == nil && result != nil && result.Success {
			CompleteItemProgress(req.ItemID)
		} else {
			RemoveItemProgress(req.ItemID)
		}
	}
	if shouldAbortCancelledFallback(req.ItemID, err) {
		return nil, true
	}

	if err == nil && result.Success {
		normalizedResult, alreadyExists := normalizeExtensionDownloadResult(result)
		message := "Downloaded from " + providerLabel
		if alreadyExists {
			message = "File already exists"
		}

		built := buildDownloadSuccessResponse(
			req,
			normalizedResult,
			providerLabel,
			message,
			normalizedResult.FilePath,
			alreadyExists,
		)
		overlayExtensionDownloadMetadata(&built, result)
		if ext.Manifest.SkipMetadataEnrichment {
			built.SkipMetadataEnrichment = true
		}
		applyExtensionRequestFallbacks(&built, req)

		if applyTitleFallback {
			if req.TrackName != "" && built.Title == "" {
				built.Title = req.TrackName
			}
			if req.ArtistName != "" && built.Artist == "" {
				built.Artist = req.ArtistName
			}
			if req.Composer != "" && built.Composer == "" {
				built.Composer = req.Composer
			}
		}

		embedExtensionDownloadMetadata(built, req, alreadyExists)

		if !alreadyExists && !isFDOutput(req.OutputFD) && strings.TrimSpace(req.OutputDir) != "" {
			indexISRC := strings.TrimSpace(built.ISRC)
			if indexISRC == "" {
				indexISRC = strings.TrimSpace(req.ISRC)
			}
			if indexISRC != "" && strings.TrimSpace(built.FilePath) != "" {
				AddToISRCIndex(req.OutputDir, indexISRC, built.FilePath)
			}
		}

		return &built, false
	}

	if err != nil {
		if errors.Is(err, ErrDownloadCancelled) {
			return &DownloadResponse{
				Success:   false,
				Error:     "Download cancelled",
				ErrorType: "cancelled",
				Service:   providerLabel,
			}, false
		}
		*lastErr = err
		*lastErrType = ""
	} else if result.ErrorMessage != "" {
		*lastErr = fmt.Errorf("%s", result.ErrorMessage)
		*lastErrType = normalizeExtensionDownloadErrorType(result.ErrorType, result.ErrorMessage)
		*lastRetryAfterSeconds = result.RetryAfterSeconds
	}
	return nil, false
}

func DownloadWithExtensionFallback(req DownloadRequest) (*DownloadResponse, error) {
	priority := GetProviderPriority()
	extManager := getExtensionManager()
	strictMode := !req.UseFallback
	selectedProvider := strings.TrimSpace(req.Service)

	if isDownloadCancelled(req.ItemID) {
		return nil, ErrDownloadCancelled
	}

	if strictMode {
		if selectedProvider == "" {
			selectedProvider = strings.TrimSpace(req.Source)
		}
		if selectedProvider != "" {
			priority = []string{selectedProvider}
			GoLog("[DownloadWithExtensionFallback] Strict mode enabled, provider locked to: %s\n", selectedProvider)
		}
	}

	if !strictMode && req.Service != "" {
		found := false
		for _, p := range priority {
			if strings.EqualFold(p, req.Service) {
				found = true
				break
			}
		}
		newPriority := []string{req.Service}
		for _, p := range priority {
			if !strings.EqualFold(p, req.Service) {
				newPriority = append(newPriority, p)
			}
		}
		priority = newPriority
		if !found {
			GoLog("[DownloadWithExtensionFallback] Extension service '%s' added to priority front\n", req.Service)
		} else {
			GoLog("[DownloadWithExtensionFallback] Extension service '%s' moved to priority front\n", req.Service)
		}
		GoLog("[DownloadWithExtensionFallback] New priority order: %v\n", priority)
	}

	var lastErr error
	var lastErrType string
	var lastRetryAfterSeconds int
	var stopProviderFallback bool
	var sourceExtensionLocked bool
	var sourceExtensionAvailability *ExtAvailabilityResult
	var sourceExtensionTrackID string

	if req.Source != "" && selectedProvider != req.Source {
		ext, err := extManager.GetExtension(req.Source)
		if err == nil && ext.Enabled && ext.Error == "" && ext.Manifest.IsDownloadProvider() {
			provider := newExtensionProviderWrapper(ext)
			availability, availErr := provider.CheckAvailabilityForItemID(req.ISRC, req.TrackName, req.ArtistName, req.SpotifyID, req.DeezerID, req.TidalID, req.QobuzID, req.DurationMS, req.ItemID)
			if shouldAbortCancelledFallback(req.ItemID, availErr) {
				return nil, ErrDownloadCancelled
			}
			if availErr != nil {
				GoLog("[DownloadWithExtensionFallback] Source extension %s preflight failed (non-fatal): %v\n", req.Source, availErr)
			} else if shouldStopProviderFallback(availability) {
				sourceExtensionLocked = true
				sourceExtensionAvailability = availability
				sourceExtensionTrackID = strings.TrimSpace(availability.TrackID)
				selectedProvider = req.Source
				GoLog("[DownloadWithExtensionFallback] Source extension %s requested skip_fallback (available=%v), locking download to source extension\n", req.Source, availability.Available)
			}
		}
	}

	if req.Source != "" {
		ext, err := extManager.GetExtension(req.Source)
		if err == nil && ext.Enabled && ext.Error == "" && ext.Manifest.IsMetadataProvider() {
			GoLog("[DownloadWithExtensionFallback] Enriching track from extension '%s'...\n", req.Source)

			provider := newExtensionProviderWrapper(ext)
			trackMeta := &ExtTrackMetadata{
				ID:          req.SpotifyID,
				Name:        req.TrackName,
				Artists:     req.ArtistName,
				AlbumName:   req.AlbumName,
				DurationMS:  req.DurationMS,
				ISRC:        req.ISRC,
				ReleaseDate: req.ReleaseDate,
				TrackNumber: req.TrackNumber,
				TotalTracks: req.TotalTracks,
				DiscNumber:  req.DiscNumber,
				TotalDiscs:  req.TotalDiscs,
				ProviderID:  req.Source,
				Composer:    req.Composer,
			}

			enrichedTrack, err := provider.EnrichTrackForItemID(trackMeta, req.ItemID)
			if shouldAbortCancelledFallback(req.ItemID, err) {
				return nil, ErrDownloadCancelled
			}
			if err == nil && enrichedTrack != nil {
				if enrichedTrack.ISRC != "" && enrichedTrack.ISRC != req.ISRC {
					GoLog("[DownloadWithExtensionFallback] ISRC enriched: %s -> %s\n", req.ISRC, enrichedTrack.ISRC)
					req.ISRC = enrichedTrack.ISRC
				}
				if enrichedTrack.TidalID != "" {
					GoLog("[DownloadWithExtensionFallback] Tidal ID from Odesli: %s\n", enrichedTrack.TidalID)
					req.TidalID = enrichedTrack.TidalID
				}
				if enrichedTrack.QobuzID != "" {
					GoLog("[DownloadWithExtensionFallback] Qobuz ID from Odesli: %s\n", enrichedTrack.QobuzID)
					req.QobuzID = enrichedTrack.QobuzID
				}
				if enrichedTrack.DeezerID != "" {
					GoLog("[DownloadWithExtensionFallback] Deezer ID from Odesli: %s\n", enrichedTrack.DeezerID)
					req.DeezerID = enrichedTrack.DeezerID
				}
				if enrichedTrack.Name != "" {
					req.TrackName = enrichedTrack.Name
				}
				if enrichedTrack.Artists != "" {
					req.ArtistName = enrichedTrack.Artists
				}
				overlayStr(&req.AlbumName, enrichedTrack.AlbumName, "AlbumName")
				overlayStr(&req.AlbumArtist, enrichedTrack.AlbumArtist, "")
				overlayInt(&req.DurationMS, enrichedTrack.DurationMS, "DurationMS")
				overlayStr(&req.CoverURL, enrichedTrack.CoverURL, "")
				overlayStr(&req.SpotifyID, enrichedTrack.ID, "Track ID")
				overlayStr(&req.Label, enrichedTrack.Label, "Label")
				overlayStr(&req.Copyright, enrichedTrack.Copyright, "Copyright")
				overlayStr(&req.Genre, enrichedTrack.Genre, "Genre")
				overlayStr(&req.ReleaseDate, enrichedTrack.ReleaseDate, "ReleaseDate")
				overlayInt(&req.TrackNumber, enrichedTrack.TrackNumber, "TrackNumber")
				overlayInt(&req.TotalTracks, enrichedTrack.TotalTracks, "TotalTracks")
				overlayInt(&req.DiscNumber, enrichedTrack.DiscNumber, "DiscNumber")
				overlayInt(&req.TotalDiscs, enrichedTrack.TotalDiscs, "TotalDiscs")
				overlayStr(&req.Composer, enrichedTrack.Composer, "Composer")
			}
		}
	}

	if req.Source != "" &&
		req.TrackName != "" && req.ArtistName != "" &&
		(req.AlbumName == "" || req.ReleaseDate == "" || req.ISRC == "") {

		searchQuery := req.TrackName + " " + req.ArtistName
		GoLog("[DownloadWithExtensionFallback] Metadata incomplete, searching providers for: %s\n", searchQuery)

		tracks, searchErr := extManager.SearchTracksWithMetadataProvidersForItemID(searchQuery, 5, true, req.ItemID)
		if shouldAbortCancelledFallback(req.ItemID, searchErr) {
			return nil, ErrDownloadCancelled
		}
		if searchErr == nil && len(tracks) > 0 {
			track := tracks[0]
			GoLog("[DownloadWithExtensionFallback] Metadata match (%s): %s - %s (album: %s, date: %s, isrc: %s)\n",
				track.ProviderID, track.Name, track.Artists, track.AlbumName, track.ReleaseDate, track.ISRC)

			overlayStr(&req.AlbumName, track.AlbumName, "")
			overlayStr(&req.AlbumArtist, track.AlbumArtist, "")
			overlayStr(&req.ReleaseDate, track.ReleaseDate, "")
			overlayStr(&req.ISRC, track.ISRC, "")
			overlayInt(&req.TrackNumber, track.TrackNumber, "")
			overlayInt(&req.TotalTracks, track.TotalTracks, "")
			overlayInt(&req.DiscNumber, track.DiscNumber, "")
			overlayInt(&req.TotalDiscs, track.TotalDiscs, "")
			overlayStr(&req.Composer, track.Composer, "")
			overlayStr(&req.CoverURL, track.CoverURL, "")
			overlayStr(&req.Genre, track.Genre, "")
			overlayStr(&req.Label, track.Label, "")
			overlayStr(&req.Copyright, track.Copyright, "")
		} else if searchErr != nil {
			GoLog("[DownloadWithExtensionFallback] Metadata provider search failed (non-fatal): %v\n", searchErr)
		}

		if req.ISRC != "" &&
			(req.Genre == "" || req.Label == "" || req.Copyright == "") {
			enrichExtraMetadataByISRC("DownloadWithExtensionFallback", req.ISRC, &req.Genre, &req.Label, &req.Copyright)
			if isDownloadCancelled(req.ItemID) {
				return nil, ErrDownloadCancelled
			}
		}
	}

	if req.Source != "" && selectedProvider == req.Source {
		if isDownloadCancelled(req.ItemID) {
			return nil, ErrDownloadCancelled
		}

		if sourceExtensionLocked && (sourceExtensionAvailability == nil || !sourceExtensionAvailability.Available) {
			GoLog("[DownloadWithExtensionFallback] Source extension %s stopped fallback before download (reason: %s)\n", req.Source, resolveExtensionAvailabilityReason(sourceExtensionAvailability, nil))
			return buildExtensionFallbackStoppedResponse(req.Source, sourceExtensionAvailability, nil), nil
		}

		GoLog("[DownloadWithExtensionFallback] Track source is extension '%s' matching selected provider, trying it first\n", req.Source)

		ext, err := extManager.GetExtension(req.Source)
		if err == nil && ext.Enabled && ext.Error == "" && ext.Manifest.IsDownloadProvider() {
			stopProviderFallback = ext.Manifest.StopsProviderFallback()

			provider := newExtensionProviderWrapper(ext)

			trackID := resolvePreferredTrackIDForExtension(ext, req, sourceExtensionTrackID)

			GoLog("[DownloadWithExtensionFallback] Downloading from source extension with trackID: %s (stopProviderFallback: %v)\n", trackID, stopProviderFallback)

			resp, cancelledOuter := attemptExtensionDownload(req, ext, provider, trackID, req.Quality, req.Source, true, &lastErr, &lastErrType, &lastRetryAfterSeconds)
			if cancelledOuter {
				return nil, ErrDownloadCancelled
			}
			if resp != nil {
				return resp, nil
			}
			GoLog("[DownloadWithExtensionFallback] Source extension %s failed: %v\n", req.Source, lastErr)

			sourceErrType := lastErrType
			if sourceErrType == "" && lastErr != nil {
				sourceErrType = classifyDownloadErrorType(lastErr.Error())
			}
			if strings.EqualFold(sourceErrType, "verification_required") {
				GoLog("[DownloadWithExtensionFallback] Source extension %s requires verification, not trying other providers\n", req.Source)
				return &DownloadResponse{
					Success:   false,
					Error:     "Download failed: " + lastErr.Error(),
					ErrorType: "verification_required",
					Service:   req.Source,
				}, nil
			}

			if stopProviderFallback || sourceExtensionLocked {
				if sourceExtensionLocked {
					GoLog("[DownloadWithExtensionFallback] Source extension %s requested skip_fallback, not trying other providers\n", req.Source)
					return buildExtensionFallbackStoppedResponse(req.Source, sourceExtensionAvailability, lastErr), nil
				}
				GoLog("[DownloadWithExtensionFallback] stopProviderFallback is true, not trying other providers\n")
				return &DownloadResponse{
					Success:           false,
					Error:             "Download failed: " + lastErr.Error(),
					ErrorType:         firstNonEmptyString(lastErrType, "extension_error"),
					RetryAfterSeconds: lastRetryAfterSeconds,
					Service:           req.Source,
				}, nil
			}
		} else {
			GoLog("[DownloadWithExtensionFallback] Source extension %s not available or not a download provider\n", req.Source)
		}
	}

	priority = prioritizeFallbackProvidersByHealth(priority, extManager, req.Source)

	for _, providerID := range priority {
		if isDownloadCancelled(req.ItemID) {
			return nil, ErrDownloadCancelled
		}

		providerID = strings.TrimSpace(providerID)
		if providerID == "" {
			continue
		}
		// Skip the origin extension only when it differs from the explicitly
		// selected provider; otherwise it must still be attempted here.
		if providerID == req.Source && req.Source != selectedProvider {
			continue
		}

		if providerID != selectedProvider && !isExtensionFallbackAllowed(providerID) {
			GoLog("[DownloadWithExtensionFallback] Skipping extension provider %s (not enabled for fallback)\n", providerID)
			continue
		}

		GoLog("[DownloadWithExtensionFallback] Trying provider: %s\n", providerID)

		{
			ext, err := extManager.GetExtension(providerID)
			if err != nil || !ext.Enabled || ext.Error != "" {
				GoLog("[DownloadWithExtensionFallback] Extension %s not available\n", providerID)
				continue
			}

			if !ext.Manifest.IsDownloadProvider() {
				continue
			}

			provider := newExtensionProviderWrapper(ext)

			availability, err := provider.CheckAvailabilityForItemID(req.ISRC, req.TrackName, req.ArtistName, req.SpotifyID, req.DeezerID, req.TidalID, req.QobuzID, req.DurationMS, req.ItemID)
			if shouldAbortCancelledFallback(req.ItemID, err) {
				return nil, ErrDownloadCancelled
			}
			terminalAvailability := shouldStopProviderFallback(availability)
			if err != nil || !availability.Available {
				GoLog("[DownloadWithExtensionFallback] %s: not available\n", providerID)
				if err != nil {
					lastErr = err
					if strings.EqualFold(classifyDownloadErrorType(err.Error()), "verification_required") {
						GoLog("[DownloadWithExtensionFallback] %s requires verification (availability); pausing fallback to open the challenge\n", providerID)
						return &DownloadResponse{
							Success:   false,
							Error:     "Download failed: " + err.Error(),
							ErrorType: "verification_required",
							Service:   providerID,
						}, nil
					}
				}
				if terminalAvailability {
					GoLog("[DownloadWithExtensionFallback] %s requested skip_fallback after availability check\n", providerID)
					return buildExtensionFallbackStoppedResponse(providerID, availability, err), nil
				}
				continue
			}

			req.OutputExt = ""

			// Honor the requested quality when this provider recognizes it
			// (e.g. an explicit user selection). Only when the token is not
			// one of this provider's own options do we fall back to its
			// highest quality, since a source provider's token may not map.
			fallbackQuality := req.Quality
			if len(ext.Manifest.QualityOptions) > 0 {
				requested := strings.TrimSpace(req.Quality)
				recognized := false
				if requested != "" {
					for _, opt := range ext.Manifest.QualityOptions {
						if strings.EqualFold(strings.TrimSpace(opt.ID), requested) {
							recognized = true
							break
						}
					}
				}
				if !recognized {
					if best := strings.TrimSpace(ext.Manifest.QualityOptions[0].ID); best != "" {
						fallbackQuality = best
					}
				}
			}

			resp, cancelledOuter := attemptExtensionDownload(req, ext, provider, availability.TrackID, fallbackQuality, providerID, false, &lastErr, &lastErrType, &lastRetryAfterSeconds)
			if cancelledOuter {
				return nil, ErrDownloadCancelled
			}
			if resp != nil {
				return resp, nil
			}
			GoLog("[DownloadWithExtensionFallback] %s failed: %v\n", providerID, lastErr)

			if lastErr != nil {
				effType := lastErrType
				if effType == "" {
					effType = classifyDownloadErrorType(lastErr.Error())
				}
				if strings.EqualFold(effType, "verification_required") {
					GoLog("[DownloadWithExtensionFallback] %s requires verification; pausing fallback to open the challenge\n", providerID)
					return &DownloadResponse{
						Success:           false,
						Error:             "Download failed: " + lastErr.Error(),
						ErrorType:         "verification_required",
						RetryAfterSeconds: lastRetryAfterSeconds,
						Service:           providerID,
					}, nil
				}
			}

			if terminalAvailability {
				GoLog("[DownloadWithExtensionFallback] %s requested skip_fallback after download failure\n", providerID)
				return buildExtensionFallbackStoppedResponse(providerID, availability, lastErr), nil
			}
		}
	}

	if lastErr != nil {
		errorType := firstNonEmptyString(lastErrType, classifyDownloadErrorType(lastErr.Error()))
		if errorType == "unknown" {
			errorType = "not_found"
		}
		return &DownloadResponse{
			Success:           false,
			Error:             "All providers failed. Last error: " + lastErr.Error(),
			ErrorType:         errorType,
			RetryAfterSeconds: lastRetryAfterSeconds,
		}, nil
	}

	return &DownloadResponse{
		Success:   false,
		Error:     "No extension download providers available",
		ErrorType: "not_found",
	}, nil
}

// buildDownloadFilename renders the sanitized "<name><ext>" filename for req
// from its template/metadata, defaulting to "<artist> - <title>.flac".
func buildDownloadFilename(req DownloadRequest) string {
	metadata := map[string]any{
		"title":             req.TrackName,
		"artist":            req.ArtistName,
		"album":             req.AlbumName,
		"album_artist":      req.AlbumArtist,
		"track":             req.TrackNumber,
		"track_number":      req.TrackNumber,
		"total_tracks":      req.TotalTracks,
		"playlist_position": req.PlaylistPosition,
		"disc":              req.DiscNumber,
		"disc_number":       req.DiscNumber,
		"total_discs":       req.TotalDiscs,
		"year":              extractYear(req.ReleaseDate),
		"date":              req.ReleaseDate,
		"release_date":      req.ReleaseDate,
		"isrc":              req.ISRC,
		"composer":          req.Composer,
	}

	filename := buildFilenameFromTemplate(req.FilenameFormat, metadata)
	if strings.TrimSpace(filename) == "" {
		filename = fmt.Sprintf("%s - %s", req.ArtistName, req.TrackName)
	}
	filename = sanitizeFilename(filename)

	ext := strings.TrimSpace(req.OutputExt)
	if ext == "" {
		ext = ".flac"
	} else if !strings.HasPrefix(ext, ".") {
		ext = "." + ext
	}

	return filename + ext
}

func buildOutputPath(req DownloadRequest) string {
	if strings.TrimSpace(req.OutputPath) != "" {
		return strings.TrimSpace(req.OutputPath)
	}

	outputDir := req.OutputDir
	if strings.TrimSpace(outputDir) == "" {
		outputDir = filepath.Join(os.TempDir(), "spotiflac-downloads")
	}
	os.MkdirAll(outputDir, 0755)
	AddAllowedDownloadDir(outputDir)

	return filepath.Join(outputDir, buildDownloadFilename(req))
}

func buildOutputPathForExtension(req DownloadRequest, ext *loadedExtension) string {
	if strings.TrimSpace(req.OutputPath) != "" {
		outputPath := strings.TrimSpace(req.OutputPath)
		AddAllowedDownloadDir(filepath.Dir(outputPath))
		return outputPath
	}

	// SAF downloads hand extensions a detached output FD owned by the host.
	// Extensions still need a real local temp file so Android can copy it into
	// the target document after provider-specific post-processing completes.
	if !isFDOutput(req.OutputFD) && strings.TrimSpace(req.OutputDir) != "" {
		return buildOutputPath(req)
	}

	tempDir := filepath.Join(ext.DataDir, "downloads")
	os.MkdirAll(tempDir, 0755)
	AddAllowedDownloadDir(tempDir)

	return filepath.Join(tempDir, buildDownloadFilename(req))
}

func canEmbedGenreLabel(filePath string) bool {
	path := strings.TrimSpace(filePath)
	if path == "" || strings.HasPrefix(path, "content://") || strings.HasPrefix(path, "/proc/self/fd/") {
		return false
	}
	if strings.ToLower(filepath.Ext(path)) != ".flac" {
		return false
	}
	if !filepath.IsAbs(path) {
		return false
	}
	info, err := os.Stat(path)
	return err == nil && !info.IsDir() && info.Size() > 0
}

func embedExtensionDownloadMetadata(resp DownloadResponse, req DownloadRequest, alreadyExists bool) {
	if alreadyExists || !req.EmbedMetadata {
		return
	}

	filePath := strings.TrimSpace(resp.FilePath)
	if !canEmbedGenreLabel(filePath) {
		if req.Genre != "" || req.Label != "" || resp.CoverURL != "" || req.CoverURL != "" {
			GoLog("[DownloadWithExtensionFallback] Skipping metadata/cover embed for non-local FLAC output path: %q\n", filePath)
		}
		return
	}

	coverURL := firstNonEmptyTrimmed(resp.CoverURL, req.CoverURL)
	var coverData []byte
	if coverURL != "" {
		data, err := downloadCoverToMemory(coverURL, req.EmbedMaxQualityCover)
		if err != nil {
			GoLog("[DownloadWithExtensionFallback] Warning: failed to download cover for metadata embed: %v\n", err)
		} else if len(data) > 0 {
			coverData = data
		}
	}

	metadata := Metadata{
		Title:         firstNonEmptyTrimmed(resp.Title, req.TrackName),
		Artist:        firstNonEmptyTrimmed(resp.Artist, req.ArtistName),
		Album:         firstNonEmptyTrimmed(resp.Album, req.AlbumName),
		AlbumArtist:   firstNonEmptyTrimmed(resp.AlbumArtist, req.AlbumArtist),
		ArtistTagMode: req.ArtistTagMode,
		Date:          firstNonEmptyTrimmed(resp.ReleaseDate, req.ReleaseDate),
		TrackNumber:   firstPositiveInt(resp.TrackNumber, req.TrackNumber),
		TotalTracks:   firstPositiveInt(resp.TotalTracks, req.TotalTracks),
		DiscNumber:    firstPositiveInt(resp.DiscNumber, req.DiscNumber),
		TotalDiscs:    firstPositiveInt(resp.TotalDiscs, req.TotalDiscs),
		ISRC:          firstNonEmptyTrimmed(resp.ISRC, req.ISRC),
		Genre:         firstNonEmptyTrimmed(resp.Genre, req.Genre),
		Label:         firstNonEmptyTrimmed(resp.Label, req.Label),
		Copyright:     firstNonEmptyTrimmed(resp.Copyright, req.Copyright),
		Composer:      firstNonEmptyTrimmed(resp.Composer, req.Composer),
	}
	if req.EmbedLyrics {
		metadata.Lyrics = resp.LyricsLRC
	}

	var err error
	if len(coverData) > 0 {
		err = EmbedMetadataWithCoverData(filePath, metadata, coverData)
	} else {
		err = EmbedMetadata(filePath, metadata, "")
	}
	if err != nil {
		GoLog("[DownloadWithExtensionFallback] Warning: failed to embed metadata/cover: %v\n", err)
		return
	}

	if len(coverData) > 0 {
		GoLog("[DownloadWithExtensionFallback] Embedded metadata and cover from %q\n", coverURL)
	} else {
		GoLog("[DownloadWithExtensionFallback] Embedded metadata without cover\n")
	}
}

func firstPositiveInt(values ...int) int {
	for _, value := range values {
		if value > 0 {
			return value
		}
	}
	return 0
}
