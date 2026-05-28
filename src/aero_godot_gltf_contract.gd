class_name AeroGodotGltfContract
extends RefCounted

const RESULT_SUCCESS := "success"
const RESULT_CODE := "code"
const RESULT_MESSAGE := "message"
const RESULT_DETAIL := "detail"

const SOURCE_KIND_FILE := "file"
const SOURCE_KIND_BUFFER := "buffer"
const SOURCE_KIND_URL := "url"
const SOURCE_KINDS := [
	SOURCE_KIND_FILE,
	SOURCE_KIND_BUFFER,
	SOURCE_KIND_URL,
]

const LOCATION_PACKAGED := "packaged"
const LOCATION_EXTERNAL := "external"
const LOCATION_REMOTE := "remote"
const LOCATIONS := [
	LOCATION_PACKAGED,
	LOCATION_EXTERNAL,
	LOCATION_REMOTE,
]

const FORMAT_GLTF := "gltf"
const FORMAT_GLB := "glb"
const FORMATS := [
	FORMAT_GLTF,
	FORMAT_GLB,
]

const ERROR_INVALID_SOURCE := "invalid_source"
const ERROR_UNSUPPORTED_FORMAT := "unsupported_format"
const ERROR_LOAD_FAILED := "load_failed"
const ERROR_SCENE_GENERATION_FAILED := "scene_generation_failed"
const ERROR_INVALID_LOAD_RESULT := "invalid_load_result"

static func get_default_source() -> Dictionary:
	return {
		"kind": SOURCE_KIND_FILE,
		"path": "",
		"url": "",
		"base_path": "",
		"bytes": PackedByteArray(),
		"format": "",
		"location": "",
		"metadata": {},
	}

static func get_default_transform() -> Dictionary:
	return {
		"position": Vector3.ZERO,
		"rotation_degrees": Vector3.ZERO,
		"scale": Vector3.ONE,
	}

static func get_default_instance() -> Dictionary:
	return {
		"name": "",
		"source": get_default_source(),
		"transform": get_default_transform(),
		"metadata": {},
	}

static func normalize_source(source: Dictionary) -> Dictionary:
	var normalized := get_default_source()
	for key in source.keys():
		normalized[key] = source[key]

	normalized["kind"] = String(normalized.get("kind", SOURCE_KIND_FILE)).strip_edges().to_lower()
	normalized["path"] = String(normalized.get("path", "")).strip_edges()
	normalized["url"] = String(normalized.get("url", "")).strip_edges()
	normalized["base_path"] = String(normalized.get("base_path", "")).strip_edges()
	normalized["format"] = String(normalized.get("format", "")).strip_edges().to_lower()
	normalized["location"] = String(normalized.get("location", "")).strip_edges().to_lower()

	if typeof(normalized.get("metadata", {})) != TYPE_DICTIONARY:
		normalized["metadata"] = {}

	if typeof(normalized.get("bytes", PackedByteArray())) != TYPE_PACKED_BYTE_ARRAY:
		normalized["bytes"] = PackedByteArray()

	if normalized["kind"].is_empty():
		normalized["kind"] = _infer_source_kind(normalized)

	if normalized["kind"] == SOURCE_KIND_FILE and normalized["path"].is_empty() and not normalized["url"].is_empty():
		normalized["kind"] = SOURCE_KIND_URL

	if normalized["kind"] == SOURCE_KIND_URL and normalized["url"].is_empty() and is_http_url(normalized["path"]):
		normalized["url"] = normalized["path"]

	match String(normalized.get("kind", SOURCE_KIND_FILE)):
		SOURCE_KIND_FILE:
			if normalized["format"].is_empty():
				normalized["format"] = infer_format_from_path(normalized["path"])
			if normalized["location"].is_empty():
				normalized["location"] = infer_location_from_path(normalized["path"])
			if normalized["base_path"].is_empty() and normalized["path"].begins_with("res://"):
				normalized["base_path"] = normalized["path"].get_base_dir()
		SOURCE_KIND_URL:
			if normalized["format"].is_empty():
				normalized["format"] = infer_format_from_url(normalized["url"])
			if normalized["location"].is_empty():
				normalized["location"] = LOCATION_REMOTE
		SOURCE_KIND_BUFFER:
			if normalized["location"].is_empty():
				normalized["location"] = LOCATION_EXTERNAL
		_:
			pass

	return normalized

