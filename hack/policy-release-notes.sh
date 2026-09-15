#!/usr/bin/env bash
#
# Resolve the next version of a policy and render its release notes from the
# titles of the pull requests merged since the last release.
#
# The GitHub Action ".github/actions/draft-policy-release" is a thin wrapper
# around this script. Keeping the logic here means a maintainer can run the
# whole computation locally, against the real repository, without pushing a
# branch:
#
#   hack/policy-release-notes.sh --policy-working-dir policies/echo --dry-run
#   hack/policy-release-notes.sh --all --dry-run
#
# How a release is decided
# ------------------------
# The title of every merged pull request is read as a conventional commit. A
# breaking marker asks for a major release, "feat" asks for a minor release and
# everything else asks for a patch release. The largest request wins. Labels
# play no part: they exist for search and triage only.
#
# Which pull requests count
# -------------------------
# A pull request counts when its merge commit is in the range
# "<last release tag>..<ref>" and when it changed at least one file under the
# policy directory.
#
# The range is decided by commit ancestry, not by a timestamp. This matters:
# the draft release of a version is created *before* the "Prepare for release"
# pull request that carries the version bump is merged, so a boundary based on
# the creation date of a release would pull that pull request into the next
# release window and bump every idle policy forever.
#
# Changed files come from the pull request itself rather than from "git log",
# which makes the result the same under a squash merge and under a merge
# commit.

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=hack/lib/conventional-commit.sh
source "${SCRIPT_DIR}/lib/conventional-commit.sh"

POLICY_WORKING_DIR=""
ALL_POLICIES="false"
BASE_BRANCH=""
REF="HEAD"
VERSION_OVERRIDE=""
PR_CACHE_FILE=""
DRY_RUN="false"
OUTPUT_FILE=""
NOTES_FILE=""

usage() {
	cat <<'EOF'
Usage: policy-release-notes.sh [options]

Options:
  --policy-working-dir DIR  Policy directory, with the "policies/" prefix.
                            For example "policies/echo".
  --all                     Run for every policy that has a Makefile. Implies
                            --dry-run.
  --base BRANCH             Branch the pull requests were merged into.
                            Defaults to the current branch.
  --ref REF                 End of the commit range. Defaults to HEAD.
  --version VERSION         Use this version instead of resolving one. The
                            literal string '' counts as "not given".
  --pr-cache FILE           Read the merged pull requests from this JSON file
                            instead of calling the GitHub API. Use
                            --write-pr-cache to produce it once for all
                            policies.
  --write-pr-cache FILE     Fetch the merged pull requests, write them to FILE
                            and exit.
  --output FILE             Write the outputs as KEY=VALUE lines to FILE.
                            Point this at $GITHUB_OUTPUT from a workflow.
  --notes-file FILE         Write the rendered release notes to FILE.
  --dry-run                 Print what would happen. Makes no API calls that
                            change anything.
  -h, --help                Show this help.
EOF
}

log() { printf '%s\n' "$*" >&2; }

warn() {
	# Render as a GitHub Actions annotation when running in a workflow, and as
	# plain text when running locally.
	if [ -n "${GITHUB_ACTIONS:-}" ]; then
		printf '::warning::%s\n' "$*" >&2
	else
		printf 'warning: %s\n' "$*" >&2
	fi
}

die() {
	if [ -n "${GITHUB_ACTIONS:-}" ]; then
		printf '::error::%s\n' "$*" >&2
	else
		printf 'error: %s\n' "$*" >&2
	fi
	exit 1
}

require_tool() {
	command -v "$1" >/dev/null 2>&1 || die "this script needs '$1' on the PATH"
}

