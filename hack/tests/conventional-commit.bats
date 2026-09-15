#!/usr/bin/env bats
#
# Tests for the shared conventional-commit parser.
#
# Run with:  bats hack/tests/conventional-commit.bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
	# shellcheck source=hack/lib/conventional-commit.sh
	source "${REPO_ROOT}/hack/lib/conventional-commit.sh"
}

# parse_field TITLE BODY INDEX
# Prints one line of the cc_parse output: 1 type, 2 scope, 3 breaking.
parse_field() {
	cc_parse "$1" "$2" | sed -n "${3}p"
}

type_of() { parse_field "$1" "" 1; }
scope_of() { parse_field "$1" "" 2; }
breaking_of() { parse_field "$1" "${2:-}" 3; }

@test "a plain type is parsed" {
	[ "$(type_of 'feat: add a thing')" = "feat" ]
	[ "$(scope_of 'feat: add a thing')" = "" ]
	[ "$(breaking_of 'feat: add a thing')" = "false" ]
}

@test "a scope is parsed" {
	[ "$(type_of 'fix(cel-policy): correct the matcher')" = "fix" ]
	[ "$(scope_of 'fix(cel-policy): correct the matcher')" = "cel-policy" ]
}

@test "the type and the scope are lower-cased" {
	[ "$(type_of 'FEAT(CEL-Policy): mixed case')" = "feat" ]
	[ "$(scope_of 'FEAT(CEL-Policy): mixed case')" = "cel-policy" ]
}

@test "an empty scope is accepted" {
	[ "$(type_of 'chore(): empty scope')" = "chore" ]
	[ "$(scope_of 'chore(): empty scope')" = "" ]
}

# --- the breaking marker, in its three spellings ------------------------------

@test "the specification breaking marker without a scope is read" {
	[ "$(breaking_of 'feat!: drop the old field')" = "true" ]
}

@test "the specification breaking marker with a scope is read" {
	[ "$(breaking_of 'feat(api)!: drop the old field')" = "true" ]
}

@test "the malformed breaking marker present in this repository is read" {
	# "feat!(scope):" is not the specification order, but the history uses it.
	[ "$(breaking_of 'feat!(api): drop the old field')" = "true" ]
}

