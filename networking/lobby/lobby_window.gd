class_name LobbyWindow
extends Window


static func create_window(scene_tree:SceneTree) -> LobbyWindow:
	var new_window:LobbyWindow = ResourceLoader.load("res://networking/lobby/lobby_window.tscn").instantiate() as LobbyWindow
	scene_tree.root.add_child(new_window)
	return new_window