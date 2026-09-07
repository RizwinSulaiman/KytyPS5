# Demon's Souls / PS5 Performance Research

This directory is the engineering notebook for this fork's primary target: **correct Demon's Souls Remake gameplay at 60 FPS on a Ryzen 7 7700X + Radeon RX 9070 XT Windows host**.

## Documents

- [Phase 1 correctness plan](./PHASE1_CORRECTNESS_PLAN.md) — active course-corrected pass: exact order, pinned SHAs, gates. Start here.
- [Local testing](./LOCAL_TESTING.md) — Windows build/test baseline, `38c5c3f` focused gates, and first-benchmark placeholder.
- [Master tracker](./MASTER_TRACKER.md) — live P0/P1/P2 checklist and 30/45/60-FPS milestones.
- [PS5 emulator landscape delta 2026-09-07](./PS5_EMULATOR_LANDSCAPE_2026-09-07.md) — pinned heads, landed first port (`38c5c3f`), Sep 7 ecosystem delta.
- [PS5 emulator landscape](./PS5_EMULATOR_LANDSCAPE_2026-09-06.md) — preserved snapshot: audited projects, Demon's Souls discoveries, source-quality triage.
- [Demon's Souls 60-FPS roadmap](./DEMONS_SOULS_60FPS_ROADMAP.md) — ordered correctness/performance plan and measurable 16.67-ms target.
- [Cross-emulator porting matrix](./PORTING_MATRIX.md) — what to port, reimplement, audit, benchmark, defer, or reject.
- [Format-141 abort analysis](./IMAGE_FORMAT141_ANALYSIS.md) — run 1-2 blocker mapping + ranked fix proposal (not implemented, awaiting review).

## Baseline

Research began from upstream KytyPS5 main:

- commit: `74a78f37d08fabae0a37e621ef209786796c37fe`
- date: 2026-09-05
- message: `renderer: grow repeatedly joined buffer ranges (perf)`

The fork should continue tracking upstream; this directory records external ideas so they are not lost during rebases.

Fork checkpoint 2026-09-07: `phase1/demons-souls-playable` at `38c5c3f` (donor Senaxx `2db19f7` preserved as author; OUR: guest-lane 8/8, full 25/36 same 11 pre-existing failures).

## Primary source repositories

1. Upstream KytyPS5 — https://github.com/KytyPS5/KytyPS5
2. Almo performance branch — https://github.com/Almo7aya/KytyPS5
3. Prosperity — https://github.com/Force67/prosperity
4. SharpEmu — https://github.com/sharpemu/sharpemu
5. KytyPlus — https://github.com/Coder787-source/KytyPlus
6. Hyper5 — https://github.com/Union-Crax/Hyper5
7. Senaxx/KytyPS5 — highest-priority DS correctness donor this pass (see landscape delta 2026-09-07)

Secondary/derivative projects are documented in the landscape file where useful.

## Project video reference

The supplied video reference is:

- https://youtu.be/QWuOUXaxavc
- **PS5 Emulation Improving FAST! Demon's Souls is Now Booting**
- Video Game Esoterica

It is used as a bring-up reference, not as 60-FPS benchmark evidence.

## Evidence policy

Performance claims in this fork should always identify:

- exact git commit;
- exact game version/title ID;
- host CPU/GPU/driver;
- resolution/rendering mode;
- cold versus warm cache;
- fixed benchmark route/duration;
- average, 1% low and frame-time data;
- CPU versus GPU frame-time attribution;
- correctness regressions, if any.

No optimization is accepted merely because GPU/CPU utilization changed or an FPS overlay went up in a non-repeatable scene.

## Donor-code policy

All code sources reviewed here are external projects with their own authorship/history. Preserve GPL-compatible licensing/attribution and record donor repository + source SHA in adapted commits. Prefer a clean Kyty-specific implementation when architectures differ substantially.
