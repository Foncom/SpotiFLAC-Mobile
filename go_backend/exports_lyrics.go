package gobackend

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"
)

func FetchLyrics(spotifyID, trackName, artistName string, durationMs int64) (string, error) {
	client := NewLyricsClient()
	durationSec := float64(durationMs) / 1000.0
	lyrics, err := client.FetchLyricsAllSources(spotifyID, trackName, artistName, durationSec)
	if err != nil {
		return "", err
	}

	result := map[string]any{
		"success":      true,
		"source":       lyrics.Source,
		"sync_type":    lyrics.SyncType,
		"lines":        lyrics.Lines,
		"instrumental": lyrics.Instrumental,
	}

	jsonBytes, err := json.Marshal(result)
	if err != nil {
		return "", err
	}

	return string(jsonBytes), nil
}

func GetLyricsLRC(spotifyID, trackName, artistName string, filePath string, durationMs int64) (string, error) {
	if filePath != "" {
		lyrics, err := ExtractLyrics(filePath)
		if err == nil && lyrics != "" {
			return lyrics, nil
		}
		return "", nil
	}

	client := NewLyricsClient()
	durationSec := float64(durationMs) / 1000.0
	lyricsData, err := client.FetchLyricsAllSources(spotifyID, trackName, artistName, durationSec)
	if err != nil {
		return "", err
	}

	if lyricsData.Instrumental {
		return "[instrumental:true]", nil
	}

	lrcContent := convertToLRCWithMetadata(lyricsData, trackName, artistName)
	return lrcContent, nil
}

func GetLyricsLRCWithSource(spotifyID, trackName, artistName string, filePath string, durationMs int64) (string, error) {
	if filePath != "" {
		lyrics, err := ExtractLyrics(filePath)
		if err == nil && lyrics != "" {
			source := extractLyricsSourceFromLRC(lyrics)
			if source == "" {
				source = "Embedded"
			}
			result := map[string]any{
				"lyrics":       lyrics,
				"source":       source,
				"sync_type":    "EMBEDDED",
				"instrumental": false,
			}
			jsonBytes, err := json.Marshal(result)
			if err != nil {
				return "", err
			}
			return string(jsonBytes), nil
		}

		result := map[string]any{
			"lyrics":       "",
			"source":       "",
			"sync_type":    "",
			"instrumental": false,
		}
		jsonBytes, err := json.Marshal(result)
		if err != nil {
			return "", err
		}
		return string(jsonBytes), nil
	}

	client := NewLyricsClient()
	durationSec := float64(durationMs) / 1000.0
	lyricsData, err := client.FetchLyricsAllSources(spotifyID, trackName, artistName, durationSec)
	if err != nil {
		return "", err
	}

	lrcContent := ""
	if lyricsData.Instrumental {
		lrcContent = "[instrumental:true]"
	} else {
		lrcContent = convertToLRCWithMetadata(lyricsData, trackName, artistName)
	}

	result := map[string]any{
		"lyrics":       lrcContent,
		"source":       lyricsData.Source,
		"sync_type":    lyricsData.SyncType,
		"instrumental": lyricsData.Instrumental,
	}
	jsonBytes, err := json.Marshal(result)
	if err != nil {
		return "", err
	}

	return string(jsonBytes), nil
}

func EmbedLyricsToFile(filePath, lyrics string) (string, error) {
	err := EmbedLyrics(filePath, lyrics)
	if err != nil {
		return errorResponse("Failed to embed lyrics: " + err.Error())
	}

	resp := map[string]any{
		"success": true,
		"message": "Lyrics embedded successfully",
	}

	jsonBytes, _ := json.Marshal(resp)
	return string(jsonBytes), nil
}

func FetchAndSaveLyrics(trackName, artistName, spotifyID string, durationMs int64, outputPath string, audioFilePath string) error {
	// If the audio file already has embedded lyrics or a sidecar .lrc,
	// use those directly instead of making redundant network requests.
	if audioFilePath != "" {
		existing, err := ExtractLyrics(audioFilePath)
		if err == nil && strings.TrimSpace(existing) != "" {
			if err := os.WriteFile(outputPath, []byte(existing), 0644); err != nil {
				return fmt.Errorf("failed to write LRC file: %w", err)
			}
			GoLog("[Lyrics] Saved LRC from embedded/sidecar to: %s\n", outputPath)
			return nil
		}
	}

	client := NewLyricsClient()
	durationSec := float64(durationMs) / 1000.0

	lyrics, err := client.FetchLyricsAllSources(spotifyID, trackName, artistName, durationSec)
	if err != nil {
		return fmt.Errorf("lyrics not found: %w", err)
	}

	if lyrics.Instrumental {
		return fmt.Errorf("track is instrumental, no lyrics available")
	}

	lrcContent := convertToLRCWithMetadata(lyrics, trackName, artistName)
	if lrcContent == "" {
		return fmt.Errorf("failed to generate LRC content")
	}

	if err := os.WriteFile(outputPath, []byte(lrcContent), 0644); err != nil {
		return fmt.Errorf("failed to write LRC file: %w", err)
	}

	GoLog("[Lyrics] Saved LRC to: %s (%d lines)\n", outputPath, len(lyrics.Lines))
	return nil
}

func SetLyricsProvidersJSON(providersJSON string) error {
	var providers []string
	if err := json.Unmarshal([]byte(providersJSON), &providers); err != nil {
		return err
	}

	SetLyricsProviderOrder(providers)
	return nil
}

func GetLyricsProvidersJSON() (string, error) {
	providers := GetLyricsProviderOrder()
	jsonBytes, err := json.Marshal(providers)
	if err != nil {
		return "", err
	}
	return string(jsonBytes), nil
}

func GetAvailableLyricsProvidersJSON() (string, error) {
	providers := GetAvailableLyricsProviders()
	jsonBytes, err := json.Marshal(providers)
	if err != nil {
		return "", err
	}
	return string(jsonBytes), nil
}

func SetLyricsFetchOptionsJSON(optionsJSON string) error {
	opts := GetLyricsFetchOptions()
	if strings.TrimSpace(optionsJSON) != "" {
		if err := json.Unmarshal([]byte(optionsJSON), &opts); err != nil {
			return err
		}
	}

	SetLyricsFetchOptions(opts)
	return nil
}

func GetLyricsFetchOptionsJSON() (string, error) {
	opts := GetLyricsFetchOptions()
	jsonBytes, err := json.Marshal(opts)
	if err != nil {
		return "", err
	}
	return string(jsonBytes), nil
}
