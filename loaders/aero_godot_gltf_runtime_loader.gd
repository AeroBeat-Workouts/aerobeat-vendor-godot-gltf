class_name AeroGodotGltfRuntimeLoader
extends RefCounted

const _CONTRACT_CANDIDATE_PATHS: Array[String] = [
	"res://../globals/aero_godot_gltf_contract.gd",
	"res://addons/aerobeat-vendor-godot-gltf/globals/aero_godot_gltf_contract.gd",
]

static var _contract_script: Script = _load_first_script(_CONTRACT_CANDIDATE_PATHS)

var _last_result: Dictionary = {}

func load_source(source: Dictionary, flags: int = 0) -> Dictionary:
	var contract: Script = _get_contract()
	if contract == null:
		_last_result = {
			"success": false,
			"code": "missing_contract",
			"message": "AeroGodotGltfContract could not be loaded.",
			"detail": {},
		}
		return _last_result

	var normalized_source: Dictionary = contract.call("normalize_source", source)
	var validation_error: Dictionary = contract.call("validate_source", normalized_source)
	if not validation_error.is_empty():
		_last_result = contract.call(
			"fail",
			"invalid_source",
			"GLTF source validation failed.",
			{"validation_error": validation_error, "source": normalized_source}
		)
		return _last_result

	var document: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var error: int = OK
	match String(normalized_source.get("kind", "file")):
		"file":
			error = document.append_from_file(
				String(normalized_source.get("path", "")),
				state,
				flags,
				String(normalized_source.get("base_path", ""))
			)
		"buffer":
			error = document.append_from_buffer(
				PackedByteArray(normalized_source.get("bytes", PackedByteArray())),
				String(normalized_source.get("base_path", "")),
				state,
				flags
			)
		_:
			error = ERR_INVALID_PARAMETER

	if error != OK:
		_last_result = contract.call(
			"fail",
			"load_failed",
			"Godot could not parse the requested GLTF/GLB source.",
			{
				"error": error,
				"error_name": error_string(error),
				"source": normalized_source,
				"flags": flags,
			}
		)
		return _last_result

	_last_result = contract.call(
		"ok",
		{
			"source": normalized_source,
			"flags": flags,
			"document": document,
			"state": state,
		}
	)
	return _last_result

func generate_scene(load_result: Dictionary, bake_fps: float = 30.0, trimming: bool = false, remove_immutable_tracks: bool = true) -> Dictionary:
	var contract: Script = _get_contract()
	if contract == null:
		_last_result = {
			"success": false,
			"code": "missing_contract",
			"message": "AeroGodotGltfContract could not be loaded.",
			"detail": {},
		}
		return _last_result

	if not bool(load_result.get("success", false)):
		_last_result = contract.call(
			"fail",
			"invalid_load_result",
			"GLTF scene generation requires a successful load result.",
			{"load_result": load_result}
		)
		return _last_result

	var detail: Dictionary = load_result.get("detail", {})
	var document: GLTFDocument = detail.get("document") as GLTFDocument
	var state: GLTFState = detail.get("state") as GLTFState
	if document == null or state == null:
		_last_result = contract.call(
			"fail",
			"invalid_load_result",
			"GLTF scene generation requires a GLTFDocument and GLTFState.",
			{"load_result": load_result}
		)
		return _last_result

	var root_node: Node = document.generate_scene(state, bake_fps, trimming, remove_immutable_tracks)
	if root_node == null:
		_last_result = contract.call(
			"fail",
			"scene_generation_failed",
			"Godot parsed the GLTF source but could not instantiate a scene.",
			{
				"source": detail.get("source", {}),
				"bake_fps": bake_fps,
				"trimming": trimming,
				"remove_immutable_tracks": remove_immutable_tracks,
			}
		)
		return _last_result

	var scene_detail: Dictionary = detail.duplicate(true)
	scene_detail["scene"] = root_node
	scene_detail["scene_name"] = root_node.name
	_last_result = contract.call("ok", scene_detail)
	return _last_result

func load_scene(source: Dictionary, flags: int = 0, scene_options: Dictionary = {}) -> Dictionary:
	var load_result: Dictionary = load_source(source, flags)
	if not bool(load_result.get("success", false)):
		return load_result

	return generate_scene(
		load_result,
		float(scene_options.get("bake_fps", 30.0)),
		bool(scene_options.get("trimming", false)),
		bool(scene_options.get("remove_immutable_tracks", true))
	)

func get_last_result() -> Dictionary:
	return _last_result.duplicate(true)

func _get_contract() -> Script:
	return _contract_script

static func _load_first_script(candidate_paths: Array[String]) -> Script:
	for candidate_path in candidate_paths:
		if ResourceLoader.exists(candidate_path, "Script"):
			return load(candidate_path)
	return null