static func validate_source(source: Dictionary) -> Dictionary:
	var normalized := normalize_source(source)
	if not SOURCE_KINDS.has(normalized.get("kind", SOURCE_KIND_FILE)):
		return {
			"field": "kind",
			"message": "GLTF source kind must be one of %s." % ", ".join(SOURCE_KINDS),
			"source": normalized.duplicate(true),
		}

	var source_kind := String(normalized.get("kind", SOURCE_KIND_FILE))
	match source_kind:
		SOURCE_KIND_FILE:
			if String(normalized.get("path", "")).is_empty():
				return {
					"field": "path",
					"message": "GLTF file sources require a non-empty path.",
					"source": normalized.duplicate(true),
				}
			if String(normalized.get("format", "")).is_empty():
				return {
					"field": "format",
					"message": "GLTF file sources must resolve to a .gltf or .glb path.",
					"source": normalized.duplicate(true),
				}
		SOURCE_KIND_BUFFER:
			if PackedByteArray(normalized.get("bytes", PackedByteArray())).is_empty():
				return {
					"field": "bytes",
					"message": "GLTF buffer sources require non-empty bytes.",
					"source": normalized.duplicate(true),
				}
		SOURCE_KIND_URL:
			if String(normalized.get("url", "")).is_empty():
				return {
					"field": "url",
					"message": "GLTF URL sources require a non-empty URL.",
					"source": normalized.duplicate(true),
				}
			if String(normalized.get("format", "")).is_empty():
				return {
					"field": "format",
					"message": "GLTF URL sources must resolve to a .gltf or .glb URL.",
					"source": normalized.duplicate(true),
				}
		_:
			return {
				"field": "kind",
				"message": "GLTF source kind must be one of %s." % ", ".join(SOURCE_KINDS),
				"source": normalized.duplicate(true),
			}

	if not FORMATS.has(normalized.get("format", "")):
		return {
			"field": "format",
			"message": "GLTF format must be one of %s." % ", ".join(FORMATS),
			"source": normalized.duplicate(true),
		}

	if not LOCATIONS.has(normalized.get("location", "")):
		return {
			"field": "location",
			"message": "GLTF source location must be one of %s." % ", ".join(LOCATIONS),
			"source": normalized.duplicate(true),
		}

	return {}

static func normalize_transform(transform_config: Dictionary) -> Dictionary:
	var normalized := get_default_transform()
	for key in transform_config.keys():
		normalized[key] = transform_config[key]

	normalized["position"] = variant_to_vector3(normalized.get("position", Vector3.ZERO), Vector3.ZERO)
	normalized["rotation_degrees"] = variant_to_vector3(normalized.get("rotation_degrees", Vector3.ZERO), Vector3.ZERO)
	normalized["scale"] = variant_to_vector3(normalized.get("scale", Vector3.ONE), Vector3.ONE)
	return normalized

static func normalize_instance(instance: Dictionary) -> Dictionary:
	var normalized := get_default_instance()
	for key in instance.keys():
		normalized[key] = instance[key]

	normalized["name"] = String(normalized.get("name", "")).strip_edges()
	if typeof(normalized.get("source", {})) != TYPE_DICTIONARY:
		normalized["source"] = {}
	if typeof(normalized.get("transform", {})) != TYPE_DICTIONARY:
		normalized["transform"] = {}
	if typeof(normalized.get("metadata", {})) != TYPE_DICTIONARY:
		normalized["metadata"] = {}

	normalized["source"] = normalize_source(normalized["source"])
	normalized["transform"] = normalize_transform(normalized["transform"])
	return normalized

static func validate_instance(instance: Dictionary) -> Dictionary:
	var normalized := normalize_instance(instance)
	var source_validation := validate_source(normalized.get("source", {}))
	if not source_validation.is_empty():
		return {
			"field": "source",
			"message": "GLTF instance source validation failed.",
			"instance": normalized.duplicate(true),
			"source_validation": source_validation.duplicate(true),
		}
	return {}

static func infer_format_from_path(path: String) -> String:
	var extension := _clean_extension(path)
	if extension in FORMATS:
		return extension
	return ""

static func infer_format_from_url(url: String) -> String:
	return infer_format_from_path(_pathish_part(url))

static func infer_location_from_path(path: String) -> String:
	if is_http_url(path):
		return LOCATION_REMOTE
	if path.begins_with("res://"):
		return LOCATION_PACKAGED
	if path.begins_with("user://"):
		return LOCATION_EXTERNAL
	if path.is_absolute_path():
		return LOCATION_EXTERNAL
	return LOCATION_EXTERNAL

static func is_http_url(value: String) -> bool:
	var normalized := value.strip_edges().to_lower()
	return normalized.begins_with("http://") or normalized.begins_with("https://")

static func variant_to_vector3(value: Variant, default_value: Vector3) -> Vector3:
	if value is Vector3:
		return value
	if value is Array:
		var array_value: Array = value
		if array_value.size() >= 3:
			return Vector3(float(array_value[0]), float(array_value[1]), float(array_value[2]))
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return Vector3(
			float(dictionary_value.get("x", default_value.x)),
			float(dictionary_value.get("y", default_value.y)),
			float(dictionary_value.get("z", default_value.z))
		)
	return default_value

static func ok(detail: Dictionary = {}) -> Dictionary:
	return {
		RESULT_SUCCESS: true,
		RESULT_DETAIL: detail.duplicate(true),
	}

static func fail(code: String, message: String, detail: Dictionary = {}) -> Dictionary:
	return {
		RESULT_SUCCESS: false,
		RESULT_CODE: code,
		RESULT_MESSAGE: message,
		RESULT_DETAIL: detail.duplicate(true),
	}

static func _infer_source_kind(source: Dictionary) -> String:
	if not String(source.get("url", "")).strip_edges().is_empty():
		return SOURCE_KIND_URL
	if is_http_url(String(source.get("path", "")).strip_edges()):
		return SOURCE_KIND_URL
	if not PackedByteArray(source.get("bytes", PackedByteArray())).is_empty():
		return SOURCE_KIND_BUFFER
	return SOURCE_KIND_FILE

static func _clean_extension(pathish: String) -> String:
	var working := _pathish_part(pathish)
	var extension := working.get_extension().strip_edges().to_lower()
	return extension.trim_prefix(".")

static func _pathish_part(pathish: String) -> String:
	var without_fragment := String(pathish).strip_edges().split("#", false, 1)[0]
	return without_fragment.split("?", false, 1)[0]
