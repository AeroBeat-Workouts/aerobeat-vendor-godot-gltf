class_name AeroGodotGltfContract
extends RefCounted

const RESULT_SUCCESS := "success"
const RESULT_CODE := "code"
const RESULT_MESSAGE := "message"
const RESULT_DETAIL := "detail"

const SOURCE_KIND_FILE := "file"
const SOURCE_KIND_BUFFER := "buffer"
const SOURCE_KINDS := [
	SOURCE_KIND_FILE,
	SOURCE_KIND_BUFFER,
]

const LOCATION_PACKAGED := "packaged"
const LOCATION_EXTERNAL := "external"
const LOCATIONS := [
	LOCATION_PACKAGED,
	LOCATION_EXTERNAL,
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
		"base_path": "",
		"bytes": PackedByteArray(),
		"format": "",
		"location": "",
		"metadata": {},
	}

static func normalize_source(source: Dictionary) -> Dictionary:
	var normalized := get_default_source()
	for key in source.keys():
		normalized[key] = source[key]

	normalized["kind"] = String(normalized.get("kind", SOURCE_KIND_FILE)).strip_edges().to_lower()
	normalized["path"] = String(normalized.get("path", "")).strip_edges()
	normalized["base_path"] = String(normalized.get("base_path", "")).strip_edges()
	normalized["format"] = String(normalized.get("format", "")).strip_edges().to_lower()
	normalized["location"] = String(normalized.get("location", "")).strip_edges().to_lower()

	if typeof(normalized.get("metadata", {})) != TYPE_DICTIONARY:
		normalized["metadata"] = {}

	if typeof(normalized.get("bytes", PackedByteArray())) != TYPE_PACKED_BYTE_ARRAY:
		normalized["bytes"] = PackedByteArray()

	if normalized["kind"] == SOURCE_KIND_FILE:
		if normalized["format"].is_empty():
			normalized["format"] = infer_format_from_path(normalized["path"])
		if normalized["location"].is_empty():
			normalized["location"] = infer_location_from_path(normalized["path"])
		if normalized["base_path"].is_empty() and normalized["path"].begins_with("res://"):
			normalized["base_path"] = normalized["path"].get_base_dir()
	else:
		if normalized["location"].is_empty():
			normalized["location"] = LOCATION_EXTERNAL

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
	if source_kind == SOURCE_KIND_FILE:
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
	else:
		if PackedByteArray(normalized.get("bytes", PackedByteArray())).is_empty():
			return {
				"field": "bytes",
				"message": "GLTF buffer sources require non-empty bytes.",
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

static func infer_format_from_path(path: String) -> String:
	var extension := path.get_extension().strip_edges().to_lower()
	if extension in FORMATS:
		return extension
	return ""

static func infer_location_from_path(path: String) -> String:
	if path.begins_with("res://"):
		return LOCATION_PACKAGED
	if path.begins_with("user://"):
		return LOCATION_EXTERNAL
	if path.is_absolute_path():
		return LOCATION_EXTERNAL
	return LOCATION_EXTERNAL

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
