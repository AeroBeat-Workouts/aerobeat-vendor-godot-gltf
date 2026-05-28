class_name AeroGodotGltfRuntimeLoader
extends RefCounted

const _CONTRACT_CANDIDATE_PATHS: Array[String] = [
	"res://addons/aerobeat-vendor-godot-gltf/src/aero_godot_gltf_contract.gd",
	"res://../src/aero_godot_gltf_contract.gd",
]
const DEFAULT_MULTI_SCENE_NAME := "AeroGodotGltfInstances"

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

func load_scene_instance(source: Dictionary, flags: int = 0, scene_options: Dictionary = {}, instance_options: Dictionary = {}) -> Dictionary:
	var scene_result: Dictionary = load_scene(source, flags, scene_options)
	if not bool(scene_result.get("success", false)):
		return scene_result
	return instantiate_scene_instance(scene_result, instance_options)

func instantiate_scene_instance(load_result: Dictionary, instance_options: Dictionary = {}) -> Dictionary:
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
			"GLTF instance generation requires a successful load result.",
			{"load_result": load_result}
		)
		return _last_result

	var detail: Dictionary = load_result.get("detail", {}).duplicate(true)
	var loaded_scene: Node = detail.get("scene") as Node
	if loaded_scene == null:
		var regenerated_result: Dictionary = generate_scene(load_result)
		if not bool(regenerated_result.get("success", false)):
			return regenerated_result
		detail = regenerated_result.get("detail", {}).duplicate(true)
		loaded_scene = detail.get("scene") as Node

	if loaded_scene == null:
		_last_result = contract.call(
			"fail",
			"scene_generation_failed",
			"GLTF instance generation requires an instantiated scene root.",
			{"load_result": load_result}
		)
		return _last_result

	var normalized_transform: Dictionary = contract.call("normalize_transform", _dictionary_or_empty(instance_options.get("transform", {})))
	var instance_name := String(instance_options.get("name", "")).strip_edges()
	var instance_index := int(instance_options.get("index", -1))
	var metadata := _dictionary_or_empty(instance_options.get("metadata", {}))

	var instance_root := Node3D.new()
	instance_root.name = _instance_name_for(instance_name, loaded_scene, detail.get("source", {}), instance_index)
	instance_root.position = normalized_transform.get("position", Vector3.ZERO)
	instance_root.rotation_degrees = normalized_transform.get("rotation_degrees", Vector3.ZERO)
	instance_root.scale = normalized_transform.get("scale", Vector3.ONE)
	instance_root.add_child(loaded_scene)

	var instance_detail := detail.duplicate(true)
	instance_detail["scene"] = instance_root
	instance_detail["scene_name"] = instance_root.name
	instance_detail["instance_root"] = instance_root
	instance_detail["loaded_scene"] = loaded_scene
	instance_detail["loaded_scene_name"] = loaded_scene.name
	instance_detail["instance"] = {
		"name": instance_root.name,
		"transform": normalized_transform.duplicate(true),
		"metadata": metadata,
	}
	_last_result = contract.call("ok", instance_detail)
	return _last_result

func load_scene_instances(instances: Array, flags: int = 0, scene_options: Dictionary = {}) -> Dictionary:
	var contract: Script = _get_contract()
	if contract == null:
		_last_result = {
			"success": false,
			"code": "missing_contract",
			"message": "AeroGodotGltfContract could not be loaded.",
			"detail": {},
		}
		return _last_result

	if instances.is_empty():
		_last_result = contract.call(
			"fail",
			"invalid_source",
			"GLTF multi-instance loads require at least one instance descriptor.",
			{"instances": []}
		)
		return _last_result

	var aggregate_root := Node3D.new()
	aggregate_root.name = String(scene_options.get("root_name", DEFAULT_MULTI_SCENE_NAME)).strip_edges()
	if aggregate_root.name.is_empty():
		aggregate_root.name = DEFAULT_MULTI_SCENE_NAME

	var instance_results: Array = []
	for index in range(instances.size()):
		if not (instances[index] is Dictionary):
			aggregate_root.free()
			_last_result = contract.call(
				"fail",
				"invalid_source",
				"GLTF multi-instance loads require Dictionary descriptors.",
				{"index": index, "instance": instances[index]}
			)
			return _last_result

		var normalized_instance: Dictionary = contract.call("normalize_instance", instances[index])
		var validation_error: Dictionary = contract.call("validate_instance", normalized_instance)
		if not validation_error.is_empty():
			aggregate_root.free()
			_last_result = contract.call(
				"fail",
				"invalid_source",
				"GLTF instance validation failed.",
				{
					"index": index,
					"instance": normalized_instance,
					"validation_error": validation_error,
				}
			)
			return _last_result

		var instance_result := load_scene_instance(
			normalized_instance.get("source", {}),
			flags,
			scene_options,
			{
				"index": index,
				"name": normalized_instance.get("name", ""),
				"transform": normalized_instance.get("transform", {}),
				"metadata": normalized_instance.get("metadata", {}),
			}
		)
		if not bool(instance_result.get("success", false)):
			aggregate_root.free()
			return instance_result

		var instance_detail: Dictionary = instance_result.get("detail", {}).duplicate(true)
		var instance_root := instance_detail.get("instance_root") as Node3D
		if instance_root == null:
			aggregate_root.free()
			_last_result = contract.call(
				"fail",
				"scene_generation_failed",
				"GLTF instance generation did not return an instance root.",
				{"index": index, "instance": normalized_instance}
			)
			return _last_result

		aggregate_root.add_child(instance_root)
		instance_results.append(instance_detail)

	_last_result = contract.call(
		"ok",
		{
			"scene": aggregate_root,
			"scene_name": aggregate_root.name,
			"instances": instance_results,
			"flags": flags,
		}
	)
	return _last_result

func get_last_result() -> Dictionary:
	return _last_result.duplicate(true)

func _get_contract() -> Script:
	return _contract_script

func _instance_name_for(requested_name: String, loaded_scene: Node, source: Dictionary, instance_index: int) -> String:
	if not requested_name.is_empty():
		return requested_name
	if loaded_scene != null and not String(loaded_scene.name).is_empty():
		return "%sInstance%d" % [loaded_scene.name, max(instance_index, 0)]
	var source_path := String(source.get("path", "")).strip_edges()
	if not source_path.is_empty():
		return "%sInstance%d" % [source_path.get_file().get_basename(), max(instance_index, 0)]
	return "GltfInstance%d" % max(instance_index, 0)

func _dictionary_or_empty(value: Variant) -> Dictionary:
	if value is Dictionary:
		return Dictionary(value).duplicate(true)
	return {}

static func _load_first_script(candidate_paths: Array[String]) -> Script:
	for candidate_path in candidate_paths:
		if ResourceLoader.exists(candidate_path, "Script"):
			return load(candidate_path)
	return null
