extends GutTest

const CONTRACT_CANDIDATE_PATHS := [
	"res://../globals/aero_godot_gltf_contract.gd",
	"res://addons/aerobeat-vendor-godot-gltf/globals/aero_godot_gltf_contract.gd",
]

func _load_contract() -> Script:
	for candidate_path in CONTRACT_CANDIDATE_PATHS:
		if ResourceLoader.exists(candidate_path, "Script"):
			return load(candidate_path)
	return null

func test_contract_normalizes_packaged_and_external_file_sources() -> void:
	var contract := _load_contract()
	assert_true(contract != null, "Expected AeroGodotGltfContract script to load")

	var packaged: Dictionary = contract.call("normalize_source", {
		"path": "res://tests/fixtures/minimal_runtime_scene.gltf"
	})
	assert_eq(packaged.get("kind"), "file")
	assert_eq(packaged.get("format"), "gltf")
	assert_eq(packaged.get("location"), "packaged")
	assert_eq(packaged.get("base_path"), "res://tests/fixtures")

	var external: Dictionary = contract.call("normalize_source", {
		"path": "/tmp/runtime_environment.glb"
	})
	assert_eq(external.get("format"), "glb")
	assert_eq(external.get("location"), "external")

func test_contract_rejects_missing_file_path() -> void:
	var contract := _load_contract()
	assert_true(contract != null, "Expected AeroGodotGltfContract script to load")

	var validation: Dictionary = contract.call("validate_source", {"kind": "file"})
	assert_eq(validation.get("field", ""), "path")

func test_contract_accepts_buffer_sources_when_format_is_explicit() -> void:
	var contract := _load_contract()
	assert_true(contract != null, "Expected AeroGodotGltfContract script to load")

	var validation: Dictionary = contract.call("validate_source", {
		"kind": "buffer",
		"bytes": PackedByteArray([1, 2, 3]),
		"format": "glb",
	})
	assert_true(validation.is_empty(), "Expected explicit GLB buffer sources to validate cleanly")
