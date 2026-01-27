#!/bin/bash
set -e

# Function to display usage
usage() {
    echo "Usage: $0 --bump <major|minor|patch> [--repo <owner/repo>] [--dry-run]"
    echo "  --bump <type>       Bump the version by the specified type (major, minor, or patch)."
    echo "  --repo <owner/repo> (Optional) Specify the target repository (e.g., kubewarden/policies)."
    echo "  --dry-run           Print actions without executing them."
    exit 1
}

# Check for required tools
if ! command -v gh &> /dev/null; then
    echo "Error: 'gh' (GitHub CLI) is not installed."
    exit 1
fi

if ! command -v yq &> /dev/null; then
    echo "Error: 'yq' is not installed."
    exit 1
fi

# Parse arguments
BUMP_TYPE=""
TARGET_REPO=""
DRY_RUN=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --bump)
            if [[ -n "$2" && "$2" =~ ^(major|minor|patch)$ ]]; then
                BUMP_TYPE="$2"
                shift
            else
                echo "Error: --bump requires a value of 'major', 'minor', or 'patch'."
                usage
            fi
            ;;
        --repo)
            if [[ -n "$2" && ! "$2" =~ ^-- ]]; then
                TARGET_REPO="$2"
                shift
            else
                echo "Error: --repo requires a repository value (e.g., owner/repo)."
                usage
            fi
            ;;
        --dry-run)
            DRY_RUN=true
            ;;
        *)
            echo "Unknown parameter passed: $1"
            usage
            ;;
    esac
    shift
done

if [[ -z "$BUMP_TYPE" ]]; then
    echo "Error: You must specify a bump type."
    usage
fi

# Function to bump version
bump_version() {
    local version=$1
    local type=$2
    
    # Remove 'v' prefix if present for calculation
    local clean_version="${version#v}"
    
    IFS='.' read -r -a parts <<< "$clean_version"
    local major="${parts[0]}"
    local minor="${parts[1]}"
    local patch="${parts[2]}"

    # Defaults to 0 if missing
    major=${major:-0}
    minor=${minor:-0}
    patch=${patch:-0}

    case "$type" in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
    esac

    # Restore 'v' prefix if it was there originally
    if [[ "$version" == v* ]]; then
        echo "v$major.$minor.$patch"
    else
        echo "$major.$minor.$patch"
    fi
}

# Iterate over directories in "policies"
POLICIES_DIR="policies"

if [[ ! -d "$POLICIES_DIR" ]]; then
    echo "Error: Directory '$POLICIES_DIR' not found."
    exit 1
fi

echo "Scanning directories in '$POLICIES_DIR'..."

for dir in "$POLICIES_DIR"/*/; do
    # Remove trailing slash
    full_path="${dir%/}"
    metadata_file="$full_path/metadata.yml"

    if [[ -f "$metadata_file" ]]; then
        # Extract just the basename (e.g., "policies/my-policy" -> "my-policy")
        policy_name=$(basename "$full_path")

        echo "--------------------------------------------------"
        echo "Processing policy: $policy_name"

        # Extract current version
        current_version=$(yq eval '.annotations["io.kubewarden.policy.version"]' "$metadata_file")

        if [[ -z "$current_version" || "$current_version" == "null" ]]; then
            echo "Warning: Could not find version annotation in $metadata_file. Skipping."
            continue
        fi

        # Calculate new version
        new_version=$(bump_version "$current_version" "$BUMP_TYPE")
        
        echo "  Current version: $current_version"
        echo "  Bump type:       $BUMP_TYPE"
        echo "  New version:     $new_version"

        repo_info=${TARGET_REPO:-(current context)}

        if [[ "$DRY_RUN" == "true" ]]; then
            echo "  [DRY RUN] Would trigger workflow on repo: '$repo_info'"
            echo "     Inputs:"
            echo "       policy-working-dir = '$policy_name'"
            echo "       policy-version     = '$new_version'"
        else
            echo "  Triggering workflow on repo: '$repo_info'..."
            
            # Build command array to safely handle optional args
            CMD=("gh" "workflow" "run" "trigger-policy-release.yaml")
            
            if [[ -n "$TARGET_REPO" ]]; then
                CMD+=("-R" "$TARGET_REPO")
            fi
            
            CMD+=("-f" "policy-working-dir=$policy_name")
            CMD+=("-f" "policy-version=$new_version")

            # Execute command
            "${CMD[@]}"
            
            if [[ $? -eq 0 ]]; then
                echo "  Successfully triggered workflow."
            else
                echo "  Error: Failed to trigger workflow."
            fi
        fi
    else
        # Silent skip if no metadata.yml found
        : 
    fi
done

echo "Done."