parse_args() {
	local write_pr_cache=""
	while [ $# -gt 0 ]; do
		case "$1" in
		--policy-working-dir)
			POLICY_WORKING_DIR="${2:-}"
			shift 2
			;;
		--all)
			ALL_POLICIES="true"
			DRY_RUN="true"
			shift
			;;
		--base)
			BASE_BRANCH="${2:-}"
			shift 2
			;;
		--ref)
			REF="${2:-}"
			shift 2
			;;
		--version)
			VERSION_OVERRIDE="${2:-}"
			shift 2
			;;
		--pr-cache)
			PR_CACHE_FILE="${2:-}"
			shift 2
			;;
		--write-pr-cache)
			write_pr_cache="${2:-}"
			shift 2
			;;
		--output)
			OUTPUT_FILE="${2:-}"
			shift 2
			;;
		--notes-file)
			NOTES_FILE="${2:-}"
			shift 2
			;;
		--dry-run)
			DRY_RUN="true"
			shift
			;;
		-h | --help)
			usage
			exit 0
			;;
		*) die "unknown option '$1'. Run with --help." ;;
		esac
	done

	# "trigger-policy-release.yaml" writes the literal two-character string ''
	# when it has no version to force. Treat it as absent.
	if [ "$VERSION_OVERRIDE" = "''" ] || [ "$VERSION_OVERRIDE" = '""' ]; then
		VERSION_OVERRIDE=""
	fi

	if [ -n "$write_pr_cache" ]; then
		require_tool gh
		require_tool jq
		[ -n "$BASE_BRANCH" ] || BASE_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
		fetch_merged_prs >"$write_pr_cache"
		log "wrote $(jq 'length' <"$write_pr_cache") merged pull requests to $write_pr_cache"
		exit 0
	fi

	if [ "$ALL_POLICIES" = "false" ] && [ -z "$POLICY_WORKING_DIR" ]; then
		die "give --policy-working-dir or --all. Run with --help."
	fi

	# Accept "echo" as well as "policies/echo", because the workflows are not
	# consistent about the prefix.
	if [ -n "$POLICY_WORKING_DIR" ] && [ ! -d "$POLICY_WORKING_DIR" ] &&
		[ -d "policies/$POLICY_WORKING_DIR" ]; then
		POLICY_WORKING_DIR="policies/$POLICY_WORKING_DIR"
	fi

	[ -n "$BASE_BRANCH" ] || BASE_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
}

# repo_slug
#
# Prints "owner/name" for the repository this script runs against.
repo_slug() {
	if [ -n "${GITHUB_REPOSITORY:-}" ]; then
		printf '%s\n' "$GITHUB_REPOSITORY"
		return 0
	fi
	gh repo view --json nameWithOwner -q .nameWithOwner
}

# fetch_merged_prs
#
# Prints a JSON array of every pull request merged into the base branch, with
# the fields this script needs.
#
# One query serves every policy, so a run over all 58 policies costs the same
# number of API calls as a run over one. That matters: the release workflow
# caps its matrix at five parallel jobs because of the API rate limit.
fetch_merged_prs() {
	local slug
	slug="$(repo_slug)"

	# shellcheck disable=SC2016 # $owner and friends are GraphQL variables, not shell ones.
	gh api graphql --paginate --slurp \
		-F owner="${slug%%/*}" \
		-F name="${slug##*/}" \
		-F base="$BASE_BRANCH" \
		-f query='
      query($owner: String!, $name: String!, $base: String!, $endCursor: String) {
        repository(owner: $owner, name: $name) {
          pullRequests(
            states: MERGED
            baseRefName: $base
            orderBy: {field: UPDATED_AT, direction: DESC}
            first: 50
            after: $endCursor
          ) {
            pageInfo { hasNextPage endCursor }
            nodes {
              number
              title
              body
              mergedAt
              mergeCommit { oid }
              files(first: 100) { nodes { path } }
            }
          }
        }
      }' |
		jq '[ .[].data.repository.pullRequests.nodes[]
          | { number, title, body, mergedAt,
              mergeCommit: (.mergeCommit.oid // ""),
              files: [ .files.nodes[].path ] } ]'
}

# load_merged_prs
#
# Prints the merged pull requests, from the cache file when one was given and
# from the API otherwise.
#
# Like load_releases, this caches in a file. Every caller reaches it through a
# pipeline, which is a subshell, so a variable would not survive.
MERGED_PRS_CACHE=""
load_merged_prs() {
	if [ -n "$PR_CACHE_FILE" ]; then
		[ -f "$PR_CACHE_FILE" ] || die "the cache file '$PR_CACHE_FILE' does not exist"
		cat "$PR_CACHE_FILE"
		return 0
	fi
	if [ ! -s "$MERGED_PRS_CACHE" ]; then
		log "querying the merged pull requests of '$BASE_BRANCH'..."
		fetch_merged_prs >"$MERGED_PRS_CACHE"
	fi
	cat "$MERGED_PRS_CACHE"
}

# load_releases
#
# Prints every published release of the repository as a JSON array.
#
# The list is cached in a file rather than in a variable. Every caller reaches
# this through a command substitution, which is a subshell, so a variable
# assigned here would be discarded and the list would be fetched once per
# policy — 58 times, each returning several hundred releases.
#
# The list is also fetched whole. A partial fetch is worse than a slow one:
# this repository has over four hundred releases across fifty-eight policies,
# so a short limit silently hands back the wrong baseline for the policies
# whose releases fall outside the window.
RELEASES_CACHE=""
load_releases() {
	if [ -z "$RELEASES_CACHE" ] || [ ! -s "$RELEASES_CACHE" ]; then
		log "querying the published releases..."
		gh release list --limit 100000 --exclude-drafts \
			--json tagName,isDraft,publishedAt >"$RELEASES_CACHE"
	fi
	cat "$RELEASES_CACHE"
}

