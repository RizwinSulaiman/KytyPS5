# Demon's Souls 60-FPS Master Tracker

Target: stable, correct 60 FPS / 16.67-ms frame budget on Ryzen 7 7700X + Radeon RX 9070 XT + 64 GB RAM, Windows.

## P0 — prove the frame is correct

- [ ] Establish a fixed Demon's Souls gameplay benchmark and exact game version/settings.
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

See the [roadmap](./DEMONS_SOULS_60FPS_ROADMAP.md), [landscape review](./PS5_EMULATOR_LANDSCAPE_2026-09-06.md), and [porting matrix](./PORTING_MATRIX.md) for rationale and source commits.