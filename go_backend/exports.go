package gobackend

import (
	"encoding/json"
	"runtime/debug"
	"strings"
	"sync"
)

var (
	metadataLanguageMu  sync.RWMutex
	metadataLanguageTag string
)

// SetMetadataLanguage sets the app's display language (BCP 47 tag, e.g.
// "en-US" or "id"), used as Accept-Language on metadata API requests so
// providers localize names by the app language instead of IP geolocation.
func SetMetadataLanguage(tag string) {
	metadataLanguageMu.Lock()
	metadataLanguageTag = strings.TrimSpace(tag)
	metadataLanguageMu.Unlock()
}

func metadataAcceptLanguage() string {
	metadataLanguageMu.RLock()
	tag := metadataLanguageTag
	metadataLanguageMu.RUnlock()
	if tag == "" || strings.HasPrefix(strings.ToLower(tag), "en") {
		return "en-US,en;q=0.9"
	}
	return tag + ",en;q=0.8"
}

// ReleaseMemory drops idle pooled extension runtimes, forces a GC, and
// returns freed heap to the OS. Called from the app on OS memory pressure and
// when backgrounded, so the Go side's RSS doesn't sit at its high-water mark
// after large downloads/tag writes.
func ReleaseMemory() {
	drainAllIsolatedRuntimePools()
	debug.FreeOSMemory()
}

// SetSongLinkNetworkOptions is kept for backward compatibility.
func SetSongLinkNetworkOptions(allowHTTP, insecureTLS bool) {
	SetNetworkCompatibilityOptions(allowHTTP, insecureTLS)
}

func SetDownloadDirectory(path string) error {
	return setDownloadDir(path)
}

func AllowDownloadDir(path string) {
	if strings.TrimSpace(path) == "" {
		return
	}
	AddAllowedDownloadDir(path)
}

func CheckDuplicate(outputDir, isrc string) (string, error) {
	existingFile, exists := CheckISRCExists(outputDir, isrc)

	result := map[string]any{
		"exists":   exists,
		"filepath": existingFile,
	}

	return marshalJSONString(result)
}

func CheckDuplicatesBatch(outputDir, tracksJSON string) (string, error) {
	return CheckFilesExistParallel(outputDir, tracksJSON)
}

func PreBuildDuplicateIndex(outputDir string) error {
	return PreBuildISRCIndex(outputDir)
}

func InvalidateDuplicateIndex(outputDir string) {
	InvalidateISRCCache(outputDir)
}

func BuildFilename(template string, metadataJSON string) (string, error) {
	var metadata map[string]any
	if err := json.Unmarshal([]byte(metadataJSON), &metadata); err != nil {
		return "", err
	}

	filename := buildFilenameFromTemplate(template, metadata)
	return filename, nil
}

func SanitizeFilename(filename string) string {
	return sanitizeFilename(filename)
}
