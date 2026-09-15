#!/usr/bin/env bash
#
# Shared conventional-commit parser.
#
# Both the autolabeler and the release-notes generator source this file, so the
# label of a pull request and the changelog section of that same pull request
# can never disagree.
#
# The reference is the Conventional Commits 1.0.0 specification:
#
#   <type>[optional scope][optional !]: <description>
#
# This parser is deliberately lenient. It accepts three forms of the breaking
# marker, because the repository history contains the malformed middle form:
#
#   feat!: ...        the specification form without a scope
#   feat(ci)!: ...    the specification form with a scope
#   feat!(ci): ...    malformed, but present in this repository
#
# It also accepts a "BREAKING CHANGE:" or "BREAKING-CHANGE:" footer in the body.
#
# A title that does not parse is not an error. The caller receives the type
# "chore" and a warning, so one mistyped title cannot stop a release.

# Guard against a double source, because two actions can load this file in the
# same shell.
if [ -n "${__CONVENTIONAL_COMMIT_SH_LOADED:-}" ]; then
	return 0
fi
__CONVENTIONAL_COMMIT_SH_LOADED=1

# The types this repository uses, plus the remaining specification types. A type
# outside this list does not parse, which stops a title such as
# "Fixes: the thing" from being read as the type "Fixes".
CC_KNOWN_TYPES="build chore ci deps docs feat fix perf refactor revert style test"

# The types that describe the behaviour of a policy. Only these can mark a
# breaking change, because only these can break a policy for its users.
#
# A "!" on "ci", "docs", "test", "build", "chore" or "style" marks a break in
# the tooling, not in the policy.
CC_POLICY_TYPES="feat fix perf refactor revert"

# Scopes that name the tooling rather than a policy. A breaking marker under
# one of these is a break in the tooling, whatever the type says.
#
# This rule has a concrete origin. The pull request
# "feat!(ci): release policies to a configurable OCI registry from a repo fork"
# changed metadata.yml in every policy. Its type is "feat", so the type rule
# above lets it through; without the scope rule it would raise the major
# version of fourteen policies at once for a change that altered no policy
# behaviour.
CC_TOOLING_SCOPES="ci deps release docs test build tooling"

# cc_parse TITLE [BODY]
#
# Prints three lines on stdout:
#   1. type       one of CC_KNOWN_TYPES, or "chore" when the title does not parse
#   2. scope      the scope, or the empty string
#   3. breaking   "true" or "false"
#
# Returns 0 when the title parses and 1 when it does not. The output is valid in
# both cases; the return code only tells the caller whether to warn.
cc_parse() {
	local title="$1"
	local body="${2:-}"
	local type="" scope="" breaking="false"
	local parsed=0

	# The three accepted layouts, in the order they are tried. Each regex
	# captures the type in \1 and, where present, the scope in \2.
	#
	# The patterns live in variables because `[[ =~ ]]` treats an unquoted
	# parenthesis in a literal regex as shell grouping.
	local re_scoped='^([a-zA-Z]+)\(([^)]*)\)(!?):[[:space:]]'
	local re_bang_scoped='^([a-zA-Z]+)!\(([^)]*)\):[[:space:]]'
	local re_plain='^([a-zA-Z]+)(!?):[[:space:]]'

	if [[ "$title" =~ $re_scoped ]]; then
		# feat(scope): ... and feat(scope)!: ...
		type="${BASH_REMATCH[1]}"
		scope="${BASH_REMATCH[2]}"
		[ -n "${BASH_REMATCH[3]}" ] && breaking="true"
		parsed=1
	elif [[ "$title" =~ $re_bang_scoped ]]; then
		# feat!(scope): ... — malformed, accepted on purpose.
		type="${BASH_REMATCH[1]}"
		scope="${BASH_REMATCH[2]}"
		breaking="true"
		parsed=1
	elif [[ "$title" =~ $re_plain ]]; then
		# feat: ... and feat!: ...
		type="${BASH_REMATCH[1]}"
		[ -n "${BASH_REMATCH[2]}" ] && breaking="true"
		parsed=1
	fi

	# Lower-case the type so "Feat:" and "feat:" behave the same.
	type="$(printf '%s' "$type" | tr '[:upper:]' '[:lower:]')"
	scope="$(printf '%s' "$scope" | tr '[:upper:]' '[:lower:]')"

	# Reject a type outside the known list, so an ordinary English sentence
	# that happens to contain a colon is not mistaken for a typed title.
	if [ "$parsed" -eq 1 ] && [[ " $CC_KNOWN_TYPES " != *" $type "* ]]; then
		parsed=0
	fi

	if [ "$parsed" -eq 0 ]; then
		# An unparseable title is maintenance, never a version-raising change.
		type="chore"
		scope=""
		breaking="false"
	fi

	# A "BREAKING CHANGE:" footer in the body raises the change on its own,
	# whatever the title says. The specification allows both spellings. Only a
	# line that starts with the token counts, so prose that mentions the phrase
	# in passing does not trigger a major release.
	if [ -n "$body" ] && printf '%s' "$body" |
		grep -qE '^[[:space:]]*BREAKING[ -]CHANGE[[:space:]]*:'; then
		breaking="true"
	fi

	# A break only counts when it can reach the users of the policy. A break in
	# the build, the CI or the docs cannot. See CC_POLICY_TYPES and
	# CC_TOOLING_SCOPES.
	if [ "$breaking" = "true" ]; then
		if [[ " $CC_POLICY_TYPES " != *" $type "* ]]; then
			breaking="false"
		elif [ -n "$scope" ] && [[ " $CC_TOOLING_SCOPES " == *" $scope "* ]]; then
			breaking="false"
		fi
	fi

	printf '%s\n%s\n%s\n' "$type" "$scope" "$breaking"
	[ "$parsed" -eq 1 ]
}

