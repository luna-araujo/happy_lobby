# Deploying Builds (Windows/Linux)

This project ships release builds to GitHub Releases from git tags.

## What gets deployed

- `Windows Desktop` export -> `happy_lobby-<tag>-windows.zip`
- `Linux/X11` export -> `happy_lobby-<tag>-linux.zip`

Current phase scope:

- Implemented: Windows + Linux
- Deferred: macOS

## Steam behavior in release builds

Release exports are configured with the custom export feature `steam` in `export_presets.cfg`.
At runtime, `SteamConfig.is_enabled()` checks this feature and forces Steam mode on.

Steam mode resolution order:

1. `OS.has_feature("steam")` (release exports)
2. `HAPPY_LOBBY_STEAM` env override (`1/true/yes/on` or `0/false/no/off`)
3. Default fallback (`false`)

This keeps local development flexible while ensuring release artifacts run with Steam enabled.

## Release trigger

Workflow file: `.github/workflows/release.yml`

Release builds run on tag pushes matching `v*`, but only publish for stable SemVer tags:

- Publishes: `v1.2.3`
- Skips: `v1.2.3-rc1`, `v1.2`, `test-tag`

## How to publish a release

1. Create and push a stable tag:
   - `git tag v0.1.0`
   - `git push origin v0.1.0`
2. Wait for the `Release Builds` GitHub Action to finish.
3. Open the GitHub Release for that tag and download platform zip files.

## Notes

- Godot export templates are downloaded by CI (`4.6.1-stable`) using `firebelley/godot-export@v7.0.0`.
- GitHub Release limits (current): up to 1000 assets per release, each asset under 2 GiB.
  Reference: https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases

## Future macOS phase

When macOS is enabled, add a macOS export preset and extend the workflow to archive/upload a macOS build.
