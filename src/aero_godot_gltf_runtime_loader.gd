class_name AeroGodotGltfRuntimeLoader
extends RefCounted

const _CONTRACT_CANDIDATE_PATHS: Array[String] = [
	"res://addons/aerobeat-vendor-godot-gltf/globals/aero_godot_gltf_contract.gd",
	"res://addons/aerobeat-vendor-godot-gltf/src/aero_godot_gltf_contract.gd",
	"res://../src/aero_godot_gltf_contract.gd",
]
const DEFAULT_MULTI_SCENE_NAME := "AeroGodotGltfInstances"
const DOWNLOAD_TEMP_DIRECTORY_NAME := "aerobeat-vendor-godot-gltf"
const HTTP_POLL_DELAY_MSEC := 10
const HTTP_CONNECT_TIMEOUT_MSEC := 10000
const HTTP_BODY_TIMEOUT_MSEC := 30000

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

	var resolved_source_result := _resolve_runtime_source(normalized_source)
	if not bool(resolved_source_result.get("ok", false)):
		_last_result = contract.call(
			"fail",
			String(resolved_source_result.get("code", "load_failed")),
			String(resolved_source_result.get("message", "GLTF source preparation failed.")),
			_dictionary_or_empty(resolved_source_result.get("detail", {}))
		)
		return _last_result

	var runtime_source: Dictionary = _dictionary_or_empty(resolved_source_result.get("source", {}))
	var runtime_detail: Dictionary = _dictionary_or_empty(resolved_source_result.get("detail", {}))
	var document: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var error: int = OK
	match String(runtime_source.get("kind", "file")):
		"file":
			error = document.append_from_file(
				String(runtime_source.get("path", "")),
				state,
				flags,
				String(runtime_source.get("base_path", ""))
			)
		"buffer":
			error = document.append_from_buffer(
				PackedByteArray(runtime_source.get("bytes", PackedByteArray())),
				String(runtime_source.get("base_path", "")),
				state,
				flags
			)
		_:
			error = ERR_INVALID_PARAMETER

	if error != OK:
		_cleanup_download_artifacts(runtime_detail)
		_last_result = contract.call(
			"fail",
			"load_failed",
			"Godot could not parse the requested GLTF/GLB source.",
			{
				"error": error,
				"error_name": error_string(error),
				"source": normalized_source,
				"resolved_source": runtime_source,
				"flags": flags,
				"download": _dictionary_or_empty(runtime_detail.get("download", {})),
			}
		)
		return _last_result

	_last_result = contract.call(
		"ok",
		{
			"source": normalized_source,
			"resolved_source": runtime_source,
			"download": _dictionary_or_empty(runtime_detail.get("download", {})),
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
		_cleanup_download_artifacts(detail)
		_last_result = contract.call(
			"fail",
			"scene_generation_failed",
			"Godot parsed the GLTF source but could not instantiate a scene.",
			{
				"source": detail.get("source", {}),
				"resolved_source": detail.get("resolved_source", {}),
				"download": detail.get("download", {}),
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
		_cleanup_download_artifacts(detail)
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

func unload_result(result: Dictionary) -> Dictionary:
	var contract: Script = _get_contract()
	if contract == null:
		_last_result = {
			"success": false,
			"code": "missing_contract",
			"message": "AeroGodotGltfContract could not be loaded.",
			"detail": {},
		}
		return _last_result

	var detail: Dictionary = _dictionary_or_empty(result.get("detail", result))
	var freed_roots := 0

	var scene_root := detail.get("scene", null) as Node
	if scene_root != null and is_instance_valid(scene_root):
		if scene_root.get_parent() != null:
			scene_root.get_parent().remove_child(scene_root)
		scene_root.queue_free()
		freed_roots += 1

	_cleanup_download_artifacts(detail)
	_last_result = contract.call("ok", {
		"unloaded": true,
		"freed_roots": freed_roots,
		"download": _dictionary_or_empty(detail.get("download", {})),
	})
	return _last_result

func unload_last_result() -> Dictionary:
	if _last_result.is_empty():
		var contract := _get_contract()
		if contract != null:
			return contract.call("ok", {"unloaded": false, "freed_roots": 0})
		return {
			"success": true,
			"detail": {"unloaded": false, "freed_roots": 0},
		}
	return unload_result(_last_result)

func get_last_result() -> Dictionary:
	return _last_result.duplicate(true)

func _get_contract() -> Script:
	return _contract_script

func _instance_name_for(requested_name: String, loaded_scene: Node, source: Dictionary, instance_index: int) -> String:
	if not requested_name.is_empty():
		return requested_name
	if loaded_scene != null and not String(loaded_scene.name).is_empty():
		return "%sInstance%d" % [loaded_scene.name, max(instance_index, 0)]
	var source_path := String(source.get("path", source.get("url", ""))).strip_edges()
	if not source_path.is_empty():
		return "%sInstance%d" % [source_path.get_file().get_basename(), max(instance_index, 0)]
	return "GltfInstance%d" % max(instance_index, 0)

func _resolve_runtime_source(source: Dictionary) -> Dictionary:
	var source_kind := String(source.get("kind", "file"))
	if source_kind != "url":
		return {
			"ok": true,
			"source": source.duplicate(true),
			"detail": {},
		}

	var download_result := _download_url_source(source)
	if not bool(download_result.get("ok", false)):
		return download_result

	return {
		"ok": true,
		"source": _dictionary_or_empty(download_result.get("source", {})),
		"detail": {
			"download": _dictionary_or_empty(download_result.get("download", {})),
		},
	}

func _download_url_source(source: Dictionary) -> Dictionary:
	var contract: Script = _get_contract()
	var url := String(source.get("url", source.get("path", ""))).strip_edges()
	var byte_result := _download_url_bytes(url)
	if not bool(byte_result.get("ok", false)):
		return byte_result

	var bytes: PackedByteArray = PackedByteArray(byte_result.get("bytes", PackedByteArray()))
	var format := String(source.get("format", "")).strip_edges().to_lower()
	var download_directory := _build_download_directory(url)
	var make_dir_error := DirAccess.make_dir_recursive_absolute(download_directory)
	if make_dir_error != OK:
		return {
			"ok": false,
			"code": "load_failed",
			"message": "Could not create a temporary directory for the GLTF URL download.",
			"detail": {
				"url": url,
				"download_directory": download_directory,
				"error": make_dir_error,
				"error_name": error_string(make_dir_error),
			},
		}

	var download_file_path := download_directory.path_join(_download_file_name_for(url, format))
	var file := FileAccess.open(download_file_path, FileAccess.WRITE)
	if file == null:
		DirAccess.remove_absolute(download_directory)
		return {
			"ok": false,
			"code": "load_failed",
			"message": "Could not write the GLTF URL download to a temporary file.",
			"detail": {
				"url": url,
				"download_file_path": download_file_path,
			},
		}
	file.store_buffer(bytes)
	file.close()

	return {
		"ok": true,
		"source": {
			"kind": "file",
			"path": download_file_path,
			"url": url,
			"base_path": download_directory,
			"bytes": PackedByteArray(),
			"format": format,
			"location": contract.get("LOCATION_EXTERNAL") if contract != null else "external",
			"metadata": _dictionary_or_empty(source.get("metadata", {})),
		},
		"download": {
			"url": url,
			"directory": download_directory,
			"file_path": download_file_path,
			"response_code": int(byte_result.get("response_code", 0)),
			"headers": _array_or_empty(byte_result.get("headers", [])),
		},
	}

func _download_url_bytes(url: String) -> Dictionary:
	var parsed_url := _parse_http_url(url)
	if parsed_url.is_empty():
		return {
			"ok": false,
			"code": "invalid_source",
			"message": "GLTF URL sources require an http:// or https:// URL.",
			"detail": {"url": url},
		}

	var client := HTTPClient.new()
	var tls_options: TLSOptions = TLSOptions.client() if bool(parsed_url.get("https", false)) else null
	var connect_error := client.connect_to_host(
		String(parsed_url.get("host", "")),
		int(parsed_url.get("port", 80)),
		tls_options
	)
	if connect_error != OK:
		return {
			"ok": false,
			"code": "load_failed",
			"message": "Could not connect to the requested GLTF URL host.",
			"detail": {
				"url": url,
				"error": connect_error,
				"error_name": error_string(connect_error),
			},
		}

	var connect_deadline := Time.get_ticks_msec() + HTTP_CONNECT_TIMEOUT_MSEC
	while client.get_status() == HTTPClient.STATUS_CONNECTING or client.get_status() == HTTPClient.STATUS_RESOLVING:
		client.poll()
		if Time.get_ticks_msec() > connect_deadline:
			return {
				"ok": false,
				"code": "load_failed",
				"message": "Timed out while connecting to the requested GLTF URL host.",
				"detail": {"url": url},
			}
		OS.delay_msec(HTTP_POLL_DELAY_MSEC)

	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		return {
			"ok": false,
			"code": "load_failed",
			"message": "The GLTF URL connection did not reach a connected state.",
			"detail": {"url": url, "status": client.get_status()},
		}

	var request_error := client.request(
		HTTPClient.METHOD_GET,
		String(parsed_url.get("request_path", "/")),
		PackedStringArray(["User-Agent: AeroBeatVendorGodotGLTF/0.3.0"])
	)
	if request_error != OK:
		return {
			"ok": false,
			"code": "load_failed",
			"message": "Could not request the GLTF URL payload.",
			"detail": {
				"url": url,
				"error": request_error,
				"error_name": error_string(request_error),
			},
		}

	var body_deadline := Time.get_ticks_msec() + HTTP_BODY_TIMEOUT_MSEC
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		if Time.get_ticks_msec() > body_deadline:
			return {
				"ok": false,
				"code": "load_failed",
				"message": "Timed out while requesting the GLTF URL payload.",
				"detail": {"url": url},
			}
		OS.delay_msec(HTTP_POLL_DELAY_MSEC)

	var response_code := client.get_response_code()
	var response_headers := client.get_response_headers()
	if response_code < 200 or response_code >= 300:
		return {
			"ok": false,
			"code": "load_failed",
			"message": "The GLTF URL returned a non-success HTTP status.",
			"detail": {
				"url": url,
				"response_code": response_code,
				"headers": response_headers,
			},
		}

	var body := PackedByteArray()
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk := client.read_response_body_chunk()
		if not chunk.is_empty():
			body.append_array(chunk)
		elif Time.get_ticks_msec() > body_deadline:
			return {
				"ok": false,
				"code": "load_failed",
				"message": "Timed out while downloading the GLTF URL payload.",
				"detail": {"url": url, "response_code": response_code},
			}
		OS.delay_msec(HTTP_POLL_DELAY_MSEC)

	return {
		"ok": true,
		"bytes": body,
		"response_code": response_code,
		"headers": response_headers,
	}

func _parse_http_url(url: String) -> Dictionary:
	var trimmed := url.strip_edges()
	var https := trimmed.begins_with("https://")
	var http := trimmed.begins_with("http://")
	if not https and not http:
		return {}

	var scheme_separator_index := trimmed.find("://")
	if scheme_separator_index == -1:
		return {}

	var remainder := trimmed.substr(scheme_separator_index + 3)
	var slash_index := remainder.find("/")
	var host_port := remainder
	var request_path := "/"
	if slash_index != -1:
		host_port = remainder.substr(0, slash_index)
		request_path = remainder.substr(slash_index)
	if host_port.is_empty():
		return {}

	var host := host_port
	var port := 443 if https else 80
	var colon_index := host_port.rfind(":")
	if colon_index > 0 and host_port.find("]") == -1:
		host = host_port.substr(0, colon_index)
		port = int(host_port.substr(colon_index + 1))

	if host.is_empty():
		return {}

	return {
		"https": https,
		"host": host,
		"port": port,
		"request_path": request_path,
	}

func _build_download_directory(url: String) -> String:
	var tmp_root := OS.get_environment("TMPDIR")
	if tmp_root.is_empty():
		tmp_root = "/tmp"
	return tmp_root.path_join(DOWNLOAD_TEMP_DIRECTORY_NAME).path_join(str(Time.get_unix_time_from_system())).path_join(str(abs(url.hash())))

func _download_file_name_for(url: String, format: String) -> String:
	var pathish := url.split("#", false, 1)[0].split("?", false, 1)[0]
	var file_name := pathish.get_file()
	if file_name.is_empty():
		file_name = "downloaded-model.%s" % format
	if file_name.get_extension().strip_edges().to_lower().is_empty():
		file_name += ".%s" % format
	return file_name

func _cleanup_download_artifacts(detail: Dictionary) -> void:
	var download: Dictionary = _dictionary_or_empty(detail.get("download", {}))
	var file_path := String(download.get("file_path", "")).strip_edges()
	var directory := String(download.get("directory", "")).strip_edges()
	if not file_path.is_empty() and FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
	if not directory.is_empty():
		DirAccess.remove_absolute(directory)

func _dictionary_or_empty(value: Variant) -> Dictionary:
	if value is Dictionary:
		return Dictionary(value).duplicate(true)
	return {}

func _array_or_empty(value: Variant) -> Array:
	if value is Array:
		return Array(value).duplicate(true)
	return []

static func _load_first_script(candidate_paths: Array[String]) -> Script:
	for candidate_path in candidate_paths:
		if ResourceLoader.exists(candidate_path, "Script"):
			return load(candidate_path)
	return null
