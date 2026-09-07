# PS5 Emulator Landscape Delta — 2026-09-07

This is a small delta on top of `PS5_EMULATOR_LANDSCAPE_2026-09-06.md`,
which is preserved untouched. Scope is limited to the Phase 1
course correction: verify pinned donor heads locally, land the single
first port, and record local validation. No performance work, no broad audit.

## Pinned heads verified locally (2026-09-07, `git rev-parse`)

| Repo | Ref | Full SHA |
|---|---|---|
| upstream KytyPS5 | `upstream/main` | `74a78f37d08fabae0a37e621ef209786796c37fe` |
| senaxx/KytyPS5 | `senaxx/main` | `2db19f71fcfd49eed82b1e73d4dfbac08a3216d3` |
| lordix/KytyPS5 | `lordix/demons-souls` | `7c21b713d2f706f6d761fd0cd5ec53dbce6dd399` |
| fxpw/KytyPS5 | `fxpw/yotei-windows-bringup` | `cf88512b6a78ca16bd9d6d2d693375aae44b6602` |
| almo/KytyPS5 | `almo/main` | `609302b40f90ee96a623a0956de5bb064bf20b51` |

Our checkout: `phase1/demons-souls-playable` at `38c5c3f` (local commit; donor Senaxx `2db19f7` preserved as author; ahead of `origin/main`).

## Senaxx 2db19f7 (validated locally)

- `shader: derive compute lane identity from the guest workgroup`.
- Correctness rationale (donor description, confirmed by our local focused gates):
  host subgroup != guest wave; subgroup32 `SubgroupLocalInvocationId`
  repeats 0..31 for wave64, corrupting `V_MBCNT` prefix counts. Fix uses
  linear local invocation index mod guest wave size.
- Touch surface is small and test-bearing: SPIR-V emitter flow (2 files),
  `ShaderInfoCollection.cpp`, `tests/ShaderGuestLaneTests.h` (new),
  `tests/ShaderRecompilerComputeTests.cpp`.
- Donor claim (remains donor-only): 366 host/compute/graphics checks pass (RTX 5090), Hunter run
  reaches Outpost Passage; lighting/texture corruption remains. Our local validation: targeted
  guest-lane mode 8/8 passed; full suite 25/36 with the same 11 pre-existing baseline failures, no new failures.

## Lordix 7c21b71 / fxpw cf88512 (overlap comparison only)

- Lordix `7c21b71`: Vulkan graphics pipeline, indirect descriptors, texture
  tiler bounds (Demon's Souls-titled commit; larger surface than Senaxx).
- fxpw `cf88512`: bounded image descriptor tables (shader table
  materialization; adjacent to Senaxx image-table follow-ups, not to
  `2db19f7`'s lane-identity path).
- Step 4 rule: after `2db19f7` passes, diff ONE small Senaxx follow-up
  (`c6b4156`, `0ebfb0d`, `4fda5b7`, or `89f2f34` area) against these two
  heads for overlapping files before considering it. No wholesale merge.

## Almo 609302b (deferred)

Async shader/pipeline system stays deferred for this pass per the course
correction, regardless of its P1 ranking in the 09-06 research.

## Sep 7 ecosystem delta (genuinely new vs 09-06 snapshot; evidence-labelled)

- Senaxx/KytyPS5 is now the highest-priority Demon's Souls correctness donor. Sept 6 chain after upstream: `2db19f7` guest compute lane identity (COMMITTED here as `38c5c3f`; OUR measurement: guest-lane 8/8, full 25/36 same 11 pre-existing failures); `c6b4156` guarded record-backed image tables; `0ebfb0d` counted direct image tables; `390792b` bounded direct-address image tables; `d42de24` reachable sampler phis; `7be1416` candidate-specific image layouts; `89f2f34` depth overlap/layout coherence; `c11721c`/`cd14777`/`6d1f799` mip/slice/layer validation; `cb5b1a4`/`e31274a` formatted buffer stores. Donor claim: ordinary Demon's Souls reaches Outpost Passage with movement but black materials/scene corruption remain. OUR measurement validates only `2db19f7` so far.
- iStark/PS5PCEM: fast-moving independent GPL-3.0 Zig emulator, active through Sep 6, Ghost of Yotei bring-up; host-side resource/cache/readback/compute work. Repo-reported Sep 6 measurement (donor claim): resource-resolution ~20m13s -> ~12m06s and median frame ~13.614s -> ~9.151s (~0.108 FPS); output still dark/incorrect, NOT playable. Treat as architecture/reference until license compatibility is checked.
- sharpemu/sharpemu active; PR #863 (donor claim) adds VSadU32, SMulHiI32, SAbsdiffI32 with synthetic tests. Port only if our DS shader corpus hits them.
- Force67/prosperity remains an important AGC/PM4 conceptual reference. Sep 1 corrected packet interpretation such as 0x93 wait-on-address and added dropped-packet census ideas. Reference only, no blind cherry-pick.
- Coder787-source/KytyPlus active through Sep 5: stability/QOL/package/pipeline-cache ideas, not the primary DS renderer path.
- Stepz97/ps5emu: meaningful Windows/native execution and Win64 fiber ABI work around Jul 30, now behind Sep 4-6 activity.
- Union-Crax/Hyper5: lower priority / older SharpEmu-derived work, last notable Jul 29 in sweep.
- Komary-related forks mostly quiet by ~Aug 20; carecu-style forks largely July-era.
- ps5rs active as Rust tooling/research crates useful for PRX/NID/schema/shader analysis, not a gameplay emulator.
- MagnusPS5 public late-Aug release exists but is shallow/watch-only.

## What did not change

No new benchmark numbers, no FPS claims, no census/telemetry system, no
AGC/PM4/NGG/metadata audit conclusions. Those remain future work outside
this pass.
