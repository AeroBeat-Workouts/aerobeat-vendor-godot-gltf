# aerobeat-vendor-godot-gltf

Godot-native vendor runtime loading surface for AeroBeat GLTF/GLB scene ingestion.

## Architecture role

`aerobeat-vendor-godot-gltf` owns the narrow vendor slice that speaks directly to Godot's runtime `GLTFDocument` / `GLTFState` API. It is the concrete place where AeroBeat can load GLTF-family scene payloads into live Godot scene data without pushing Godot-specific parsing concerns into a higher-level tool facade.

This repo is intentionally vendor-oriented, not workflow-oriented:

- it normalizes and validates GLTF/GLB source descriptors
- it loads packaged (`res://`) and external (`user://` or absolute-path) scene sources through the same Godot-native runtime path
- it can generate a Godot scene from a successful load result
- it leaves package discovery, environment policy, workout-package selection, persistence, and user-facing orchestration to higher-level tool repos

## Current contract slice

The current truthful slice stays vendor-focused while covering both single-scene and multi-instance loading:

- `globals/aero_godot_gltf_contract.gd`
  - result keys and error codes
  - source normalization/validation
  - source kind (`file`, `buffer`, `url`)
  - source location (`packaged`, `external`, `remote`)
  - supported format vocabulary (`gltf`, `glb`)
  - instance-transform normalization for `position`, `rotation_degrees`, and `scale`
- `loaders/aero_godot_gltf_runtime_loader.gd`
  - `load_source(source, flags := 0)` parses a GLTF/GLB source into `GLTFDocument` + `GLTFState`
  - `generate_scene(load_result, ...)` instantiates a Godot node tree from a successful load result
  - `load_scene(source, flags := 0, scene_options := {})` convenience path for load + instantiate
  - `load_scene_instance(source, flags := 0, scene_options := {}, instance_options := {})` wraps one loaded GLTF scene under a transformable parent `Node3D`
  - `load_scene_instances(instances, flags := 0, scene_options := {})` loads multiple independent GLTF assets under one aggregate root with per-instance transforms applied after load
  - `unload_result(result)` explicitly frees loaded scene roots and cleans temporary URL download artifacts
  - `unload_last_result()` explicitly unloads the last vendor result
  - `get_last_result()` exposes the last vendor result for debugging/handoff use

The design keeps one vendor-owned runtime architecture for both packaged/internal and external/local-package ingestion: a normalized source dictionary plus the Godot runtime loader. Future tool-facing repos can wrap this with workout-package resolution or environment-specific policies without changing the vendor contract.

## Public surface example

```gdscript
var loader := AeroGodotGltfRuntimeLoader.new()

var result := loader.load_scene({
  "path": "res://fixtures/workout_scene.glb"
})

if result.get("success", false):
  var scene_root: Node = result["detail"]["scene"]
  add_child(scene_root)
else:
  push_error(result.get("message", "GLTF load failed"))
```

External/local-package sources use the same surface:

```gdscript
var result := loader.load_scene({
  "path": "/absolute/path/to/workout-package/environment.glb"
})
```

Multi-instance placement stays in the vendor layer too:

```gdscript
var result := loader.load_scene_instances([
  {
    "name": "LeftPlanet",
    "source": {"path": "res://fixtures/alien-planet.glb"},
    "transform": {
      "position": [-2.0, 0.0, 0.0],
      "rotation_degrees": [0.0, -15.0, 0.0],
      "scale": [1.0, 1.0, 1.0]
    }
  },
  {
    "name": "RightPlanet",
    "source": {"path": "/absolute/path/to/environment.glb"},
    "transform": {
      "position": [2.0, 0.5, 0.0],
      "rotation_degrees": [0.0, 35.0, 0.0],
      "scale": [1.25, 1.25, 1.25]
    }
  }
], 0, {"root_name": "EnvironmentInstances"})

if result.get("success", false):
  add_child(result["detail"]["scene"])
```

