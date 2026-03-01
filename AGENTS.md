# Repository Guidelines

## Project Structure & Module Organization
This repository is a Godot 4.6 project rooted at `project.godot`, with `main.tscn` as the entry scene. Core gameplay and networking logic is split by domain:
- `game_world/`: world scene, player spawn, movement, and character scripts.
- `networking/`: session/lobby flow and Steam-facing integration.
- `char_editor/` and `ui_components/`: character editor scenes and reusable UI button scripts.
- `avatar/` and `assets/`: avatar logic, shaders/materials, and source art.
- `addons/`: vendored plugins (`godotsteam`, `plenticons`); avoid editing unless intentionally updating a dependency.

## Build, Test, and Development Commands
Use the Godot 4.6 editor for daily development.
- `godot4 --path .` launches the project.
- `godot4 --path . --scene main.tscn` runs the main scene directly.
- `godot4 --headless --path . --quit` performs a quick CI-style import/config sanity check.
- `godot4 --path . --export-debug "Linux/X11"` builds a debug export (preset must exist in `export_presets.cfg`).

If `godot4` is not in `PATH`, use the local editor binary configured in `.vscode/settings.json`.

## Coding Style & Naming Conventions
Follow existing GDScript conventions in this repo:
- Use 4-space indentation and UTF-8 encoding.
- Prefer `class_name` scripts for reusable components.
- Scene files use `snake_case.tscn`; script files use matching `snake_case.gd`.
- Keep autoload responsibilities centralized (`NetworkManager`, `SessionManager`) instead of duplicating state.
- Do not hand-edit `*.gd.uid` files; let Godot manage resource IDs.

## Testing Guidelines
There is no committed automated unit test framework yet. Validate changes with focused manual checks:
- Run two instances to test host/join flow on port `4242`.
- Verify late join behavior for player spawn/customization sync.
- For UI/editor changes, re-open affected scenes to confirm exported node paths and signal bindings.

Document manual verification steps in PRs until automated tests are added.

## Commit & Pull Request Guidelines
Recent commits mostly use short, imperative subjects (for example: `Add ...`, `Refactor ...`, `Enable ...`). Keep this pattern:
- Subject line in imperative mood, concise, and scoped to one change.
- Group related scene/script updates in a single commit.
- PRs should include: summary, testing performed, linked issue (if any), and screenshots/GIFs for UI or scene behavior changes.
