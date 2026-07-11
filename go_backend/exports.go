package gobackend

import (
	"encoding/json"
	"strings"
)

func CheckAvailability(spotifyID, isrc string) (string, error) {
	client := NewSongLinkClient()
	availability, err := client.CheckTrackAvailability(spotifyID, isrc)
	if err != nil {
		return "", err
	}

	return marshalJSONString(availability)
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
