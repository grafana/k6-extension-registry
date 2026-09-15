---
name: k6-extension-release
description: Release a new version of a k6 extension. Use when the user says "release", "tag", "new version", "publish", "cut a release" in an xk6 extension repo. Covers the tag, the GitHub release, the Go module proxy, the registry entry, the registry tag, and the changelog message.
---

# k6 Extension Release

This skill releases one k6 extension. It is NOT a k6 release — do not load the `k6-release` skill.

Ask the user which extension to release when the repo you are in does not name one, and stop until they answer. Everything below uses these values.

| Placeholder | Meaning | Example |
| --- | --- | --- |
| `<EXTENSION>` | The repo name | `xk6-docs` |
| `<MODULE>` | The Go module path | `github.com/grafana/xk6-docs` |
| `<VERSION>` | The version you release | `0.0.10` |
| `<CATALOG_KEY>` | How the catalog names what the extension provides | `subcommand:docs` |

The catalog key depends on what the extension provides.

| The extension provides | Key |
| --- | --- |
| A subcommand | `subcommand:<name>` |
| A JavaScript module | The import path, such as `k6/x/faker` |
| An output | The output name |

Read the extension repo's own agent docs before every release, such as `AGENTS.md`, `CLAUDE.md`, and a history file. They hold burned versions and past incidents.

When any step fails (GitHub API, proxy check, etc.), retry up to 5 times before giving up. External services are flaky — persistence usually wins.

A release reaches users through four systems in this order.

| System | What it holds |
| --- | --- |
| The extension repo | The tag and the GitHub release. |
| `proxy.golang.org` | The module at that version. Immutable. |
| This repo | The version in `registry.yaml` or `registry-v2.yaml`. |
| `https://registry.k6.io` | The catalog that k6 and the build service read. |

## Pre-flight

1. All tests and lint must pass locally before pushing.
2. Determine the next version: check `git tag --sort=-v:refname | head -1` and increment the patch.
3. Confirm the proxy has never seen that version:

        go list -m <MODULE>@v<VERSION>

   It must fail with `invalid version`. If it prints a version, that number is burned — the proxy served it once and keeps it forever, even though no tag and no release remain. Increment again and check the new number the same way. `git tag` cannot tell you this, because a deleted tag leaves no trace in git.
4. Collect commits since last tag: `git log <last-tag>..HEAD --oneline`.

## Step 1: Push and tag

    git push origin main
    # Wait for CI to pass — check with: gh run list --limit 1
    git tag v<VERSION>
    git push origin v<VERSION>

IMPORTANT: Never move a tag after pushing. The Go module proxy cache is immutable — a faulty tag cannot be replaced, only superseded by a new version.

## Step 2: Verify the release

Wait for the release workflow to complete:

    gh run list --limit 1

Then verify the release exists and has assets:

    gh release view v<VERSION>

## Step 3: Write the GitHub release description

Edit the release with a description. Always wrap technical terms in backticks. Group changes by new features, bug fixes, and maintenance. Each item links its commit hash. Omit sections that have no entries.

    gh release edit v<VERSION> --notes "$(cat <<'EOF'
    <release body here>
    EOF
    )"

