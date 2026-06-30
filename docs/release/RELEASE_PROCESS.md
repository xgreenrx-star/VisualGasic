# Release Process & Versioning

VisualGasic follows [Semantic Versioning 2.0.0](https://semver.org/) with a
pre-release suffix for any build that isn't yet considered stable.

## TL;DR — pick a tag

| Situation                                           | Tag                  |
| --------------------------------------------------- | -------------------- |
| First public preview of a coming release            | `vX.Y.Z-beta.1`      |
| Subsequent previews, fixing bugs in the preview     | `vX.Y.Z-beta.2`, …   |
| Feature-frozen, fixing only release blockers        | `vX.Y.Z-rc.1`, …     |
| Public stable release                               | `vX.Y.Z`             |
| Bugfix on the latest stable                         | `vX.Y.Z+1`           |
| New backward-compatible features                    | `vX.Y+1.0`           |
| Breaking change to public API / save format / CLI   | `vX+1.0.0`           |

> **Examples:** `v5.1.0-beta.1` → `v5.1.0-beta.2` → `v5.1.0-rc.1` → `v5.1.0`
> → (bugfix) `v5.1.1` → (next feature batch) `v5.2.0-beta.1` → `v5.2.0`

## The numbers

`MAJOR.MINOR.PATCH`

- **MAJOR** — incompatible API or behavioural changes the user will notice
  (e.g. `.vg` save format break, plugin entry point rename, removal of a
  CLI flag). Bumping MAJOR resets MINOR and PATCH to `0`.
- **MINOR** — new backward-compatible functionality, or a substantial
  internal refactor with no user-visible regression. Resets PATCH to `0`.
- **PATCH** — bug fixes only. No new features, no API additions, no
  behavioural changes outside the fix.

> **Common misconception:** the patch digit is **not** "the beta number".
> A beta of `5.1.0` is `v5.1.0-beta.1`, not `v5.1.0` where the trailing
> `0` somehow signals beta. Pre-release information always lives in the
> suffix after the dash.

## Pre-release suffixes

For any build that isn't yet considered stable, append one of:

- `-alpha.N` — early, expect breakage. Rare in this project; we usually
  start at `-beta`.
- `-beta.N` — feature work is mostly done, looking for early-adopter
  feedback. Multiple betas are normal.
- `-rc.N` — release candidate; feature-frozen, fixing only release
  blockers. The next tag after a green RC is the bare `vX.Y.Z`.

`N` starts at `1` and is dot-separated so SemVer-aware tooling sorts
correctly: `beta.10` > `beta.2` works only with the dot, not as `beta10`
vs `beta2`. **Always use the dotted form** (`-beta.1`, not `-Beta1` or
`-beta1`).

A pre-release version is treated as *less than* the bare release, so
`v5.1.0-beta.1` < `v5.1.0-rc.1` < `v5.1.0` — exactly what we want.

## What gets a pre-release?

Anything that:

- introduces a new MINOR or MAJOR feature set,
- changes the editor or runtime ABI,
- changes the `.vg` file format,
- ships a new GDExtension build.

A pure bugfix on a stable line goes straight to the next PATCH (e.g.
`v5.1.1` after `v5.1.0`); we don't typically beta those unless the fix
is risky.

## Tagging & creating the GitHub release

1. Update `VERSION` to the bare version *without* the leading `v`:
   ```
   5.1.0-beta.1
   ```
2. Update `CHANGELOG.md` with the new entry.
3. Commit:
   ```
   git commit -am "release: v5.1.0-beta.1"
   ```
4. Tag and push:
   ```
   git tag -a v5.1.0-beta.1 -m "v5.1.0-beta.1"
   git push origin main --tags
   ```
5. Build the artifacts:
   ```bash
   bash scripts/build_appimage.sh 5.1.0-beta.1
   bash scripts/build_windows_installer.sh 5.1.0-beta.1
   bash scripts/build_offline_bundle.sh 5.1.0-beta.1
   ```
6. Create the GitHub release. Pre-releases must be marked as such:
   ```bash
   gh release create v5.1.0-beta.1 \
     release/v5.1.0-beta.1/VisualGasic-Installer-v5.1.0-beta.1-x86_64.AppImage \
     release/v5.1.0-beta.1/VisualGasic-Installer-v5.1.0-beta.1-x86_64.exe \
     release/v5.1.0-beta.1/VisualGasic-Installer-Offline-v5.1.0-beta.1-linux-x86_64.zip \
     release/v5.1.0-beta.1/VisualGasic-Installer-Offline-v5.1.0-beta.1-windows-x86_64.zip \
     --title "VisualGasic v5.1.0 Beta 1" \
     --notes-file RELEASE_NOTES_v5.1.0-beta.1.md \
     --prerelease
   ```

   For a stable release, drop `--prerelease` and tag without a suffix.

## Updating an existing release

If you need to re-upload artifacts after a fix:

```bash
gh release upload vX.Y.Z-beta.N <files…> --clobber
```

If you only need to refresh the body (e.g. embed screenshots that landed
on `main` after the tag was created), edit it from a sed-substituted
copy so relative paths in the file resolve to absolute `raw.githubusercontent.com`
URLs:

```bash
sed 's|docs/screenshots/|https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/docs/screenshots/|g' \
    RELEASE_NOTES_vX.Y.Z-beta.N.md > /tmp/release_body.md
gh release edit vX.Y.Z-beta.N --notes-file /tmp/release_body.md
```

## Archiving / removing old releases

Old releases that pre-date this policy (e.g. `v4.4.0-rc1`…`v4.4.0-rc6`,
`v3.5.0-beta2`, `v2.3.0`) have had their **binaries removed** but the
release pages remain so existing changelog links keep working. Each
archived page carries the standard archived-binaries notice at the top.

If you want to do this for a future release:

```bash
# Remove every asset from a tag…
for asset in $(gh release view vX.Y.Z --json assets --jq '.assets[].name'); do
    gh release delete-asset vX.Y.Z "$asset" -y
done
# …then prepend the archived notice to the body.
```

Do **not** delete the GitHub release itself unless you also delete the
git tag — orphaned tags on `main` confuse `git describe`.
