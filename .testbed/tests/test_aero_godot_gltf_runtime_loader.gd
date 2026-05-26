extends GutTest

const LOADER_CANDIDATE_PATHS := [
	"res://../loaders/aero_godot_gltf_runtime_loader.gd",
	"res://addons/aerobeat-vendor-godot-gltf/loaders/aero_godot_gltf_runtime_loader.gd",
]
const PACKAGED_FIXTURE_PATH := "res://tests/fixtures/alien-planet.glb"
const EXPECTED_PACKAGED_SCENE_NAME := "Sketchfab_Scene"
const EXPECTED_PACKAGED_ROOT_CHILDREN := 1
const EXTERNAL_FIXTURE_DIRECTORY_NAME := "aerobeat-vendor-godot-gltf-tests"
const EXTERNAL_FIXTURE_FILE_NAME := "alien-planet-external.glb"

func _load_loader_script() -> Script:
	for candidate_path in LOADER_CANDIDATE_PATHS:
		if ResourceLoader.exists(candidate_path, "Script"):
			return load(candidate_path)
	return null

func _copy_binary_file(source_absolute_path: String, target_absolute_path: String) -> void:
	assert_true(FileAccess.file_exists(source_absolute_path), "Expected source GLB fixture to exist")
	var source_file := FileAccess.open(source_absolute_path, FileAccess.READ)
	assert_true(source_file != null, "Expected source GLB fixture to open")
	var bytes := source_file.get_buffer(source_file.get_length())
	DirAccess.make_dir_recursive_absolute(target_absolute_path.get_base_dir())
	var target_file := FileAccess.open(target_absolute_path, FileAccess.WRITE)
	assert_true(target_file != null, "Expected target GLB fixture to open")
	target_file.store_buffer(bytes)

func _get_external_fixture_absolute_path() -> String:
	var temp_root := OS.get_environment("TMPDIR")
	if temp_root.is_empty():
		temp_root = "/tmp"
	return temp_root.path_join(EXTERNAL_FIXTURE_DIRECTORY_NAME).path_join(EXTERNAL_FIXTURE_FILE_NAME)

func _make_external_fixture_copy() -> String:
	var source_absolute_path := ProjectSettings.globalize_path(PACKAGED_FIXTURE_PATH)
	var target_absolute_path := _get_external_fixture_absolute_path()
	_copy_binary_file(source_absolute_path, target_absolute_path)
	return target_absolute_path

func test_loader_rejects_invalid_sources() -> void:
	var loader_script := _load_loader_script()
	assert_true(loader_script != null, "Expected AeroGodotGltfRuntimeLoader script to load")
	var loader = loader_script.new()

	var result: Dictionary = loader.load_source({"path": "res://tests/fixtures/not_a_model.txt"})
	assert_false(result.get("success", true))
	assert_eq(result.get("code", ""), "invalid_source")

func test_loader_can_load_and_generate_scene_from_packaged_glb_fixture() -> void:
	var loader_script := _load_loader_script()
	assert_true(loader_script != null, "Expected AeroGodotGltfRuntimeLoader script to load")
	var loader = loader_script.new()

	var load_result: Dictionary = loader.load_source({"path": PACKAGED_FIXTURE_PATH})
	assert_true(load_result.get("success", false), "Expected packaged GLB fixture to load")
	var scene_result: Dictionary = loader.generate_scene(load_result)
	assert_true(scene_result.get("success", false), "Expected packaged GLB fixture to instantiate")
	var detail: Dictionary = scene_result.get("detail", {})
	var scene_root := detail.get("scene") as Node
	assert_true(scene_root != null, "Expected generated scene root to exist")
	assert_eq(detail.get("source", {}).get("format", ""), "glb")
	assert_eq(detail.get("source", {}).get("location", ""), "packaged")
	assert_eq(scene_root.name, EXPECTED_PACKAGED_SCENE_NAME)
	assert_eq(scene_root.get_child_count(), EXPECTED_PACKAGED_ROOT_CHILDREN)
	scene_root.free()

func test_loader_can_load_same_glb_from_external_absolute_copy() -> void:
	var loader_script := _load_loader_script()
	assert_true(loader_script != null, "Expected AeroGodotGltfRuntimeLoader script to load")
	var loader = loader_script.new()
	var external_path: String = _make_external_fixture_copy()

	var scene_result: Dictionary = loader.load_scene({"path": external_path})
	assert_true(scene_result.get("success", false), "Expected external GLB fixture copy to load and instantiate")
	var detail: Dictionary = scene_result.get("detail", {})
	var scene_root := detail.get("scene") as Node
	assert_true(scene_root != null, "Expected generated external scene root to exist")
	assert_eq(detail.get("source", {}).get("location", ""), "external")
	assert_eq(detail.get("source", {}).get("format", ""), "glb")
	assert_eq(scene_root.name, EXPECTED_PACKAGED_SCENE_NAME)
	assert_eq(scene_root.get_child_count(), EXPECTED_PACKAGED_ROOT_CHILDREN)
	scene_root.free()
	DirAccess.remove_absolute(external_path)

func test_loader_exposes_last_result_for_debugging() -> void:
	var loader_script := _load_loader_script()
	assert_true(loader_script != null, "Expected AeroGodotGltfRuntimeLoader script to load")
	var loader = loader_script.new()

	var result: Dictionary = loader.load_source({"path": PACKAGED_FIXTURE_PATH})
	assert_true(result.get("success", false), "Expected packaged GLB fixture to load")
	var last_result: Dictionary = loader.get_last_result()
	assert_true(last_result.get("success", false), "Expected last result to capture the successful load")
	assert_eq(last_result.get("detail", {}).get("source", {}).get("path", ""), PACKAGED_FIXTURE_PATH)
	assert_eq(last_result.get("detail", {}).get("source", {}).get("format", ""), "glb")

func after_each() -> void:
	var external_path := _get_external_fixture_absolute_path()
	if FileAccess.file_exists(external_path):
		DirAccess.remove_absolute(external_path)
	DirAccess.remove_absolute(external_path.get_base_dir())