Format:

    <EXTENSION> `v<VERSION>` is here!
    - One line per feature, in the user's terms
    - One line per feature, in the user's terms

    ## New features

    ### Feature name [<short-hash>](https://github.com/grafana/<EXTENSION>/commit/<short-hash>)

    What the user can do now, and how they reach it. Two sentences at most.

    > [!NOTE]
    > A caveat the user hits in practice, with the issue linked.

    ## Bug fixes

    - [<short-hash>](https://github.com/grafana/<EXTENSION>/commit/<short-hash>) What works again.

    ## Maintenance and internal improvements

    - [<short-hash>](https://github.com/grafana/<EXTENSION>/commit/<short-hash>) What changed under the hood.

## Step 4: Verify Go module proxy

    curl -s https://proxy.golang.org/<MODULE>/@v/v<VERSION>.info

If this returns JSON with the version and timestamp, the proxy has it. If not, wait and retry — it can take a few minutes.

## Step 5: Add the version to the registry

Pick the file by the k6 major version that the extension builds against.

| The extension imports | File |
| --- | --- |
| `go.k6.io/k6` | `registry.yaml` |
| `go.k6.io/k6/v2` | `registry-v2.yaml` |

Add the version to the `versions` list of the extension's entry, by hand. `register-version.sh` and the `register-version.yml` workflow write `registry.yaml` only, so they are the wrong tool for a k6 v2 extension.

Create a PR on a feature branch:

    gh pr create --repo grafana/k6-extension-registry \
      --base main --head add-<EXTENSION>-v<VERSION> \
      --title "Add <EXTENSION> v<VERSION>" \
      --body "Add [v<VERSION>](https://github.com/grafana/<EXTENSION>/releases/tag/v<VERSION>) of \`<EXTENSION>\` to the registry."

`main` needs one approval, so leave the PR open and ping a reviewer (or wait for an existing approver). The release is still usable via `xk6 build` immediately.

## Step 6: Tag this repo

A merge to `main` publishes to the staging bucket only. The `publish-prod` job in `update.yml` runs under `if: ${{ github.ref_type == 'tag' }}`, so the merged entry reaches nobody until someone pushes a tag.

Push a new patch tag on the merge commit:

    git -C <registry-clone> tag -a v<REGISTRY_VERSION> <MERGE_SHA> -m "Publish registry with <EXTENSION> v<VERSION>"
    git -C <registry-clone> push origin v<REGISTRY_VERSION>

The tag publishes every other commit on `main` since the previous tag, so read `git log <last-tag>..origin/main --oneline` first and confirm those commits are safe to ship.

## Step 7: Wait for the new version to reach users

The publish job syncs to S3 without a CloudFront invalidation, and the objects carry no `cache-control`, so the edge keeps the old catalog for up to an hour.

Check the served catalog, and skip your own cache:

    curl -s "https://registry.k6.io/v2/catalog.json?cb=$(date +%s)" | jq '.["<CATALOG_KEY>"].versions'

The build service at `https://ingest.k6.io/builder/api/v1` picks the concrete version, not k6 and not the local catalog cache, and it keeps its own copy for a few minutes after the edge refreshes. Ask it directly:

    curl -s -X POST https://ingest.k6.io/builder/api/v1/build \
      -H 'Content-Type: application/json' \
      -d '{"k6_mod_path":"go.k6.io/k6/v2","k6":"<K6_VERSION>","platform":"<GOOS>/<GOARCH>","dependencies":[{"name":"<CATALOG_KEY>","constraints":"*"}]}' \
      | jq '.artifact.dependencies'

The release reaches users when that answer names the new version. Only then does k6 provision it.

When you test the provisioned binary, delete the stale local copies of the catalog and the builds. On macOS they are `~/Library/Caches/k6/v2/catalog.json` and `~/Library/Caches/k6/builds/`.

## Step 8: Print the changelog message

Print the message in the session so the user can copy it into `#k6-changelog`. Do not post it.

Only list features, not bug fixes or maintenance. Always wrap technical terms in backticks. Link each commit hash.

Treat architectural changes that expand who can use the project as features. New shared modules, new public APIs, new integration points — these are headline news, not "internal improvements." If another consumer can do something new because of this release, lead with it.

Use plain Markdown — `[text](url)` for links, `*` for bullets. Do NOT use Slack's older `<url|text>` mrkdwn syntax or `-` bullets; the channel renders Markdown.

Format:

    :k6_party: *<EXTENSION> <VERSION> is released*

    > One line on what the extension does.

    * Feature description ([short-hash](commit-url))
    * Feature description ([short-hash](commit-url))

    See the [complete release notes](https://github.com/grafana/<EXTENSION>/releases/tag/v<VERSION>).

## Checklist

Before telling the user the release is done, verify:

- [ ] CI passed on main
- [ ] Tag pushed and release workflow completed
- [ ] GitHub release has its assets and its description
- [ ] Go module proxy has the version
- [ ] Registry PR opened (merge handled separately by a reviewer)
- [ ] Registry tagged, and the build service resolves the new version
- [ ] Changelog message printed for the user
