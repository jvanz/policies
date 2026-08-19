#!/bin/bash
# Verifies that a policy is correctly represented in the repository's Hauler
# manifest tooling:
#
#   - hauler_manifest.yaml                    (the manifest itself)
#   - updatecli/values/hauler-manifest.yaml   (the Updatecli policy that
#                                              reconciles the manifest weekly)
#
# Policies listed in policies/excluded-from-publishing.txt must be absent
# from both files. All other policies must be present in both.
#
# This intentionally only checks *presence*, never versions: the weekly
# Updatecli automation is the source of truth for versions, and asserting
# equality here would fight that automation on every bump.
set -euo pipefail

usage() {
  echo "Usage: $0 <policy-working-dir>" >&2
  echo "  policy-working-dir: path to a policy directory, e.g. policies/pod-privileged-policy" >&2
  exit 1
}

if [ "$#" -ne 1 ]; then
  usage
fi

POLICY_DIR="$1"
if [ ! -d "$POLICY_DIR" ]; then
  echo "ERROR: policy directory '$POLICY_DIR' does not exist" >&2
  exit 1
fi

if ! command -v yq >/dev/null 2>&1; then
  echo "ERROR: 'yq' is required" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXCLUSION_LIST="$REPO_ROOT/policies/excluded-from-publishing.txt"
MANIFEST_FILE="$REPO_ROOT/hauler_manifest.yaml"
VALUES_FILE="$REPO_ROOT/updatecli/values/hauler-manifest.yaml"
MANIFEST_DOC="kubewarden-policies"

for f in "$EXCLUSION_LIST" "$MANIFEST_FILE" "$VALUES_FILE"; do
  if [ ! -f "$f" ]; then
    echo "ERROR: expected file '$f' not found" >&2
    exit 1
  fi
done

POLICY_BASENAME="$(basename "$POLICY_DIR")"

METADATA_FILE="$(find "$POLICY_DIR" -maxdepth 1 \( -name 'metadata.yml' -o -name 'metadata.yaml' \) | head -1)"
if [ -z "$METADATA_FILE" ]; then
  echo "ERROR: no metadata.yml/metadata.yaml found in '$POLICY_DIR'" >&2
  exit 1
fi

POLICY_OCI_URL="$(yq -r '.annotations."io.kubewarden.policy.ociUrl" // ""' "$METADATA_FILE")"
POLICY_ID="${POLICY_OCI_URL##*/}"

EXCLUDED=false
while IFS= read -r line; do
  entry="$(echo "$line" | sed -e 's/#.*//' -e 's/[[:space:]]//g')"
  [ -z "$entry" ] && continue
  if [ "$entry" = "$POLICY_BASENAME" ]; then
    EXCLUDED=true
    break
  fi
done <"$EXCLUSION_LIST"

# Match by directory name, embedded in the certificate-identity-regexp's
# release tag path (.../refs/tags/<policy-dir>/{version}). This is the only
# reliable identity for policies with no ociUrl annotation, since those all
# resolve POLICY_ID to the literal string "null".
manifest_dir_matches=$(DIR="$POLICY_BASENAME" DOC="$MANIFEST_DOC" yq eval-all '
  [select(.metadata.name == env(DOC)) | .spec.images[] | select((."certificate-identity-regexp" // "") | contains("refs/tags/" + env(DIR) + "/"))] | length
' "$MANIFEST_FILE")

values_dir_matches=$(DIR="$POLICY_BASENAME" DOC="$MANIFEST_DOC" yq '
  [.documents[] | select(.name == env(DOC)) | .items[] | select(((.fields."certificate-identity-regexp") // "") | contains("refs/tags/" + env(DIR) + "/"))] | length
' "$VALUES_FILE")

# Match by OCI repository, when the policy has an id. Catches entries that
# were added without the identity regexp field.
manifest_id_matches=0
values_has_version=false
values_id_matches=0
if [ -n "$POLICY_ID" ] && [ "$POLICY_ID" != "null" ]; then
  manifest_id_matches=$(ID="$POLICY_ID" DOC="$MANIFEST_DOC" yq eval-all '
    [select(.metadata.name == env(DOC)) | .spec.images[] | select(.name | split(":")[0] == "ghcr.io/kubewarden/policies/" + env(ID))] | length
  ' "$MANIFEST_FILE")
  values_has_version=$(ID="$POLICY_ID" yq '.versions | has(env(ID))' "$VALUES_FILE")
  values_id_matches=$(ID="$POLICY_ID" DOC="$MANIFEST_DOC" yq '
    [.documents[] | select(.name == env(DOC)) | .items[] | select(.repository == "ghcr.io/kubewarden/policies/" + env(ID))] | length
  ' "$VALUES_FILE")
fi

if [ "$EXCLUDED" = true ]; then
  fail=false
  if [ "$manifest_dir_matches" != "0" ] || [ "$manifest_id_matches" != "0" ]; then
    echo "ERROR: '$POLICY_BASENAME' is listed in $EXCLUSION_LIST but is present in $MANIFEST_FILE." >&2
    echo "       Remove its image entry from that file." >&2
    fail=true
  fi
  if [ "$values_dir_matches" != "0" ] || [ "$values_id_matches" != "0" ] || [ "$values_has_version" = "true" ]; then
    echo "ERROR: '$POLICY_BASENAME' is listed in $EXCLUSION_LIST but is present in $VALUES_FILE." >&2
    echo "       Remove its 'versions' entry and its 'documents[].items[]' entry from that file." >&2
    fail=true
  fi
  if [ "$fail" = true ]; then
    exit 1
  fi
  echo "OK: '$POLICY_BASENAME' is excluded from publishing and correctly absent from the Hauler manifest tooling."
  exit 0
fi

fail=false
if [ "$manifest_dir_matches" = "0" ] && [ "$manifest_id_matches" = "0" ]; then
  echo "ERROR: '$POLICY_BASENAME' is not excluded from publishing but is missing from $MANIFEST_FILE." >&2
  echo "       Add an image entry for ghcr.io/kubewarden/policies/$POLICY_ID to that file." >&2
  fail=true
fi
if [ "$values_dir_matches" = "0" ] && [ "$values_id_matches" = "0" ] && [ "$values_has_version" != "true" ]; then
  echo "ERROR: '$POLICY_BASENAME' is not excluded from publishing but is missing from $VALUES_FILE." >&2
  echo "       Add a 'versions.$POLICY_ID' entry and a matching 'documents[].items[]' entry to that file." >&2
  fail=true
fi
if [ "$fail" = true ]; then
  exit 1
fi

echo "OK: '$POLICY_BASENAME' is correctly listed in the Hauler manifest tooling."
