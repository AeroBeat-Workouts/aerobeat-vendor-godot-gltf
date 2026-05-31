# AeroBeat Vendor Godot GLTF Testbed Src + GLB Path Fix

**Date:** 2026-05-28  
**Status:** In Progress  
**Last Updated:** 2026-05-31 08:46 EDT  
**Blocked Reason:** None  
**Agent:** `cookie`

---

## Goal

Repair the `aerobeat-vendor-godot-gltf` `.testbed` project after the source-file move into repo-root `src/` and the GLB fixture move into `.testbed/assets/models/alien-planet.glb`.

---

## Overview

This work belongs to `aerobeat-vendor-godot-gltf`, so the plan lives in that repo’s `/.plans/` folder. Two repo-layout moves need to be reflected in the hidden proving surface. First, scripts that used to be under repo-root `globals/` and `loaders/` are now under repo-root `src/`, but the `.testbed` proving scripts/tests still have fallback references to `../globals/...` and `../loaders/...` or addon-mounted `globals/` / `loaders/` paths. Second, the GLB fixture has moved to `.testbed/assets/models/alien-planet.glb`, while several proving/test references and the `.import` metadata still point at the old `res://tests/fixtures/alien-planet.glb` path.

The implementation slice should update the repo-owned `.testbed` scripts/tests/path fallbacks and the `.import` metadata to match the new layout, then run repo-local validation and commit/push. As with the other fixes in this session, Derrick will manually QA/audit afterwards, so this execution pass only needs the coder loop plus a clean handoff.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Owning repo root | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-godot-gltf` |
| `REF-02` | Main runtime loader now under `src/` | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-godot-gltf/src/aero_godot_gltf_runtime_loader.gd` |
| `REF-03` | Main contract now under `src/` | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-godot-gltf/src/aero_godot_gltf_contract.gd` |
| `REF-04` | Testbed proving script | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-godot-gltf/.testbed/scripts/multi_gltf_proving_surface.gd` |
| `REF-05` | Testbed/runtime regression coverage | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-godot-gltf/.testbed/tests/` |
| `REF-06` | New GLB fixture location | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-godot-gltf/.testbed/assets/models/alien-planet.glb` |

---

## Tasks

### Task 1: Repair `.testbed` source-path fallbacks after moving runtime files into `src/`

**Bead ID:** `aerobeat-vendor-godot-gltf-cyh`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`  
**Prompt:** Claim the assigned bead with `bd update <id> --status in_progress --json` at start. In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-godot-gltf`, update the repo-owned `.testbed` scripts/tests so they reference the moved runtime source under repo-root `src/` instead of the old `globals/` and `loaders/` layout. Do not patch generated addon copies. Run repo-local validation, commit/push to `main` by default, and record root cause, changed files, validation, and commit hash.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-godot-gltf/src/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-godot-gltf/.testbed/`

**Files Created/Deleted/Modified:**
- `README.md`

**Status:** ✅ Complete

**Results:** The repo-owned `.testbed` scripts/tests were already correctly updated to use `src/` fallbacks (`res://addons/.../src/...` and `res://../src/...`). The remaining stale source-layout references were documentation-level references in `README.md`, which still described the old `globals/` / `loaders/` paths. Updated those docs to `src/aero_godot_gltf_contract.gd` and `src/aero_godot_gltf_runtime_loader.gd`. Validation passed with `godot --headless --path .testbed --import`, `godot --headless --path .testbed --script res://scripts/validate_multi_gltf_proving_surface.gd`, and `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`. Bead lookup failed because `aerobeat-vendor-godot-gltf-cyh` was not present in the repo-local Beads database at execution time.

---

### Task 2: Repair `.testbed` GLB references after moving the fixture to `.testbed/assets/models/`

**Bead ID:** `aerobeat-vendor-godot-gltf-cyh`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-01`, `REF-04`, `REF-05`, `REF-06`  
**Prompt:** Claim the assigned bead with `bd update <id> --status in_progress --json` at start. Update the repo-owned `.testbed` proving scene/scripts/tests/import metadata so the moved GLB fixture resolves from `.testbed/assets/models/alien-planet.glb` instead of the old `tests/fixtures` path. Keep the fix narrow, validate locally, and include the fixture-path migration details in the handoff.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-godot-gltf/.testbed/assets/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-godot-gltf/.testbed/`

**Files Created/Deleted/Modified:**
- `README.md`

**Status:** ✅ Complete

**Results:** The repo-owned `.testbed` proving scene/scripts/tests/import metadata were already aligned with the moved fixture at `.testbed/assets/models/alien-planet.glb` / `res://assets/models/alien-planet.glb`. The remaining stale references were documentation-level references in `README.md`, which still described `.testbed/tests/fixtures/alien-planet.glb` and `res://tests/fixtures/alien-planet.glb`. Updated those docs to the new `.testbed/assets/models/alien-planet.glb` / `res://assets/models/alien-planet.glb` locations. Validation passed with the same import, proving-surface smoke, and GUT test commands noted in Task 1.

---

### Task 3: Manual QA/audit handoff

**Bead ID:** `Skipped by user`  
**SubAgent:** `primary` (for `qa` / `auditor`)  
**Role:** `qa` / `auditor`  
**References:** `REF-04`, `REF-05`, `REF-06`  
**Prompt:** Skipped by Derrick for this execution pass; Derrick will manually verify the fixed proving surface.

**Folders Created/Deleted/Modified:**
- None for this execution pass

**Files Created/Deleted/Modified:**
- None for this execution pass

**Status:** ⏭️ Skipped by user

**Results:** Derrick explicitly asked to handle QA/audit manually while the implementation work proceeds.

---

## Final Results

**Status:** ⚠️ Partial

**What We Built:** Completed the coder slice for the testbed path-move handoff. The actual `.testbed` code/import metadata was already correct for both the `src/` source move and the packaged GLB fixture move; the remaining stale references were in `README.md`, which now documents the current `src/` runtime paths and `.testbed/assets/models/alien-planet.glb` fixture location. Manual QA/audit remains with Derrick per the approved plan.

**Reference Check:** `REF-01` through `REF-06` are satisfied for the coder slice: verified `.testbed` scripts/tests/import metadata already matched `REF-02`, `REF-03`, and `REF-06`, and updated repo docs accordingly. No generated addon copies were modified.

**Commits:**
- Pending commit

**Lessons Learned:** Path-move follow-up work can collapse into a documentation repair even when the testbed/runtime code is already correct. It was still worth revalidating the hidden proving surface and loader tests before handoff.

---

*Drafted on 2026-05-28*