Each instance gets its own parent `Node3D`, so higher-level repos can attach multiple GLTF assets independently and still keep transforms outside the imported scene payload itself.

A future package loader can also hand this repo extracted bytes via `{"kind": "buffer", "bytes": ..., "format": "glb"}` when path-based loading is not the right transport.

Remote URL transport also stays vendor-owned. For example, a tool-facing facade can ask the runtime to fetch and load:

```gdscript
var result := loader.load_scene({
  "kind": "url",
  "url": "http://127.0.0.1:8123/alien-planet.glb",
  "format": "glb"
})
```

## Dependency expectations

For this vendor repo itself:

- runtime dependency: Godot `4.6.2 stable standard`
- no required dependency on `aerobeat-tool-core` for the current vendor slice

For a future tool-facing facade repo above this layer:

- depend on this vendor repo when you need Godot-native runtime GLTF/GLB ingestion
- keep package selection, workout-package storage rules, editor/CLI UX, and environment-policy decisions in the tool repo
- pass resolved file paths or extracted bytes into this vendor repo rather than teaching the vendor layer package semantics

## GodotEnv development flow

This repo uses the AeroBeat GodotEnv package convention.

- Canonical dev/test manifest: `.testbed/addons.jsonc`
- Installed dev/test addons: `.testbed/addons/`
- GodotEnv cache: `.testbed/.addons/`
- Hidden workbench project: `.testbed/project.godot`
- Repo-local unit tests: `.testbed/tests/`

### Restore dev/test dependencies

From the repo root:

```bash
cd .testbed
godotenv addons install
```

The current manifest is intentionally narrow: `gut` only.

### Import smoke check

From the repo root:

```bash
godot --headless --path .testbed --import
```

### Run unit tests

From the repo root:

```bash
godot --headless --path .testbed --script addons/gut/gut_cmdln.gd \
  -gdir=res://tests \
  -ginclude_subdirs \
  -gexit
```

### Human proving surface

The hidden testbed now includes an interactive multi-instance proving surface:

- scene: `.testbed/scenes/multi_gltf_proving_surface.tscn`
- script: `.testbed/scripts/multi_gltf_proving_surface.gd`
- fixture: `.testbed/tests/fixtures/alien-planet.glb`

Open the hidden testbed project and run that scene to verify:

- two independent GLTF instances load under separate parent anchors
- parent `position`, `rotation_degrees`, and `scale` controls apply after load
- each instance can be adjusted without mutating the other imported scene

For a quick headless smoke check of the proving surface wiring itself:

```bash
godot --headless --path .testbed --script res://scripts/validate_multi_gltf_proving_surface.gd
```

Keyboard controls inside the proving surface:

- `F1` / `F2` / `F3` — load the packaged project path, copied external device path, or URL source
- `L` — reload the current source mode
- `U` — explicitly unload the current result
- `W` / `A` / `S` / `D` — fly the camera
- `Q` / `E` — move the camera down/up
- hold `Shift` — move the camera faster
- hold left mouse and drag — rotate the fly camera

- `1` / `2` — select the left or right instance
- `Tab` — cycle the selected instance
- `P` — cycle parent position presets
- `R` — cycle parent rotation presets
- `S` — cycle parent scale presets
- `V` — print a transform snapshot to the Godot output log

### GLB proof fixture coverage

The hidden testbed now carries a concrete packaged GLB proof fixture copied from the shared environment fixture set:

- source fixture: `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/.testbed/assets/models/alien-planet.glb`
- packaged/internal proof fixture: `.testbed/tests/fixtures/alien-planet.glb`
- external proof path: a temporary absolute copy under `/tmp/aerobeat-vendor-godot-gltf-tests/alien-planet-external.glb`

The runtime-loader test suite proves both code paths against the same binary asset:

- packaged/internal `res://tests/fixtures/alien-planet.glb`
- external absolute-path copy created during the test run and removed afterward
