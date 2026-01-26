# Copilot instructions (HappyLobby)

## Project snapshot
- Godot **4.6** project (see `project.godot`), written in **GDScript**.
- Entry scene is `main.tscn` (`[application]/run/main_scene`).
- Two key **autoload singletons** (see `[autoload]` in `project.godot`):
  - `SessionManager` (`SessionManager.gd`)
  - `NetworkManager` (`networking/NetworkManager.gd`)

## Architecture + data flow
- `NetworkManager` owns platform identity and Steam integration:
  - Decides Steam vs local based on `SessionManager.USING_STEAM`.
  - Creates/hosts a `Lobby` child node (`networking/lobby/lobby.gd`).
  - Stores local identity in `user://local_user_id` when Steam is off.
- `SessionManager` owns the active multiplayer peer and player roster:
  - Uses **ENet** (`ENetMultiplayerPeer`) on port **4242**.
  - Connects to Godot multiplayer signals (`connected_to_server`, `peer_connected`, etc.).
  - Keeps `connected_players` as an `Array[Dictionary]` with keys like `id`, `username`, `steam_id`, `character`.
- `GameWorld` is the gameplay/network boundary:
  - The active instance is discovered via group **"GameWorld"** (`get_first_node_in_group`).
  - Spawning/despawning happens in `game_world/game_world.gd`.

## Multiplayer model (important)
- This project is **server-authoritative**.
  - `SessionManager.create_local_lobby()` creates a server and spawns player 1.
  - `GameWorld.spawn_player_character()` only runs on server and calls `_spawn_player_on_clients.rpc(...)`.
  - Movement is simulated on the **server** in `game_world/character_movement.gd` and position is broadcast via an `@rpc(..., "unreliable")` sync.
- When adding netcode, follow the existing pattern:
  - Gate server-only logic with `if not multiplayer.is_server(): return`.
  - Prefer `@rpc("authority", "call_remote", "unreliable")` for high-frequency transforms.
  - Use `set_multiplayer_authority(id)` on spawned player nodes (see `game_world/char.gd` + `game_world/game_world.gd`).

## Steam integration
- GodotSteam addon is vendored under `addons/godotsteam/`.
- Steam settings are in `project.godot` under `[steam]` (App ID currently **480** / Spacewar).
- Steam is currently disabled by default via `SessionManager.USING_STEAM = false`.
  - If you enable Steam, keep logic routed through `NetworkManager` / `NetworkManager.lobby`.
  - Lobby code is in `networking/lobby/lobby.gd`; lobby-list UI uses `networking/lobby/popups/lobby_finder_window.gd`.

## UI patterns
- Main menu buttons are small `class_name` scripts under `ui_components/` and call into singletons.
  - Example: `ui_components/create_lobby_button.gd` hosts locally when Steam is off.
- Pop-up windows are created via static factories that load scenes and attach to the root.
  - Example: `LobbyFinderWindow.create_window(get_tree())` in `networking/lobby/popups/lobby_finder_window.gd`.

## Persistence
- Local character customization is stored as JSON at `user://user_char.json` (see `Character.store_save/load_save` in `game_world/char.gd`).
- Local (non-Steam) user id is persisted to `user://local_user_id` (see `NetworkManager.get_local_user_id`).

## Repo conventions (don’ts + gotchas)
- Don’t hand-edit `project.godot` unless necessary; prefer changing settings via the Godot editor.
- Don’t touch `*.gd.uid` / `*.tscn` UID references unless you understand Godot’s resource UID system.
- Scripts commonly use `class_name` and scene unique-node access via `%NodeName` (see `game_world/game_world.gd`).

## Dev workflow (Windows)
- Open the folder in the Godot editor and run `main.tscn`.
- Local multiplayer quick check:
  - Run two instances; on one press **Host Local Lobby**, on the other press **Join Lobby** (joins `localhost`).
  - Default port is `4242`.
