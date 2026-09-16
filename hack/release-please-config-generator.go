// This program generates release-please-config.json and
// .release-please-manifest.json from the policies in the "policies"
// directory. Run it with `make release-please-config` after adding,
// removing, or renaming a policy.
package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
)

const (
	configPath   = "release-please-config.json"
	manifestPath = ".release-please-manifest.json"
	policiesDir  = "policies"
)

var versionAnnotationRe = regexp.MustCompile(`(?m)^\s*io\.kubewarden\.policy\.version:\s*"?([0-9][^"\s]*)"?\s*$`)

type packageConfig struct {
	Component   string          `json:"component"`
	ReleaseType string          `json:"release-type"`
	ExtraFiles  []extraFileSpec `json:"extra-files"`
}

type extraFileSpec struct {
	Type     string `json:"type,omitempty"`
	Path     string `json:"path,omitempty"`
	JSONPath string `json:"jsonpath,omitempty"`
}

type config struct {
	Schema                  string                   `json:"$schema"`
	BootstrapSHA            string                   `json:"bootstrap-sha,omitempty"`
	SeparatePullRequests    bool                     `json:"separate-pull-requests"`
	SkipChangelog           bool                     `json:"skip-changelog"`
	SkipGithubRelease       bool                     `json:"skip-github-release"`
	IncludeComponentInTag   bool                     `json:"include-component-in-tag"`
	IncludeVInTag           bool                     `json:"include-v-in-tag"`
	TagSeparator            string                   `json:"tag-separator"`
	Label                   string                   `json:"label"`
	PullRequestTitlePattern string                   `json:"pull-request-title-pattern"`
	ReleaseSearchDepth      int                      `json:"release-search-depth"`
	SequentialCalls         bool                     `json:"sequential-calls"`
	Plugins                 []string                 `json:"plugins"`
	Packages                map[string]packageConfig `json:"packages"`
}

func main() {
	var bootstrapSHA string
	for i, arg := range os.Args {
		if arg == "--bootstrap-sha" && i+1 < len(os.Args) {
			bootstrapSHA = os.Args[i+1]
		}
	}

	// Once release-please-config.json exists, keep its "bootstrap-sha"
	// unless a new value is given explicitly. release-please ignores this
	// key after the first release PR merges, but this generator must not
	// erase it on every re-run, or "make release-please-config" would
	// produce a diff on every CI run.
	if bootstrapSHA == "" {
		if existing, err := os.ReadFile(configPath); err == nil {
			var previous config
			if err := json.Unmarshal(existing, &previous); err == nil {
				bootstrapSHA = previous.BootstrapSHA
			}
		}
	}

	entries, err := os.ReadDir(policiesDir)
	if err != nil {
		panic(err)
	}

	packages := map[string]packageConfig{}
	manifest := map[string]string{}

	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		name := entry.Name()
		policyDir := filepath.Join(policiesDir, name)
		metadataPath := filepath.Join(policyDir, "metadata.yml")
		metadataBytes, err := os.ReadFile(metadataPath)
		if err != nil {
			// Not a policy directory (e.g. "crates").
			continue
		}

		releaseType := "simple"
		if _, err := os.Stat(filepath.Join(policyDir, "Cargo.toml")); err == nil {
			releaseType = "rust"
		}

		key := policiesDir + "/" + name
		packages[key] = packageConfig{
			Component:   name,
			ReleaseType: releaseType,
			ExtraFiles: []extraFileSpec{
				{
					Type:     "yaml",
					Path:     "metadata.yml",
					JSONPath: "$.annotations['io.kubewarden.policy.version']",
				},
				{
					Type: "generic",
					Path: "metadata.yml",
				},
			},
		}

		match := versionAnnotationRe.FindSubmatch(metadataBytes)
		if match == nil {
			panic(fmt.Sprintf("%s: could not find io.kubewarden.policy.version annotation", metadataPath))
		}
		manifest[key] = string(match[1])
	}

	cfg := config{
		Schema:                  "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json",
		BootstrapSHA:            bootstrapSHA,
		SeparatePullRequests:    true,
		SkipChangelog:           true,
		SkipGithubRelease:       true,
		IncludeComponentInTag:   true,
		IncludeVInTag:           true,
		TagSeparator:            "/",
		Label:                   "TRIGGER-RELEASE,kind/chore,area/release",
		PullRequestTitlePattern: "build: Prepare for release ${component} ${version}",
		ReleaseSearchDepth:      600,
		SequentialCalls:         true,
		Plugins:                 []string{"cargo-workspace"},
		Packages:                packages,
	}

	writeJSON(configPath, cfg)
	writeJSON(manifestPath, sortedManifest(manifest))
}

// sortedManifest returns the manifest map unchanged; Go's json encoder
// sorts map keys alphabetically already, this helper only documents intent.
func sortedManifest(m map[string]string) map[string]string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return m
}

func writeJSON(path string, v interface{}) {
	data, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		panic(err)
	}
	data = append(data, '\n')
	if err := os.WriteFile(path, data, 0o644); err != nil {
		panic(err)
	}
}
