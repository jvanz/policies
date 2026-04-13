#!/bin/bash
# create-releases.sh
#
# Creates a GitHub release in jvanz/policies for every local git tag.
# Skips tags that already have a release. Use --dry-run to preview.
set -euo pipefail

TARGET_REPO="jvanz/policies"
DRY_RUN=false

usage() {
    echo "Usage: $0 [--dry-run]"
    echo "  --dry-run  Print actions without creating releases."
    exit 1
}

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true ;;
        -h|--help) usage ;;
        *) echo "Unknown parameter: $1"; usage ;;
    esac
    shift
done

if ! command -v gh &>/dev/null; then
    echo "Error: 'gh' (GitHub CLI) is not installed." >&2
    exit 1
fi

tags=$(git tag)

if [[ -z "$tags" ]]; then
    echo "No tags found in the local repository."
    exit 0
fi

echo "Target repository: $TARGET_REPO"
echo "---"

while IFS= read -r tag; do
    # Check if a release already exists for this tag
    if gh release view "$tag" -R "$TARGET_REPO" &>/dev/null; then
        echo "[SKIP]   $tag (release already exists)"
        continue
    fi

    # Determine if this is a pre-release
    prerelease_flag=""
    if [[ "$tag" == *"-alpha"* || "$tag" == *"-beta"* || "$tag" == *"-rc"* ]]; then
        prerelease_flag="--prerelease"
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY-RUN] gh release create \"$tag\" --title \"$tag\" $prerelease_flag -R $TARGET_REPO"
    else
        echo "[CREATE] $tag"
        gh release create "$tag" \
            --title "$tag" \
            $prerelease_flag \
            -R "$TARGET_REPO"
    fi
done <<< "$tags"

echo "---"
echo "Done."
