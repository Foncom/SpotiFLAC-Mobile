package gobackend

import (
	"fmt"
	"net/url"
	"path/filepath"
	"strings"
)

func InitExtensionStoreJSON(cacheDir string) error {
	initExtensionStore(cacheDir)
	return nil
}

func SetStoreRegistryURLJSON(registryURL string) error {
	store := getExtensionStore()
	if store == nil {
		return fmt.Errorf("extension store not initialized")
	}

	resolved, err := resolveRegistryURL(registryURL)
	if err != nil {
		return err
	}

	if err := requireHTTPSURL(resolved, "registry"); err != nil {
		return err
	}

	store.setRegistryURL(resolved)
	return nil
}

func ClearStoreRegistryURLJSON() error {
	store := getExtensionStore()
	if store == nil {
		return fmt.Errorf("extension store not initialized")
	}

	store.setRegistryURL("")
	store.clearCache()
	return nil
}

func GetStoreRegistryURLJSON() (string, error) {
	store := getExtensionStore()
	if store == nil {
		return "", fmt.Errorf("extension store not initialized")
	}

	return store.getRegistryURL(), nil
}

func GetStoreExtensionsJSON(forceRefresh bool) (string, error) {
	store := getExtensionStore()
	if store == nil {
		return "", fmt.Errorf("extension store not initialized")
	}

	extensions, err := store.getExtensionsWithStatus(forceRefresh)
	if err != nil {
		return "", err
	}

	return marshalJSONString(extensions)
}

func SearchStoreExtensionsJSON(query, category string) (string, error) {
	store := getExtensionStore()
	if store == nil {
		return "", fmt.Errorf("extension store not initialized")
	}

	extensions, err := store.searchExtensions(query, category)
	if err != nil {
		return "", err
	}

	return marshalJSONString(extensions)
}

func GetStoreCategoriesJSON() (string, error) {
	store := getExtensionStore()
	if store == nil {
		return "", fmt.Errorf("extension store not initialized")
	}

	categories := store.getCategories()
	return marshalJSONString(categories)
}

func storeExtensionPackageSuffix(downloadURL string) string {
	rawPath := downloadURL
	if parsed, err := url.Parse(downloadURL); err == nil {
		rawPath = parsed.Path
	}

	lowerPath := strings.ToLower(rawPath)
	if strings.HasSuffix(lowerPath, ".sflx") {
		return ".sflx"
	}
	if strings.HasSuffix(lowerPath, ".spotiflac-ext") {
		return ".spotiflac-ext"
	}
	return ".spotiflac-ext"
}

func buildStoreExtensionDestPath(destDir, extensionID, downloadURL string) (string, error) {
	if strings.TrimSpace(extensionID) == "" {
		return "", fmt.Errorf("invalid extension id")
	}

	safeExtensionID := sanitizeFilename(extensionID)
	return filepath.Join(destDir, safeExtensionID+storeExtensionPackageSuffix(downloadURL)), nil
}

func DownloadStoreExtensionJSON(extensionID, destDir string) (string, error) {
	store := getExtensionStore()
	if store == nil {
		return "", fmt.Errorf("extension store not initialized")
	}

	ext, err := store.findExtension(extensionID)
	if err != nil {
		return "", err
	}

	destPath, err := buildStoreExtensionDestPath(destDir, extensionID, ext.getDownloadURL())
	if err != nil {
		return "", err
	}
	err = store.downloadExtension(extensionID, destPath)
	if err != nil {
		return "", err
	}

	return destPath, nil
}

func ClearStoreCacheJSON() error {
	store := getExtensionStore()
	if store == nil {
		return fmt.Errorf("extension store not initialized")
	}

	store.clearCache()
	return nil
}