# cc_bump TYPE BREAKING
#
# Prints the semver increment a single pull request asks for.
#
#   breaking  -> major
#   feat      -> minor
#   all else  -> patch
cc_bump() {
	local type="$1"
	local breaking="$2"

	if [ "$breaking" = "true" ]; then
		printf 'major\n'
		return 0
	fi

	case "$type" in
	feat) printf 'minor\n' ;;
	*) printf 'patch\n' ;;
	esac
}

# cc_category TYPE BREAKING [SCOPE]
#
# Prints the stable key of the changelog section a pull request belongs to.
# The caller turns the key into a heading with cc_category_title.
cc_category() {
	local type="$1"
	local breaking="$2"
	local scope="${3:-}"

	if [ "$breaking" = "true" ]; then
		printf 'breaking\n'
		return 0
	fi

	# A dependency bump is maintenance whatever its type, which is where
	# release-drafter put it through the "area/dependencies" label. Without
	# this, "fix(deps): bump serde" would land under Bug Fixes.
	if [ "$scope" = "deps" ]; then
		printf 'maintenance\n'
		return 0
	fi

	case "$type" in
	feat) printf 'features\n' ;;
	fix) printf 'fixes\n' ;;
	*) printf 'maintenance\n' ;;
	esac
}

# cc_category_title KEY
#
# Prints the heading of a changelog section. The four headings match the ones
# release-drafter produced, so the releases before and after this change read
# the same.
cc_category_title() {
	case "$1" in
	breaking) printf '## ⚠️  Breaking changes\n' ;;
	features) printf '## 🚀 Features\n' ;;
	fixes) printf '## 🐛 Bug Fixes\n' ;;
	maintenance) printf '## 🧰 Maintenance\n' ;;
	*)
		printf 'cc_category_title: unknown category %s\n' "$1" >&2
		return 1
		;;
	esac
}

# cc_categories_in_order
#
# Prints every category key, in the order the changelog presents them.
cc_categories_in_order() {
	printf 'breaking\nfeatures\nfixes\nmaintenance\n'
}

# cc_max_bump BUMP_A BUMP_B
#
# Prints the larger of two semver increments.
cc_max_bump() {
	local rank_a rank_b
	cc__bump_rank() {
		case "$1" in
		major) printf '3\n' ;;
		minor) printf '2\n' ;;
		*) printf '1\n' ;;
		esac
	}
	rank_a="$(cc__bump_rank "$1")"
	rank_b="$(cc__bump_rank "$2")"
	if [ "$rank_a" -ge "$rank_b" ]; then
		printf '%s\n' "$1"
	else
		printf '%s\n' "$2"
	fi
}

# cc_labels TYPE SCOPE BREAKING
#
# Prints the labels the autolabeler applies to a pull request, one per line.
#
# These labels exist so maintainers can search and triage pull requests. No
# release logic reads them: the version and the changelog come from the title.
cc_labels() {
	local type="$1"
	local scope="$2"
	local breaking="$3"

	if [ "$breaking" = "true" ]; then
		printf 'kind/breaking-change\n'
	fi

	# A dependency bump carries the scope "deps", whatever its type. Renovate
	# opens these as "chore(deps)", "build(deps)" and "fix(deps)".
	if [ "$scope" = "deps" ]; then
		printf 'area/dependencies\n'
	fi

	case "$type" in
	feat) printf 'kind/feature\n' ;;
	fix) printf 'kind/bug\n' ;;
	*) printf 'kind/chore\n' ;;
	esac
}
