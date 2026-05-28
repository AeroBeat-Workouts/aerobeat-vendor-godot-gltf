extends GutTest

const LOADER_CANDIDATE_PATHS := [
	"res://addons/aerobeat-vendor-godot-gltf/src/aero_godot_gltf_runtime_loader.gd",
	"res://../src/aero_godot_gltf_runtime_loader.gd",
]
const PACKAGED_FIXTURE_PATH := "res://assets/models/alien-planet.glb"
const MINIMAL_FIXTURE_PATH := PACKAGED_FIXTURE_PATH
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

func test_loader_can_wrap_single_scene_in_transformable_instance_root() -> void:
	var loader_script := _load_loader_script()
	assert_true(loader_script != null, "Expected AeroGodotGltfRuntimeLoader script to load")
	var loader = loader_script.new()

	var instance_result: Dictionary = loader.load_scene_instance(
		{"path": PACKAGED_FIXTURE_PATH},
		0,
		{},
		{
			"name": "PlanetAnchor",
			"transform": {
				"position": [1, 2, 3],
				"rotation_degrees": [0, 45, 0],
				"scale": [0.5, 0.5, 0.5],
			},
		}
	)
	assert_true(instance_result.get("success", false), "Expected packaged GLB fixture to load into an instance root")
	var detail: Dictionary = instance_result.get("detail", {})
	var instance_root := detail.get("scene") as Node3D
	var loaded_scene := detail.get("loaded_scene") as Node
	assert_true(instance_root != null, "Expected transformable instance root to exist")
	assert_true(loaded_scene != null, "Expected wrapped scene child to exist")
	assert_eq(instance_root.name, "PlanetAnchor")
	assert_eq(instance_root.position, Vector3(1, 2, 3))
	assert_eq(instance_root.rotation_degrees, Vector3(0, 45, 0))
	assert_eq(instance_root.scale, Vector3(0.5, 0.5, 0.5))
	assert_eq(instance_root.get_child_count(), 1)
	assert_eq(instance_root.get_child(0), loaded_scene)
	assert_eq(loaded_scene.name, EXPECTED_PACKAGED_SCENE_NAME)
	instance_root.free()

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

func test_loader_can_build_multiple_independent_instances_under_one_root() -> void:
	var loader_script := _load_loader_script()
	assert_true(loader_script != null, "Expected AeroGodotGltfRuntimeLoader script to load")
	var loader = loader_script.new()

	var scene_result: Dictionary = loader.load_scene_instances([
		{
			"name": "LeftFixture",
			"source": {"path": MINIMAL_FIXTURE_PATH},
			"transform": {
				"position": [-2, 0, 0],
				"rotation_degrees": [0, -15, 0],
				"scale": [1, 1, 1],
			},
		},
		{
			"name": "RightFixture",
			"source": {"path": MINIMAL_FIXTURE_PATH},
			"transform": {
				"position": [2, 1, 0],
				"rotation_degrees": [0, 30, 0],
				"scale": [1.5, 1.5, 1.5],
			},
		},
	], 0, {"root_name": "MultiFixtureRoot"})
	assert_true(scene_result.get("success", false), "Expected multi-instance GLTF scene load to succeed")
	var detail: Dictionary = scene_result.get("detail", {})
	var aggregate_root := detail.get("scene") as Node3D
	var instances: Array = detail.get("instances", [])
	assert_true(aggregate_root != null, "Expected aggregate instance scene root to exist")
	assert_eq(aggregate_root.name, "MultiFixtureRoot")
	assert_eq(aggregate_root.get_child_count(), 2)
	assert_eq(instances.size(), 2)

	var left_detail: Dictionary = instances[0]
	var left_root := left_detail.get("instance_root") as Node3D
	var left_scene := left_detail.get("loaded_scene") as Node
	assert_true(left_root != null, "Expected left instance root to exist")
	assert_true(left_scene != null, "Expected left loaded scene to exist")
	assert_eq(left_root.name, "LeftFixture")
	assert_eq(left_root.position, Vector3(-2, 0, 0))
	assert_eq(left_root.rotation_degrees, Vector3(0, -15, 0))
	assert_eq(left_root.scale, Vector3.ONE)
	assert_eq(left_root.get_child(0), left_scene)

	var right_detail: Dictionary = instances[1]
	var right_root := right_detail.get("instance_root") as Node3D
	var right_scene := right_detail.get("loaded_scene") as Node
	assert_true(right_root != null, "Expected right instance root to exist")
	assert_true(right_scene != null, "Expected right loaded scene to exist")
	assert_eq(right_root.name, "RightFixture")
	assert_eq(right_root.position, Vector3(2, 1, 0))
	assert_eq(right_root.rotation_degrees, Vector3(0, 30, 0))
	assert_eq(right_root.scale, Vector3(1.5, 1.5, 1.5))
	assert_eq(right_root.get_child(0), right_scene)
	assert_ne(left_root, right_root)
	assert_ne(left_scene, right_scene)
	aggregate_root.free()

func test_loader_can_unload_generated_scene_roots() -> void:
	var loader_script := _load_loader_script()
	assert_true(loader_script != null, "Expected AeroGodotGltfRuntimeLoader script to load")
	var loader = loader_script.new()

	var scene_result: Dictionary = loader.load_scene({"path": PACKAGED_FIXTURE_PATH})
	assert_true(scene_result.get("success", false), "Expected packaged GLB fixture to load before unload")
	var scene_root := scene_result.get("detail", {}).get("scene", null) as Node
	assert_true(scene_root != null, "Expected loaded scene root to exist before unload")
	var unload_result: Dictionary = loader.unload_result(scene_result)
	assert_true(unload_result.get("success", false), "Expected unload_result to report success")
	assert_eq(unload_result.get("detail", {}).get("freed_roots", 0), 1)

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