# last_release_tag POLICY_NAME
#
# Prints the tag of the newest published release of a policy, or nothing when
# the policy has never been released.
#
# This reads the releases rather than the tags on purpose. "git tag --sort
# -v:refname" ranks "echo/v1.0.0-rc1" above "echo/v1.0.0", which would make
# every policy that ever had a release candidate resolve from the wrong
# baseline. A draft release is skipped, because the draft of the version being
# prepared already exists when this runs.
last_release_tag() {
	local policy_name="$1"

	load_releases | jq -r \
		--arg prefix "${policy_name}/v" '
      [ .[]
        | select(.isDraft | not)
        | select(.tagName | startswith($prefix))
      ]
      | sort_by(.publishedAt) | last | .tagName // ""
    '
}

# commits_in_range TAG REF
#
# Prints every commit in "TAG..REF", or every commit reachable from REF when no
# tag is given.
commits_in_range() {
	local tag="$1"
	local ref="$2"

	if [ -n "$tag" ]; then
		if ! git rev-parse --verify --quiet "${tag}^{commit}" >/dev/null; then
			die "the tag '$tag' is not in this clone. Check out with 'fetch-depth: 0'."
		fi
		git rev-list "${tag}..${ref}"
	else
		git rev-list "$ref"
	fi
}

