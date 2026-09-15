#!/usr/bin/env bats
#
# Tests for the parts of policy-release-notes.sh that do not call the network.
#
# The script runs main() when it is executed, so these tests source it with
# POLICY_RELEASE_NOTES_LIB_ONLY set, which stops at the function definitions.
#
# Run with:  bats hack/tests/policy-release-notes.bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
	export POLICY_RELEASE_NOTES_LIB_ONLY=1
	# shellcheck source=hack/policy-release-notes.sh
	source "${REPO_ROOT}/hack/policy-release-notes.sh"
}

# --- resolving the version ----------------------------------------------------

@test "no pull requests means no version" {
	run resolve_version "1.2.3" '[]'
	[ "$output" = "" ]
}

@test "a single chore is a patch release" {
	run resolve_version "1.2.3" '[{"number":1,"title":"chore: tidy","body":""}]'
	[ "$output" = "1.2.4" ]
}

@test "a feature is a minor release" {
	run resolve_version "1.2.3" '[{"number":1,"title":"feat: add","body":""}]'
	[ "$output" = "1.3.0" ]
}

@test "a breaking change is a major release" {
	run resolve_version "1.2.3" '[{"number":1,"title":"feat!: drop","body":""}]'
	[ "$output" = "2.0.0" ]
}

@test "the largest increment among many pull requests wins" {
	local prs='[
    {"number":1,"title":"chore: tidy","body":""},
    {"number":2,"title":"feat: add","body":""},
    {"number":3,"title":"fix: repair","body":""}
  ]'
	run resolve_version "1.2.3" "$prs"
	[ "$output" = "1.3.0" ]
}

@test "a breaking change outranks a feature whatever the order" {
	local prs='[
    {"number":1,"title":"feat!: drop","body":""},
    {"number":2,"title":"feat: add","body":""}
  ]'
	run resolve_version "1.2.3" "$prs"
	[ "$output" = "2.0.0" ]
}

@test "a title that does not parse still produces a patch release" {
	run resolve_version "1.2.3" '[{"number":1,"title":"tidy things up","body":""}]'
	# "run" folds stderr into the output, and an unparseable title warns there.
	[[ "$output" == *"is not a conventional commit"* ]]
	[ "$(printf '%s' "$output" | tail -1)" = "1.2.4" ]
}

@test "a breaking change on a version below one reaches 1.0.0" {
	run resolve_version "0.1.20" '[{"number":1,"title":"feat!: drop","body":""}]'
	[ "$output" = "1.0.0" ]
}

# --- rendering the notes ------------------------------------------------------

@test "a pull request is rendered as a title and a number" {
	run render_notes '[{"number":42,"title":"fix: repair the thing","body":""}]'
	[[ "$output" == *"- fix: repair the thing (#42)"* ]]
}

@test "only the sections that have entries appear" {
	run render_notes '[{"number":1,"title":"chore: tidy","body":""}]'
	[[ "$output" == *"Maintenance"* ]]
	[[ "$output" != *"Features"* ]]
	[[ "$output" != *"Bug Fixes"* ]]
	[[ "$output" != *"Breaking changes"* ]]
}

@test "the sections are rendered from most to least important" {
	local prs='[
    {"number":1,"title":"chore: tidy","body":""},
    {"number":2,"title":"fix: repair","body":""},
    {"number":3,"title":"feat: add","body":""},
    {"number":4,"title":"feat!: drop","body":""}
  ]'
	run render_notes "$prs"
	local order
	order="$(printf '%s' "$output" | grep '^## ' | paste -sd'|')"
	[ "$order" = "## ⚠️  Breaking changes|## 🚀 Features|## 🐛 Bug Fixes|## 🧰 Maintenance" ]
}

@test "a dependency bump is rendered under maintenance" {
	run render_notes '[{"number":7,"title":"fix(deps): bump serde","body":""}]'
	[[ "$output" == *"Maintenance"* ]]
	[[ "$output" != *"Bug Fixes"* ]]
}

@test "no pull requests renders nothing" {
	run render_notes '[]'
	[ "$output" = "" ]
}

@test "a title that does not parse is rendered verbatim under maintenance" {
	run render_notes '[{"number":9,"title":"Serialize ArtifactHub updates","body":""}]'
	[[ "$output" == *"- Serialize ArtifactHub updates (#9)"* ]]
	[[ "$output" == *"Maintenance"* ]]
}

# --- selecting the pull requests of one policy --------------------------------

# run_select POLICY_DIR COMMITS PRS_JSON
run_select() {
	local range_file pr_file
	range_file="$(mktemp)"
	pr_file="$(mktemp)"
	printf '%s\n' $2 >"$range_file"
	printf '%s' "$3" >"$pr_file"
	PR_CACHE_FILE="$pr_file"
	select_policy_prs "$1" "$range_file"
	rm -f "$range_file" "$pr_file"
}

@test "a pull request outside the commit range is left out" {
	local prs='[{"number":1,"title":"fix: a","body":"","mergedAt":"2024-01-01T00:00:00Z","mergeCommit":"bbb","files":["policies/echo/x"]}]'
	run run_select "policies/echo" "aaa" "$prs"
	[ "$(jq 'length' <<<"$output")" -eq 0 ]
}

