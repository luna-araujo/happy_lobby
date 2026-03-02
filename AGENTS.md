# Repository Guidelines

## Project Structure & Module Organization
This repository is a Godot 4.6 project rooted at `project.godot`, with `main.tscn` as the entry scene. Core gameplay and networking logic is split by domain:
- `game_world/`: world scene, player spawn, movement, and character scripts.
- `networking/`: session/lobby flow and Steam-facing integration.
- `char_editor/` and `ui_components/`: character editor scenes and reusable UI button scripts.
- `avatar/` and `assets/`: avatar logic, shaders/materials, and source art.
- `addons/`: vendored plugins (`godotsteam`, `plenticons`); avoid editing unless intentionally updating a dependency.
- `addons/steam_play_button/`: local editor addon that adds a toolbar button to play `main.tscn` with Steam env flags.

## Build, Test, and Development Commands
Use the Godot 4.6 editor for daily development.
- `godot4 --path .` launches the project.
- `godot4 --path . --scene main.tscn` runs the main scene directly.
- `godot4 --headless --path . --quit` performs a quick CI-style import/config sanity check.
- `godot4 --path . --export-debug "Linux/X11"` builds a debug export (preset must exist in `export_presets.cfg`).

If `godot4` is not in `PATH`, use the local editor binary configured in `.vscode/settings.json`.

Editor addon note:
- Enable `Steam Play Button` in `Project > Project Settings > Plugins` to show an extra toolbar play button for Steam launches.

## Publish Release Builds
Use the tag-based GitHub release flow to publish new player builds.

1. Set `Project Settings > Application > Config > Version` to the exact release tag value (for example `v0.1.1`). This maps to `config/version` in `project.godot`.
2. Commit and push your latest game changes to `main`.
3. Create a new stable SemVer tag in the format `vX.Y.Z` (for example `v0.1.1`).
4. Push that tag to GitHub.
5. Wait for the `Release Builds` GitHub Actions workflow to finish.
6. Share artifacts from the GitHub Release page for that tag.

Commands:
- `git add .`
- `git commit -m "Bump version to v0.1.1 and describe build change"`
- `git push origin main`
- `git tag v0.1.1`
- `git push origin v0.1.1`

Notes:
- Only stable tags like `v1.2.3` publish builds.
- Pre-release-style tags like `v1.2.3-rc1` are skipped by the release workflow.
- Expected release assets:
  - `happy_lobby-vX.Y.Z-windows.zip`
  - `happy_lobby-vX.Y.Z-linux.zip`

## Coding Style & Naming Conventions
Follow existing GDScript conventions in this repo:
- Use 4-space indentation and UTF-8 encoding.
- Always use explicit type annotations in GDScript; never rely on `:=` type inference.
- Prefer `class_name` scripts for reusable components.
- Scene files use `snake_case.tscn`; script files use matching `snake_case.gd`.
- Keep autoload responsibilities centralized (`NetworkManager`, `SessionManager`) instead of duplicating state.
- Do not hand-edit `*.gd.uid` files; let Godot manage resource IDs.

## Testing Guidelines
There is no committed automated unit test framework yet. Validate changes with focused manual checks:
- Run two instances to test host/join flow on port `4242`.
- Verify late join behavior for player spawn/customization sync.
- For UI/editor changes, re-open affected scenes to confirm exported node paths and signal bindings.

### Runtime Debug Log Check (required after multiplayer testing)
For side-by-side local debugging, launch two instances and capture logs:
- `/home/luna/Godot/Editor/Godot_v4.6.1-stable_linux.x86_64 --path . --scene main.tscn --windowed --resolution 960x1056 --position 0,24 >/tmp/happy_lobby_instance_1.log 2>&1 &`
- `/home/luna/Godot/Editor/Godot_v4.6.1-stable_linux.x86_64 --path . --scene main.tscn --windowed --resolution 960x1056 --position 960,24 >/tmp/happy_lobby_instance_2.log 2>&1 &`

After finishing test steps, always scan logs for runtime issues:
- `rg -n "ERROR|SCRIPT ERROR|E [0-9]|Invalid|Failed|CRASH|Assertion" /tmp/happy_lobby_instance_1.log /tmp/happy_lobby_instance_2.log`

If matches are found:
- Include the relevant lines in your test report/PR notes.
- Do not claim a clean pass until the errors are triaged or explicitly called out.

Document manual verification steps in PRs until automated tests are added.

## Commit & Pull Request Guidelines
Recent commits mostly use short, imperative subjects (for example: `Add ...`, `Refactor ...`, `Enable ...`). Keep this pattern:
- Subject line in imperative mood, concise, and scoped to one change.
- Group related scene/script updates in a single commit.
- PRs should include: summary, testing performed, linked issue (if any), and screenshots/GIFs for UI or scene behavior changes.