@test "a BREAKING CHANGE footer in the body is read" {
	[ "$(breaking_of 'fix: something' 'body text

BREAKING CHANGE: the field is gone')" = "true" ]
}

@test "the hyphenated BREAKING-CHANGE footer is read" {
	[ "$(breaking_of 'fix: something' 'BREAKING-CHANGE: the field is gone')" = "true" ]
}

@test "the phrase BREAKING CHANGE in prose is not a footer" {
	[ "$(breaking_of 'fix: something' 'this is not a BREAKING CHANGE: really')" = "false" ]
}

# --- the breaking marker only counts when it can reach a policy user ----------

@test "a breaking marker on a tooling type does not break the policy" {
	[ "$(breaking_of 'ci!: rebuild every image')" = "false" ]
	[ "$(breaking_of 'chore!: drop the old script')" = "false" ]
	[ "$(breaking_of 'build!: change the toolchain')" = "false" ]
	[ "$(breaking_of 'docs!: rewrite the readme')" = "false" ]
}

@test "a breaking marker under a tooling scope does not break the policy" {
	# The real pull request #749. It changed metadata.yml in every policy, so
	# without this rule it raised the major version of fourteen policies.
	local title='feat!(ci):  release policies to a configurable OCI registry from a repo fork'
	[ "$(type_of "$title")" = "feat" ]
	[ "$(scope_of "$title")" = "ci" ]
	[ "$(breaking_of "$title")" = "false" ]
}

@test "a breaking marker on a policy type and scope does break the policy" {
	[ "$(breaking_of 'feat(cel-policy)!: change the settings schema')" = "true" ]
	[ "$(breaking_of 'fix!: reject what was accepted')" = "true" ]
}

# --- titles that do not parse -------------------------------------------------

@test "a title without a type does not parse and counts as a chore" {
	run cc_parse 'Serialize ArtifactHub branch updates'
	[ "$status" -eq 1 ]
	[ "$(type_of 'Serialize ArtifactHub branch updates')" = "chore" ]
	[ "$(breaking_of 'Serialize ArtifactHub branch updates')" = "false" ]
}

@test "an unknown type does not parse" {
	# Otherwise "Fixes: the thing" would be read as the type "fixes".
	run cc_parse 'Fixes: the thing'
	[ "$status" -eq 1 ]
	[ "$(type_of 'Fixes: the thing')" = "chore" ]
}

@test "a type with no space after the colon does not parse" {
	run cc_parse 'feat:no space'
	[ "$status" -eq 1 ]
}

@test "a known type parses and reports success" {
	run cc_parse 'feat: a thing'
	[ "$status" -eq 0 ]
}

# --- the version increment ----------------------------------------------------

@test "a breaking change asks for a major release" {
	[ "$(cc_bump feat true)" = "major" ]
	[ "$(cc_bump chore true)" = "major" ]
}

@test "a feature asks for a minor release" {
	[ "$(cc_bump feat false)" = "minor" ]
}

@test "every other type asks for a patch release" {
	for type in fix chore build ci docs test refactor perf style revert deps; do
		[ "$(cc_bump "$type" false)" = "patch" ]
	done
}

@test "the larger of two increments wins" {
	[ "$(cc_max_bump patch minor)" = "minor" ]
	[ "$(cc_max_bump minor patch)" = "minor" ]
	[ "$(cc_max_bump minor major)" = "major" ]
	[ "$(cc_max_bump major patch)" = "major" ]
	[ "$(cc_max_bump patch patch)" = "patch" ]
}

# --- the changelog section ----------------------------------------------------

@test "a breaking change goes to the breaking section" {
	[ "$(cc_category feat true)" = "breaking" ]
}

@test "a feature goes to the features section" {
	[ "$(cc_category feat false)" = "features" ]
}

@test "a fix goes to the fixes section" {
	[ "$(cc_category fix false)" = "fixes" ]
}

@test "every other type goes to the maintenance section" {
	for type in chore build ci docs test refactor style revert; do
		[ "$(cc_category "$type" false)" = "maintenance" ]
	done
}

@test "a dependency bump goes to maintenance whatever its type" {
	# release-drafter put these under Maintenance through the
	# "area/dependencies" label. Without this, "fix(deps)" would appear under
	# Bug Fixes.
	[ "$(cc_category fix false deps)" = "maintenance" ]
	[ "$(cc_category chore false deps)" = "maintenance" ]
	[ "$(cc_category build false deps)" = "maintenance" ]
}

@test "every section key has a heading" {
	for key in $(cc_categories_in_order); do
		run cc_category_title "$key"
		[ "$status" -eq 0 ]
		[ -n "$output" ]
	done
}

@test "the sections are ordered from most to least important" {
	[ "$(cc_categories_in_order | paste -sd,)" = "breaking,features,fixes,maintenance" ]
}

# --- the labels ---------------------------------------------------------------

@test "a breaking change is labelled" {
	run cc_labels feat "" true
	[[ "$output" == *"kind/breaking-change"* ]]
}

@test "a dependency bump is labelled whatever its type" {
	for type in chore build fix; do
		run cc_labels "$type" deps false
		[[ "$output" == *"area/dependencies"* ]]
	done
}

@test "a feature and a fix get their own labels" {
	run cc_labels feat "" false
	[[ "$output" == *"kind/feature"* ]]
	run cc_labels fix "" false
	[[ "$output" == *"kind/bug"* ]]
}

@test "every other type is labelled a chore" {
	for type in build ci docs test refactor style revert chore; do
		run cc_labels "$type" "" false
		[[ "$output" == *"kind/chore"* ]]
	done
}

@test "a plain chore is not labelled a dependency" {
	run cc_labels chore "" false
	[[ "$output" != *"area/dependencies"* ]]
}