@test "a pull request that touches no file of the policy is left out" {
	local prs='[{"number":1,"title":"fix: a","body":"","mergedAt":"2024-01-01T00:00:00Z","mergeCommit":"aaa","files":["policies/other/x"]}]'
	run run_select "policies/echo" "aaa" "$prs"
	[ "$(jq 'length' <<<"$output")" -eq 0 ]
}

@test "a pull request in range that touches the policy is kept" {
	local prs='[{"number":1,"title":"fix: a","body":"","mergedAt":"2024-01-01T00:00:00Z","mergeCommit":"aaa","files":["policies/echo/src/lib.rs"]}]'
	run run_select "policies/echo" "aaa" "$prs"
	[ "$(jq 'length' <<<"$output")" -eq 1 ]
	[ "$(jq -r '.[0].number' <<<"$output")" = "1" ]
}

@test "a policy name that prefixes another policy name does not match it" {
	# "policies/echo" must not collect the files of "policies/echo-extra".
	local prs='[{"number":1,"title":"fix: a","body":"","mergedAt":"2024-01-01T00:00:00Z","mergeCommit":"aaa","files":["policies/echo-extra/src/lib.rs"]}]'
	run run_select "policies/echo" "aaa" "$prs"
	[ "$(jq 'length' <<<"$output")" -eq 0 ]
}

@test "a pull request with no merge commit is left out" {
	local prs='[{"number":1,"title":"fix: a","body":"","mergedAt":"2024-01-01T00:00:00Z","mergeCommit":"","files":["policies/echo/x"]}]'
	run run_select "policies/echo" "aaa" "$prs"
	[ "$(jq 'length' <<<"$output")" -eq 0 ]
}

@test "the kept pull requests are ordered oldest first" {
	local prs='[
    {"number":2,"title":"fix: b","body":"","mergedAt":"2024-02-01T00:00:00Z","mergeCommit":"bbb","files":["policies/echo/x"]},
    {"number":1,"title":"fix: a","body":"","mergedAt":"2024-01-01T00:00:00Z","mergeCommit":"aaa","files":["policies/echo/x"]}
  ]'
	run run_select "policies/echo" "aaa
bbb" "$prs"
	[ "$(jq -r '[.[].number] | join(",")' <<<"$output")" = "1,2" ]
}

@test "a trailing slash on the policy directory makes no difference" {
	local prs='[{"number":1,"title":"fix: a","body":"","mergedAt":"2024-01-01T00:00:00Z","mergeCommit":"aaa","files":["policies/echo/x"]}]'
	run run_select "policies/echo/" "aaa" "$prs"
	[ "$(jq 'length' <<<"$output")" -eq 1 ]
}

@test "the release list is fetched once, not once per policy" {
	# Regression test. load_releases used to cache in a variable, but every
	# caller reaches it through a command substitution, which is a subshell, so
	# the cache was discarded and the list was fetched once per policy: 58
	# queries of several hundred releases each, against an API rate limit.
	local calls_file
	calls_file="$(mktemp)"
	RELEASES_CACHE="$(mktemp)"

	# Stand in for the real command and count the calls.
	gh() {
		echo "call" >>"$calls_file"
		printf '[{"tagName":"echo/v1.0.0","isDraft":false,"publishedAt":"2024-01-01T00:00:00Z"}]'
	}

	last_release_tag echo >/dev/null
	last_release_tag echo >/dev/null
	last_release_tag other >/dev/null

	[ "$(wc -l <"$calls_file")" -eq 1 ]
	rm -f "$calls_file" "$RELEASES_CACHE"
}

@test "the newest published release is the baseline, not the highest tag name" {
	# "v1.0.0-rc1" sorts above "v1.0.0" by refname, so the baseline comes from
	# the publication date instead.
	RELEASES_CACHE="$(mktemp)"
	cat >"$RELEASES_CACHE" <<'JSON'
[
  {"tagName":"echo/v1.0.0-rc1","isDraft":false,"publishedAt":"2024-01-01T00:00:00Z"},
  {"tagName":"echo/v1.0.0","isDraft":false,"publishedAt":"2024-02-01T00:00:00Z"}
]
JSON
	run last_release_tag echo
	[ "$output" = "echo/v1.0.0" ]
	rm -f "$RELEASES_CACHE"
}

@test "a policy with no release has no baseline" {
	RELEASES_CACHE="$(mktemp)"
	printf '[{"tagName":"other/v1.0.0","isDraft":false,"publishedAt":"2024-01-01T00:00:00Z"}]' >"$RELEASES_CACHE"
	run last_release_tag echo
	[ "$output" = "" ]
	rm -f "$RELEASES_CACHE"
}

@test "a policy name that prefixes another does not take its release" {
	RELEASES_CACHE="$(mktemp)"
	printf '[{"tagName":"echo-extra/v9.0.0","isDraft":false,"publishedAt":"2024-01-01T00:00:00Z"}]' >"$RELEASES_CACHE"
	run last_release_tag echo
	[ "$output" = "" ]
	rm -f "$RELEASES_CACHE"
}

# --- the version override -----------------------------------------------------

@test "the literal two-quote string counts as no override" {
	# trigger-policy-release.yaml writes version='' when it has nothing to force.
	VERSION_OVERRIDE="''"
	ALL_POLICIES=true
	parse_args --all
	[ "$VERSION_OVERRIDE" = "" ]
}

@test "a real version is kept as an override" {
	parse_args --all --version 4.5.6
	[ "$VERSION_OVERRIDE" = "4.5.6" ]
}
