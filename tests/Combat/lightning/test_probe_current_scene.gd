extends GutTest

func test_probe_current_scene() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var cs: Node = tree.current_scene if tree != null else null
	print("GUT-PROBE current_scene=", cs)
	print("GUT-PROBE root children=", tree.root.get_children().map(func(c): return c.name) if tree != null else "no tree")
