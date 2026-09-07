# Demon's Souls 60-FPS Master Tracker

Target: stable, correct 60 FPS / 16.67-ms frame budget on Ryzen 7 7700X + Radeon RX 9070 XT + 64 GB RAM, Windows.

> Course correction 2026-09-07: this pass follows PHASE1_CORRECTNESS_PLAN.md in exact order (docs, baseline, Senaxx 2db19f7 only, conditional second commit). Broad P0 audits and Almo performance work are deferred. Source checkpoint is now local commit `38c5c3f` (donor Senaxx `2db19f7` preserved as author). See LOCAL_TESTING.md and PS5_EMULATOR_LANDSCAPE_2026-09-07.md.

## Phase 1 (active, small)

- [x] Docs: PHASE1_CORRECTNESS_PLAN.md, LOCAL_TESTING.md, PS5_EMULATOR_LANDSCAPE_2026-09-07.md (+ tracker refresh).
- [x] Baseline: minimal Windows build/test baseline in LOCAL_TESTING.md (25 passed / 11 failed; pre-existing image.cpp:693 failures + 4 Not Run).
- [x] Port Senaxx `2db19f7` committed as `38c5c3f` (donor preserved as author; blob-identical, clang-format clean); guest-lane 8/8 ok, full regression 25/36 identical to baseline, no new failures. Not pushed.
- [x] Crash fix: almo `953b1ce` committed locally as `6ce809a` (donor author; port + format fixup, logic identical); test gate 29/36 reconfirmed (same 7 substantive failures; tests 1-4 pass on build scope, NOT the fix). Docs/harness uncommitted for review.
- [x] Visual milestone (AUTHORITATIVE, parent run `015819`): Bluepoint logo t2-t10, DEMON'S SOULS LANGUAGE SELECT menu at t15 — first interactive menu. Run-3 harness overlapped its tail: survival/stdout/RSS stand, screenshots + system GPU samples non-authoritative. No push.
- [x] Clean baseline (AUTHORITATIVE, parent run `020322`, single instance): 31.8 s timeout, no crash, stderr empty; LANGUAGE SELECT stable t2-t25; GPU ~32-36% sustained (not FPS); RSS 1.4→5.6 GB watch item, not a leak claim. Supersedes contaminated utilization from overlapping runs (kept as history).
- [ ] Run 4 (harness READY, not run): `-InputSchedule '25:j'` — lowercase j = Cross under built-in defaults, no --keymap needed; focuses spawned PID window only, default OFF. Checkpoints per LOCAL_TESTING.
- [ ] Conditional: ONE additional small Senaxx commit only after diffing overlap vs Lordix 7c21b71 and fxpw cf88512.
- [x] First game benchmark (OUR run 1 @ `38c5c3f`, cold): app0 direct, 480x270 Immediate, shader-opt Performance, validations/dumps off, playgo-hack on; 93 shaders; ~19 s to format=141 blocker; stderr empty; no FPS claimed.
- [x] Second game benchmark (OUR run 2 @ `38c5c3f`, warm): 6.67 s, exit 321, 93 shaders; 2 s/5 s screenshots show window open but render black (no logo/UI/scene); same format=141 blocker at `image.cpp:693`; RSS ~3.93 GB @ ~5.4 s, CPU ~1200-1350% (≈12-13 CPUs), ~58-59 threads. Milestone: window → black → abort before first visible frame (cold run 1 was ~19 s to same blocker).
- [x] Benchmark harness `scripts/Run-DsBenchmark.ps1` READY (game root via env/arg, screenshots default 2/5/10/15 s, ~1 Hz samples, outputs under ignored `_Build/benchmarks/`). Local infra, not a perf optimization.

## Repository workflow policy (2026-09-07)

- Local commits may be frequent; remote pushes are bundled into at most ~5 checkpoint pushes per day.
- An exceptionally major milestone may trigger one immediate extra push; never push every small edit.
- Major benchmark / source-validation checkpoints (e.g. `38c5c3f`) qualify as push-worthy checkpoints at orchestrator discretion.

## P0 — prove the frame is correct

- [ ] Establish a fixed Demon's Souls gameplay benchmark and exact game version/settings. (Deferred for this pass; see PHASE1_CORRECTNESS_PLAN.md.)
- [ ] Add CPU/GPU/present/pipeline/shader/readback/barrier/submission frame-time telemetry.
- [ ] Add AGC packet/submission/draw/dispatch census.
- [ ] Audit Prosperity's Demon's Souls findings against current Kyty: ring/doorbell submission, WRITE_DATA destination semantics, NGG v5 vertex index, inline V# fetches, gfx10.3 shader/swizzle coverage, state blocks outside narrow aperture assumptions, end-of-frame signal forms, and DCC descriptor behavior.
- [ ] Add real shader opcode/dispatcher-fallback census from the Demon's Souls shader corpus.
- [ ] Verify no unbounded host-memory/resource-pool growth during a long gameplay run.

## P1 — highest-confidence performance work

- [ ] Rebase/port Almo7aya `609302b...` async shader/pipeline system in small reviewable commits.
- [ ] Add correctness mode that blocks on a first-use required pipeline instead of relying on skipped cold draws.
- [ ] Port/audit Almo `b072439...` synchronization reductions.
- [ ] Unify current upstream readback windows with an adaptive hot-buffer shadow design inspired by Almo `97a895b...`.
- [ ] Audit aligned dword shader lowering using SharpEmu `fe6521f...` as the measured reference.
- [ ] Deduplicate/aggregate hot Release logging.

## P2 — steady-state architecture

- [ ] Persistent Kyty IR/SPIR-V cache in addition to Vulkan driver pipeline cache.
- [ ] Descriptor-set-layout and pipeline-layout caches.
- [ ] Precise synchronization2 resource-state/barrier tracker.
- [ ] Allocation-free warm cached-draw path.
- [ ] Pipeline-key cardinality profiler and selective further dynamic state.

## Conditional experiments

- [ ] Test lower internal resolution / FSR1 only if GPU time is actually the limiter.
- [ ] Test async compute/transfer only if GPU traces show idle overlap opportunity.

## Milestones

- [ ] M0 — reproducible gameplay boot.
- [ ] M1 — correct benchmark scene with zero unexplained dropped GPU work.
- [ ] M2 — stable 30 FPS / <=33.3 ms.
- [ ] M3 — stable 45 FPS / <=22.2 ms.
- [ ] M4 — stable 60 FPS / <=16.67 ms.
- [ ] M5 — traversal-quality 60 FPS with controlled 1% lows and no material shader/pipeline hitching.

## Evidence required for every claimed improvement

Record:

- exact git SHA;
- exact game/title version;
- host driver version;
- render resolution/mode;
- cold versus warm cache state;
- fixed benchmark route and duration;
- average FPS, 1% low, 0.1% low and frame-time statistics;
- CPU versus GPU time attribution;
- any correctness difference.

See the roadmap, the 2026-09-06 landscape snapshot (preserved), the 2026-09-07 delta, and the porting matrix for rationale and source commits.