extends SceneTree
## Run against the exported PCK, not an editor cache containing excluded images.
var output := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output=arg.trim_prefix("--evidence-dir=")
	run.call_deferred()

func run() -> void:
	var rows: Array = []
	var passed := not output.is_empty()
	for path in ["res://assets/visual_fauna/aeral_runtime.glb","res://assets/visual_fauna/veyra_runtime.glb","res://assets/visual_fauna/morrow_runtime.glb","res://assets/models/rover.glb"]:
		var scene := load(path) as PackedScene
		var row := {"path":path,"scene_loaded":scene!=null,"textured_surfaces":0,"normal_surfaces":0,"roughness_surfaces":0}
		if scene!=null:
			var instance := scene.instantiate()
			for node in instance.find_children("*","MeshInstance3D",true,false):
				for surface in node.mesh.get_surface_count():
					var material := node.get_active_material(surface) as BaseMaterial3D
					if material==null: continue
					if material.albedo_texture!=null: row.textured_surfaces+=1
					if material.normal_texture!=null: row.normal_surfaces+=1
					if material.roughness_texture!=null: row.roughness_surfaces+=1
			instance.free()
		passed=passed and row.scene_loaded and row.textured_surfaces>0 and row.normal_surfaces>0 and row.roughness_surfaces>0
		rows.append(row)
	var world_script := load("res://scripts/world.gd") as Script
	var revision: int = world_script.get_script_constant_map().get("TERRAIN_REVISION",-1)
	var dependencies: Dictionary = {}
	for path in ["res://assets/alien_flora/listening-flora.glb","res://assets/alien_flora/habitat-layout.res","res://assets/alien_flora/lamina-veins-albedo.png","res://assets/alien_flora/lamina-veins-normal.png","res://assets/alien_flora/lamina-veins-roughness.png","res://assets/alien_renewal/terrain_v%d.res" % revision,"res://assets/alien_renewal/terrain_collision_v%d.res" % revision]:
		var resource := load(path)
		dependencies[path] = resource is Texture2D if path.ends_with(".png") else resource != null
		passed = passed and dependencies[path]
	var mipmaps: Dictionary = {}
	for path in ["res://assets/market_environment/cc0/Rock055_1K-JPG_Color.jpg","res://assets/market_environment/cc0/Rock055_1K-JPG_NormalGL.jpg","res://assets/market_environment/cc0/Ground045_1K-JPG_Color.jpg"]:
		var texture := load(path) as Texture2D
		var pixels := texture.get_image() if texture != null else null
		mipmaps[path] = pixels.get_mipmap_count() if pixels != null else -1
		passed = passed and int(mipmaps[path])>0
	var result := {"passed":passed,"kind":"actual_exported_pack_texture_dependencies","models":rows,"world_dependencies":dependencies,"world_texture_mipmap_counts":mipmaps}
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		var file := FileAccess.open(output.path_join("receipt.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(result,"  "))
	print("EXPORT_MATERIAL_CHECKS "+JSON.stringify(result))
	quit(0 if passed else 1)
