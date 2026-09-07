# Phase 1 Correctness Plan (course-corrected)

Date: 2026-09-07. Supersedes broad-audit ordering for this pass only.
Prior research (2026-09-06) is preserved untouched.

## Objective

Move this fork materially toward playable Demon's Souls on Windows with a
small, reviewable, evidence-driven correctness pass. No performance work in
this pass.

## Exact order (no reordering)

1. **DOCS FIRST** (this file + companions below).
2. **BASELINE**: minimal Windows build/test baseline + exact toolchain status
   in `LOCAL_TESTING.md`.
3. **FIRST SOURCE PORT ONLY**: Senaxx `2db19f7` (guest compute lane identity
   + tests), with attribution. Run focused shader/compute tests and available
   regression gates. Do not merge the Senaxx chain.
4. **CONDITIONAL**: only if `2db19f7` passes, consider ONE additional small
   Senaxx correctness commit after diffing overlap against Lordix `7c21b71`
   and fxpw `cf88512`.
5. No push by the agent (orchestrator bundles pushes per workflow policy below).

## Out of scope for this pass

- Broad AGC/PM4, WRITE_DATA, queue/doorbell, NGG, aperture, DCC/CMASK/HTILE,
  and telemetry/census audits.
- Any Almo performance work (including `609302b` async pipelines).
- Any broad new census/telemetry system.
- Any push to any remote.

## Pinned donor heads (verified locally 2026-09-07)

| Repo | SHA (full) | Note |
|---|---|---|
| upstream KytyPS5 | `74a78f37d08fabae0a37e621ef209786796c37fe` | Base baseline |
| senaxx/KytyPS5 | `2db19f71fcfd49eed82b1e73d4dfbac08a3216d3` | First port; committed as `38c5c3f` (donor preserved as author) |
| lordix/KytyPS5 | `7c21b713d2f706f6d761fd0cd5ec53dbce6dd399` | Overlap comparison only |
| fxpw/KytyPS5 | `cf88512b6a78ca16bd9d6d2d693375aae44b6602` | Overlap comparison only |
| almo/KytyPS5 | `609302b40f90ee96a623a0956de5bb064bf20b51` | Deferred, not in this pass |

Donor-repo claims (FPS, "playable", "verified on X") are not our
measurements. Record our own commit SHA, toolchain, test names, and
pass/fail counts for every claim in this fork.

## Senaxx 2db19f7 scope (from local `git show`)

- Title: `shader: derive compute lane identity from the guest workgroup`.
- Problem: host subgroup is not necessarily a complete guest wave; on
  subgroup32 hardware, `SubgroupLocalInvocationId` for wave64 repeats
  0..31 in the upper half, breaking `V_MBCNT` prefix counts.
- Fix: linear local invocation index modulo guest wave size for compute
  `LaneId`; collect that builtin even when guest thread-ID VGPR init is
  disabled. Graphics lane identity and subgroup communication unchanged.
- Files: `SpirvEmitter.cpp`, `spirvEmitterFlow.cpp`,
  `ShaderInfoCollection.cpp`, `tests/ShaderGuestLaneTests.h`,
  `tests/ShaderRecompilerComputeTests.cpp`.
- Donor validation claim (not ours): Release clang-cl launcher build, all
  366 host/compute/graphics checks pass on RTX 5090; Demon's Souls Hunter
  run reaches Outpost Passage; black materials/corruption remain.
- Our gate: focused `shader_recompiler_compute` tests + available
  regression gates on this Windows PC, results recorded in `LOCAL_TESTING.md`.

## Phase 1 checkpoint result (measured 2026-09-07, commit `38c5c3f`)

- Senaxx `2db19f7` validated locally and committed as `38c5c3f` (donor preserved as author; blob-identical, `clang-format` clean).
- Targeted guest-lane mode: 8/8 passed (`--guest-lane-id-only`: MBCNT control + 7 new wave32/64 cases).
- Full suite: 25/36 passed with exactly the same 11 pre-existing failures as baseline (tests 1-4 Not Run, no `kyty_emulator.exe`; tests 19, 28-30, 34-36).
- Ordinary compute failure signature unchanged: `image.cpp:693`, format=129 usage=0x23 samples=2. No new failures.
- Performance / game smoke test deferred (donor Hunter/Outpost claim remains donor-only).

## Evidence required per change

- Base SHA + donor SHA + attribution in commit message.
- Focused test names and pass/fail counts.
- Full available suite result (or explicit reason if not runnable).
- `clang-format` clean on touched files.
- No game data in Git. `DS_DUMP_ROOT`, if set, is opaque local test input
  only.

## Prohibited

- Searching for or downloading keys, firmware, proprietary SDKs, licenses,
  secrets, or DRM/circumvention material.
- Copying the game into Git.
- Pushing from the agent in this pass (orchestrator bundles pushes per workflow policy).

## Handoff

- Next action: compare ONE next small Senaxx correctness commit against Lordix `7c21b71` and fxpw `cf88512` for overlap/conflict before porting.
- Prefer correctness before Almo performance (`609302b` stays deferred).
- Source checkpoint `38c5c3f` is committed locally; the orchestrator may push after review (agent itself does not push).

## Repository workflow policy (2026-09-07)

- Local commits may be frequent; remote pushes are bundled into at most ~5 checkpoint pushes per day.
- An exceptionally major milestone may trigger one immediate extra push; never push every small edit.
- Major benchmark / source-validation checkpoints (e.g. `38c5c3f`) qualify as push-worthy checkpoints at orchestrator discretion.
