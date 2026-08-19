# hauler/manifest

Reconciles a [Hauler](https://github.com/hauler-dev/hauler) content manifest
(a multi-document YAML file using `apiVersion: content.hauler.cattle.io/v1`)
against a declarative desired state.

## Overview

This policy is generic: it carries no project-specific data. Everything
about *your* manifest — which documents it has, which images/charts/files
belong to each, where their versions come from, and any extra per-item
configuration such as cosign keyless verification — is supplied through
values.

If the manifest file itself does not exist, the policy fails unless
`hauler.createIfMissing` is set, in which case it is created from scratch.
The parent directory must exist either way — a missing directory is treated
as a typo in `hauler.file`, not as a request to bootstrap a manifest there.

For every document you declare, the policy:

- **Creates the document if missing** (when `createIfMissing: true`), or
  fails loudly if it is missing and `createIfMissing` is not set.
- **Updates it if present**: annotations are reconciled key by key, and each
  item is matched against the existing list — updated in place if found,
  appended if not.
- **Preserves everything else**: other documents, comments, and document
  ordering in the file are left untouched. Selection is always by
  `metadata.name`, never by array position.
- Optionally **sorts** the reconciled array by name, and optionally **prunes**
  entries that are no longer declared in values.

This addresses three requirements that Updatecli's native `yaml`/`file`
resources cannot satisfy on a manifest like Hauler's: `kind: yaml` targets
fail with "couldn't find key" if a key does not already exist (no
create-if-missing), `engine: yamlpath` (the only engine supporting name-based
selection) silently truncates a multi-document file to its first document,
and neither resource can append a new array element. See
[How it works](#how-it-works) for why the policy is implemented as a
`kind: shell` target driving `yq` and `jq` instead.

## Requirements

- `yq` ([mikefarah](https://github.com/mikefarah/yq), v4) and `jq` on the
  runner. The policy's `conditions:` fail loudly if either is missing. Both
  ship by default on GitHub's `ubuntu-latest` runners.
- `bash` (the target's `spec.shell` is `/usr/bin/env bash`).

## Supported SCM Backends

`github`, `githubsearch`, `gitlab`, `gitea`, `bitbucket`, `stash`. `gitea` and
`stash` are self-hosted and require `scm.url`. `githubsearch` uses
`scm.search`/`scm.limit` instead of `scm.owner`/`scm.repository`.

## Policy Configuration

### Available Input Values

```yaml
hauler:
  file: "hauler_manifest.yaml"   # path to the manifest, relative to the repo/scm root
  createIfMissing: false         # default false: fail if the file doesn't exist

# Named version sources. Each becomes an Updatecli source; items reference
# one by id via `versionFrom`.
versions:
  <id>:
    kind: yaml                   # yaml (default) | dockerimage | helmchart | githubrelease | shell
    # kind: yaml
    file: "path/or/https://..."  # mutually exclusive with filePrefix/fileVersionFrom/fileSuffix, see below
    key: "$.some.path"
    engine: "yamlpath"           # optional; ONLY safe on a single-document file, see Troubleshooting
    trimQuotes: true             # optional; strip a leading/trailing '"' from the resolved value
    # kind: dockerimage
    image: "ghcr.io/org/image"
    versionfilter: {kind: semver}
    # kind: helmchart
    url: "https://charts.example.com"
    name: "chart-name"
    # kind: githubrelease
    owner: "org"
    repository: "repo"
    token: "..."
    versionfilter: {kind: semver}
    # kind: shell
    command: "..."

# Desired state, one entry per top-level document, selected by metadata.name.
documents:
  - name: "my-images"            # required, matches metadata.name
    kind: Images                 # Images | Charts | Files
    apiVersion: "content.hauler.cattle.io/v1"  # optional, only used if the document must be created
    createIfMissing: true        # default false: fail if the document doesn't exist
    sort: true                   # default false: sort the array by name after reconciling
    prune: false                 # default false: remove items not declared below
    annotations:
      hauler.dev/certificate-oidc-issuer: "https://token.actions.githubusercontent.com"
    items:
      # Images item
      - repository: "ghcr.io/org/image"     # matched against "name" up to the last ':'
        versionFrom: "<id>"                 # OR:
        version: "v1.2.3"                   # a literal version (mutually exclusive with versionFrom)
        tagTemplate: "{version}"            # optional, default "{version}"; {version} is substituted
        fields:                             # optional extra per-image fields (see below)
          certificate-identity-regexp: "https://github.com/org/repo/.github/workflows/release.yml@refs/tags/{tag}"
      # Charts item
      - name: "chart-name"
        repoURL: "https://charts.example.com"
        versionFrom: "<id>"                 # OR: version: "1.2.3"
        fields: {}                          # optional extra chart fields, see below
      # Files item
      - name: "install.sh"
        pathTemplate: "https://example.com/releases/{version}/install.sh"
        versionFrom: "<id>"                 # OR: path: "https://example.com/install.sh" (literal)

scm:
  enabled: false
  kind: "github"                 # github | githubsearch | gitlab | gitea | bitbucket | stash
  env_token: "UPDATECLI_GITHUB_TOKEN"
  branch: "main"
  # user, email, owner (requiredEnv), repository, username, commitusingapi, commitmessage: {...}
  # search, limit: only for kind githubsearch
  # url: required for kind gitea / stash

pr:
  enabled: false                 # set true to have the policy open the PR/MR itself
  automerge: false
  mergemethod: "squash"
  title: "chore(deps): Update Hauler manifest"
  description: ""
  labels: []
  reviewers: []

pipeline:
  labels:
    ecosystem: "hauler"
    policy: "manifest"
```

`{version}` and `{tag}` in `tagTemplate`, `pathTemplate` and `fields` values
are literal, single-brace placeholders resolved by the policy at run time —
they are unrelated to (and safe alongside) Updatecli's own `{{ }}` templating.

### Per-item `fields`

`fields` accepts arbitrary extra keys written verbatim onto the matched
entry, with `{tag}`/`{version}` substituted. For `Images` items this is how
you configure Hauler's cosign keyless verification, in addition to the
`hauler.dev/*` document-level annotations:

```
key, use-tlog-verify, certificate-identity, certificate-identity-regexp,
certificate-oidc-issuer, certificate-oidc-issuer-regexp,
certificate-github-workflow-repository, platform, rewrite, exclude-extras,
local, ca-file, insecure-skip-tls-verify
```

**`Charts` documents have no cosign support in Hauler** — only Helm
provenance verification (`verify`, `keyring`). Don't put cosign-shaped keys
in a `Charts` item's `fields`; Hauler will simply ignore them.

`Files` items have no dedicated version field in Hauler; if the file's
identity is versioned, encode it in `pathTemplate` with a `{version}`
placeholder.

## How It Works

The target is a single `kind: shell` step. At render time, Updatecli's
Go-template pass turns your `documents:` values into a flat, newline-
delimited (NDJSON) desired-state document — one record per document header
and one per item, linked by index — which a `jq` pass then reassembles into
the nested shape the reconciliation logic uses. The reconciliation itself
locates each target document with `yq eval-all 'select(.metadata.name == ...)'`
(safe for multi-document files, unlike the default `yq eval`, which
reintroduces document separators into captured output), matches items by
identity (repository prefix for `Images`, name for `Charts`/`Files`), and
updates or appends via targeted `yq -i` calls addressed by array index, with
every dynamic value passed through `env(...)` rather than interpolated into
the `yq` expression string.

Reconciliation happens against a scratch copy of the manifest. Updatecli
always sets the `DRY_RUN` environment variable for shell targets (`true` for
`diff`, `false` for `apply`); the script only copies its result back over the
real file when `DRY_RUN` is not `true`, so `updatecli diff` never mutates
your manifest.

### Two implementation traps worth knowing before editing `updatecli.d/default.yaml`

**The NDJSON step is not a stylistic choice.** Emitting the documents/items
arrays directly from nested `range` loops requires a comma-separator guard
(an `if` gated on the loop index) around each element. When such a guard
encloses a *further nested* range that itself contains a reference to a
named source value — exactly the shape of `documents[].items[]` with
`versionFrom` — Updatecli's dependency-graph builder fails with an unrelated-
looking internal template parsing error while trying to statically resolve
that reference. Flattening the structure avoids the pattern entirely. Avoid
reintroducing `{{ if $index }},{{ end }}`-style comma guards around a range
that (directly or transitively) contains a `source "..."` reference.

**`source` must always be called with a literal string argument**
(`source "version/foo"`), never a computed one
(`source (printf "version/%s" $x)`) — Updatecli's dependency scanner does not
resolve computed arguments. Where the id is dynamic, the policy builds the
literal `{{ source "..." }}` text via `{{"{{"}} ... {{"}}"}}` instead of
calling `source` directly, deferring the actual call to the point where
Updatecli re-evaluates the rendered command as a template just before
execution.

## Quick Usage

### Local Testing

```sh
# render and inspect
updatecli manifest show --config updatecli.d --values values.yaml --values <your-values>.yaml

# dry run against the bundled fixture (does not write to disk, see "How it
# works" above)
updatecli diff --config updatecli.d --values values.yaml --values testdata/values.yaml

# apply for real, with an SCM (opens a PR/MR if pr.enabled: true)
updatecli apply --config updatecli.d --values values.yaml --values <your-values>.yaml
```

### Using from an OCI Registry

```yaml
policies:
  - name: Reconcile Hauler manifest
    policy: ghcr.io/updatecli/policies/hauler/manifest:0.1.0
    values:
      - path/to/your-values.yaml
```

Pin by digest for unattended/high-trust CI, since tags are mutable:

```yaml
    policy: ghcr.io/updatecli/policies/hauler/manifest:0.1.0@sha256:<digest>
```

## Authentication

Set `scm.env_token` to the name of an environment variable holding your SCM
token (default `UPDATECLI_GITHUB_TOKEN`), and export it before running
`updatecli`. `scm.owner` is read via `requiredEnv`, so it must also be set as
an environment variable, not hardcoded in values (this matches the
convention used across this repository's other policies).

## Publish

Publishing follows this repository's standard flow: bump `version` in
`Policy.yaml`, add a `CHANGELOG.md` entry, and CI publishes to
`ghcr.io/updatecli/policies/hauler/manifest` on merge to `main`.

## Troubleshooting

- **A quoted YAML scalar** (e.g. `version: "1.2.3"`) is returned by the
  `yaml` source *with its quotes included*. Set `trimQuotes: true` on that
  `versions` entry when this applies — otherwise you get literal values like
  `"1.2.3"` (with quote characters) written into the manifest.
- **`engine: yamlpath`** on a `versions` entry is only safe when that source
  file is a single YAML document — on a multi-document file it silently
  truncates the read to the first document (a `goccy/go-yaml` limitation,
  not specific to this policy). Use the default engine there instead.
- **One policy instance reconciles one manifest file.** A repository with
  several Hauler manifests instantiates the policy once per file.
- **`Charts` and `Files` documents match items by `name`** (and `path` as a
  `Files` fallback); `Images` documents match by the repository prefix of
  `name` up to the last `:`. There is no support for matching by digest.
- **No discovery/autodiscovery mode.** Every document and item must be
  enumerated explicitly in values. A glob-based discovery mode (for example,
  to source many versions from a directory of `metadata.yml` files) is a
  possible future addition and would be purely additive to this values
  schema.

## Related Documentation

- [Hauler](https://github.com/hauler-dev/hauler)
- [Updatecli `shell` resource](https://www.updatecli.io/docs/plugins/resource/shell/)
- [Updatecli `yaml` resource](https://www.updatecli.io/docs/plugins/resource/yaml/)
