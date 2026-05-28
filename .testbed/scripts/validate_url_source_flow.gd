extends SceneTree

const DEFAULT_REMOTE_URL := "http://127.0.0.1:8123/alien-planet.glb"
const LOADER_CANDIDATE_PATHS := [
	"res://addons/aerobeat-vendor-godot-gltf/src/aero_godot_gltf_runtime_loader.gd",
	"res://../src/aero_godot_gltf_runtime_loader.gd",
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var loader: Variant = _create_loader()
	if loader == null:
		_fail("Could not create the vendor runtime loader")
		return
	var url := OS.get_environment("AEROBEAT_GLTF_TEST_URL")
	if url.is_empty():
		url = DEFAULT_REMOTE_URL
	var result: Dictionary = loader.load_scene({"url": url, "format": "glb"})
	if not bool(result.get("success", false)):
		_fail("URL source load failed: %s" % result.get("message", "unknown"))
		return
	var scene_root := result.get("detail", {}).get("scene", null) as Node
	if scene_root == null:
		_fail("URL source load did not produce a scene root")
		return
	var unload_result: Dictionary = loader.unload_result(result)
	if not bool(unload_result.get("success", false)):
		_fail("URL source unload failed")
		return
	print("[validate-vendor-url-source-flow] OK url=%s" % url)
	quit(0)

func _create_loader() -> Variant:
	for candidate_path in LOADER_CANDIDATE_PATHS:
		if not ResourceLoader.exists(candidate_path, "Script"):
			continue
		var script_resource: Variant = load(candidate_path)
		if script_resource != null and script_resource.has_method("new"):
			return script_resource.new()
	return null

func _fail(message: String) -> void:
	push_error("[validate-vendor-url-source-flow] %s" % message)
	quit(1)