# select_policy_prs POLICY_WORKING_DIR RANGE_FILE
#
# Prints the pull requests that belong to one policy release, newest last, as
# a JSON array.
select_policy_prs() {
	local policy_dir="$1"
	local range_file="$2"

	load_merged_prs | jq \
		--arg prefix "${policy_dir%/}/" \
		--slurpfile range <(jq -R -s 'split("\n") | map(select(length > 0))' <"$range_file") '
      ( $range[0] | map({ (.): true }) | add // {} ) as $in_range
      | [ .[]
          | select(.mergeCommit != "" and ($in_range[.mergeCommit] // false))
          | select([ .files[] | select(startswith($prefix)) ] | length > 0)
        ]
      | sort_by(.mergedAt)
    '
}

# resolve_version CURRENT_VERSION PRS_JSON
#
# Prints the next version of a policy. Reads the title of every pull request,
# takes the largest increment any of them asks for and applies it.
resolve_version() {
	local current="$1"
	local prs_json="$2"
	local bump="patch"
	local count

	count="$(jq 'length' <<<"$prs_json")"
	if [ "$count" -eq 0 ]; then
		printf '\n'
		return 0
	fi

	local title body parsed type breaking
	while IFS= read -r encoded; do
		title="$(jq -r '.title' <<<"$encoded")"
		body="$(jq -r '.body // ""' <<<"$encoded")"

		if ! parsed="$(cc_parse "$title" "$body")"; then
			warn "the title of pull request #$(jq -r '.number' <<<"$encoded") is not a conventional commit: '${title}'. Counting it as a patch."
		fi
		type="$(sed -n 1p <<<"$parsed")"
		breaking="$(sed -n 3p <<<"$parsed")"

		bump="$(cc_max_bump "$bump" "$(cc_bump "$type" "$breaking")")"
	done < <(jq -c '.[]' <<<"$prs_json")

	semver bump "$bump" "$current"
}

# render_notes PRS_JSON
#
# Prints the body of the release, grouped into the four sections release-drafter
# used, so a reader sees no difference between a release made before this change
# and one made after it.
render_notes() {
	local prs_json="$1"
	local category title body_text number parsed type scope breaking
	local section body=""

	for section in $(cc_categories_in_order); do
		local lines=""
		while IFS= read -r encoded; do
			title="$(jq -r '.title' <<<"$encoded")"
			body_text="$(jq -r '.body // ""' <<<"$encoded")"
			number="$(jq -r '.number' <<<"$encoded")"

			parsed="$(cc_parse "$title" "$body_text")" || true
			type="$(sed -n 1p <<<"$parsed")"
			scope="$(sed -n 2p <<<"$parsed")"
			breaking="$(sed -n 3p <<<"$parsed")"
			category="$(cc_category "$type" "$breaking" "$scope")"

			[ "$category" = "$section" ] || continue
			lines+="- ${title} (#${number})"$'\n'
		done < <(jq -c '.[]' <<<"$prs_json")

		if [ -n "$lines" ]; then
			body+="$(cc_category_title "$section")"$'\n'
			body+="$lines"$'\n'
		fi
	done

	printf '%s' "$body"
}

# policy_version POLICY_WORKING_DIR
#
# Prints the version in the metadata file of a policy.
policy_version() {
	local dir="$1"
	local file=""

	for candidate in "${dir}/metadata.yml" "${dir}/metadata.yaml"; do
		if [ -f "$candidate" ]; then
			file="$candidate"
			break
		fi
	done
	[ -n "$file" ] || die "'$dir' has no metadata.yml or metadata.yaml"

	yq -r '.annotations."io.kubewarden.policy.version"' "$file"
}

# process_policy POLICY_WORKING_DIR
process_policy() {
	local policy_dir="${1%/}"
	local policy_name current_version last_tag prs pr_count resolved notes tag

	policy_name="$(basename "$policy_dir")"
	current_version="$(policy_version "$policy_dir")"
	last_tag="$(last_release_tag "$policy_name")"

	local range_file
	range_file="$(mktemp)"
	# shellcheck disable=SC2064 # expand the path now, while it is known.
	trap "rm -f '$range_file'" RETURN
	commits_in_range "$last_tag" "$REF" >"$range_file"

	prs="$(select_policy_prs "$policy_dir" "$range_file")"
	pr_count="$(jq 'length' <<<"$prs")"

	log ""
	log "=== ${policy_name} ==="
	log "  current version: ${current_version}"
	log "  last release:    ${last_tag:-<none>}"
	log "  merged PRs:      ${pr_count}"

	if [ -n "$VERSION_OVERRIDE" ]; then
		resolved="$VERSION_OVERRIDE"
		log "  resolved:        ${resolved} (forced)"
	else
		if [ "$pr_count" -eq 0 ]; then
			log "  nothing merged since the last release. No release."
			emit_output "resolved_version" ""
			emit_output "pr_count" "0"
			return 0
		fi
		resolved="$(resolve_version "$current_version" "$prs")"
		log "  resolved:        ${resolved}"
	fi

	tag="${policy_name}/v${resolved}"
	notes="$(render_notes "$prs")"

	if [ -n "$NOTES_FILE" ]; then
		printf '%s' "$notes" >"$NOTES_FILE"
	fi

	emit_output "resolved_version" "$resolved"
	emit_output "tag" "$tag"
	emit_output "pr_count" "$pr_count"

	if [ "$DRY_RUN" = "true" ]; then
		log "  tag:             ${tag}"
		log "  --- notes ---"
		printf '%s\n' "$notes" | sed 's/^/  /' >&2
		return 0
	fi

	upsert_draft_release "$tag" "$notes"
}

# upsert_draft_release TAG NOTES
#
# Creates the draft release of a version, or updates the draft that is already
# there. Prints nothing; sets the "id" output.
upsert_draft_release() {
	local tag="$1"
	local notes="$2"
	local notes_file release_id

	notes_file="$(mktemp)"
	printf '%s' "$notes" >"$notes_file"

	if gh release view "$tag" >/dev/null 2>&1; then
		log "  updating the draft release ${tag}"
		gh release edit "$tag" --title "$tag" --notes-file "$notes_file" >/dev/null
	else
		log "  creating the draft release ${tag}"
		gh release create "$tag" --draft --title "$tag" \
			--notes-file "$notes_file" --target "$BASE_BRANCH" >/dev/null
	fi
	rm -f "$notes_file"

	release_id="$(gh release view "$tag" --json databaseId -q .databaseId)"
	emit_output "id" "$release_id"
}

# emit_output KEY VALUE
emit_output() {
	[ -n "$OUTPUT_FILE" ] || return 0
	printf '%s=%s\n' "$1" "$2" >>"$OUTPUT_FILE"
}

main() {
	parse_args "$@"

	require_tool gh
	require_tool jq
	require_tool git
	require_tool yq
	[ -n "$VERSION_OVERRIDE" ] || require_tool semver

	# The two API results are cached in files, because every reader of them sits
	# in a subshell. Create the files here, once, and clear them at the end.
	RELEASES_CACHE="$(mktemp)"
	MERGED_PRS_CACHE="$(mktemp)"
	# shellcheck disable=SC2064 # expand the paths now, while they are known.
	trap "rm -f '$RELEASES_CACHE' '$MERGED_PRS_CACHE'" EXIT

	if [ "$ALL_POLICIES" = "true" ]; then
		local dir
		while IFS= read -r dir; do
			process_policy "$dir"
		done < <(find policies -mindepth 2 -maxdepth 2 -name Makefile -exec dirname '{}' \; | sort)
		return 0
	fi

	process_policy "$POLICY_WORKING_DIR"
}

# The test suite sources this file to reach the functions above. Stop here when
# it does, so that sourcing has no side effect.
if [ -z "${POLICY_RELEASE_NOTES_LIB_ONLY:-}" ]; then
	main "$@"
fi
