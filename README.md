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

The first truthful slice is deliberately small:

- `globals/aero_godot_gltf_contract.gd`
  - result keys and error codes
  - source normalization/validation
  - source kind (`file`, `buffer`)
  - source location (`packaged`, `external`)
  - supported format vocabulary (`gltf`, `glb`)
- `loaders/aero_godot_gltf_runtime_loader.gd`
  - `load_source(source, flags := 0)` parses a GLTF/GLB source into `GLTFDocument` + `GLTFState`
  - `generate_scene(load_result, ...)` instantiates a Godot node tree from a successful load result
  - `load_scene(source, flags := 0, scene_options := {})` convenience path for load + instantiate
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

A future package loader can also hand this repo extracted bytes via `{"kind": "buffer", "bytes": ..., "format": "glb"}` when path-based loading is not the right transport.

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

### GLB proof fixture coverage

The hidden testbed now carries a concrete packaged GLB proof fixture copied from the shared environment fixture set:

- source fixture: `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/.testbed/assets/models/alien-planet.glb`
- packaged/internal proof fixture: `.testbed/tests/fixtures/alien-planet.glb`
- external proof path: a temporary absolute copy under `/tmp/aerobeat-vendor-godot-gltf-tests/alien-planet-external.glb`

The runtime-loader test suite proves both code paths against the same binary asset:

- packaged/internal `res://tests/fixtures/alien-planet.glb`
- external absolute-path copy created during the test run and removed afterward
