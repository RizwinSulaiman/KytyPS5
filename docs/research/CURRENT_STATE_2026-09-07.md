# Demon’s Souls current state — 2026-09-07

This is the current orchestrator delta. It supersedes stale ordering in older Phase 1 notes where those notes conflict with evidence below. Older documents remain historical evidence.

## Immediate objective

Get Demon’s Souls to reproducible, correct gameplay on the RX 9070 XT, then drive the fixed gameplay benchmark toward a stable measured 30 FPS (<=33.3 ms). Do not optimize menu-only behavior. 60 FPS remains a later target.

## Preserved control

`phase1/demons-souls-playable` at `9528c92` is the pushed known-good control: Almo storage-format capability gate (`6ce809a`) removes the AMD BC5/VK_FORMAT_BC5_UNORM_BLOCK storage-usage abort and reaches the rendered LANGUAGE SELECT menu. The clean single-instance control run `20260907-020322` survived 31.8 s with empty stderr; GPU utilization was ~32-36% but is not FPS; RSS 1.4 -> 5.6 GB is a watch item, not a leak claim.

## Local experimental stack (not yet pushed)

A separate local branch `phase1/demons-souls-senaxx-stack` was reconstructed from upstream `74a78f3` with the full 13-commit Senaxx correctness staircase in original order, followed by the validated BC5 gate and benchmark/docs infrastructure. The stack applied without conflicts. Focused guest-lane tests passed 8/8; full CTest was 29/36 with the same seven AMD image/depth/MSAA failures seen before, so no new regression was detected. A 90 s game run `20260907-032126` stayed alive beyond the old BC5 crash point, but later screenshots/results are not yet authoritative because the Desktop Commander command transport dropped during inspection.

## Critical fresh upstream change

Do not treat `74a78f3` as current upstream. As of this note, official `KytyPS5/KytyPS5` main is `2097ebb41497e70339c861e1262caf7c17022ec3`, **91 commits ahead** of `74a78f3`.

This delta is directly relevant to Demon’s Souls correctness and overlaps donor research. Notable commits include:

- `c7f7fd9` — textures: use backing format for alias uploads.
- `2462127` — AGC: merge resources from both shader stages.
- `3213934` — shader: run merged geometry stages as mesh shaders.
- `251f6d6` — shader: fix returns and descriptor placement.
- `59902d1` — shader: skip resources in untaken uniform branches.
- `2ec0e9e` — shader: fix packed image address reads.
- `44f982b` — render: apply DCC clears before binding images.
- `6ca8201` — textures: handle DCC memory reused as HTile.
- `587df91` — render: validate sampled depth descriptors independently of target history.
- `2097ebb` — render: support overlapping fragment depth feedback.

The 91-commit range also substantially rewrites texture/resource materialization, image/depth handling, pipelines/descriptors, AGC, shader CFG/lowering, memory tracking, and compute tests. Therefore donor patches must be range-diffed against current upstream before porting.

## Donor status after refresh

### Almo7aya/KytyPS5

Main still ends at `609302b` (`perf(renderer): optimize asynchronous graphics pipelines`), immediately after `953b1ce` (the storage-image format capability gate already validated on this RX 9070 XT).

Almo branch `fix/dcc-clear-before-sampling` ends at `c3929f7`, but official upstream now contains `44f982b` (`apply DCC clears before binding images`) co-authored by Techx3 and Brandon Strong and later DCC/HTile/depth changes. Treat the Almo DCC branch as a comparison/reference, not an automatic cherry-pick.

### Senaxx/KytyPS5

`main` still ends at `2db19f7`. A separate `development` branch ends at `9b33429` and is explicitly published as a recovered visual-baseline source snapshot; its commit message states that build/test/GPU/game verification was not rerun and known rendering/compatibility limitations remain. It contains substantial DCC/metadata/resource work. Treat it as an untrusted donor until diffed against current upstream and validated locally; do not merge it wholesale just because it is newer.

## Required next research/implementation order

1. Fetch official upstream and preserve `9528c92` as the immutable pushed Language Select control.
2. Make a fresh experimental branch from current upstream `2097ebb` (or newer if upstream advances again before work starts).
3. Build/test current upstream alone on this Windows + RX 9070 XT machine and run the same controlled Demon’s Souls progression benchmark. Record exact first blocker and screenshots.
4. Determine whether the BC5 storage-capability gate is already present/equivalent upstream. If not, port/reapply `6ce809a` narrowly and validate it.
5. Range-diff the full Senaxx 13-commit staircase against current upstream. Reapply only semantics that remain genuinely missing; do not mechanically replay obsolete/conflicting commits.
6. Compare Senaxx `development` and Almo DCC work against current upstream only for still-missing semantics, especially DCC materialization/invalidation, HTile/depth overlap, image-table/resource tracking, descriptor/mip/layer correctness, and scene-material corruption.
7. Establish reproducible gameplay (character creation/intro/Outpost or farther) before performance claims.
8. Upgrade measurement to real present/frame-time data and PID-attributed resource measurements. Use a fixed gameplay route, not menu timing.
9. Once gameplay is correct/repeatable, profile CPU vs GPU frame time and work toward stable 30 FPS. Only then evaluate Almo async-pipeline/performance work and other optimizations against measured bottlenecks.

## Agent operating rules

The Paseo -> OpenCode -> Muse Spark 1.3 Contributor session owns implementation/research iteration. It should investigate broadly and think independently rather than follow a hardcoded patch list. It must keep `MASTER_TRACKER.md`, `LOCAL_TESTING.md`, donor/landscape notes, and this current-state note synchronized with measured results. Every claimed breakthrough needs exact source SHA, donor attribution where applicable, test results, benchmark artifacts, and visual/runtime evidence. Preserve known-good checkpoints and keep game data/benchmark artifacts out of Git.

The parent/orchestrator independently reviews screenshots, diffs, benchmark evidence, regressions and promotion decisions. Do not push every small edit; preserve the existing bundled checkpoint push policy.
