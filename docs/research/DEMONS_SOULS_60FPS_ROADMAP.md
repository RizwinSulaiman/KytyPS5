# Demon's Souls 60-FPS Roadmap

Research date: 2026-09-06

## Goal

Run Demon's Souls Remake at a stable 60 FPS on the target PC:

- CPU: AMD Ryzen 7 7700X (8 cores / 16 threads)
- GPU: AMD Radeon RX 9070 XT
- RAM: 64 GB
- OS: Windows

A 60-FPS target means **16.67 ms total frame time**. We should not optimize toward a headline FPS counter until we can separately measure CPU emulation time, GPU execution time, synchronization stalls, shader/pipeline compilation, readback stalls, and presentation.

The first objective is a correct and repeatable gameplay scene. Then we reduce its frame budget.

---

# Definition of success

## Correctness gate

Before calling any result a performance win, the benchmark scene must have:

- no skipped required draws after warm-up;
- no missing AGC submissions/ring work;
- no unresolved shader opcodes hit by the scene;
- no fallback 1x1/null textures where a real game resource should exist;
- correct major render targets and fullscreen passes;
- stable input/game progression;
- no unbounded host-memory growth;
- no synchronization timeout or device loss;
- no frame-to-frame corruption caused by missing CMASK/DCC/HTILE semantics.

## Performance gate

After warm-up, record at least 120 seconds of the same gameplay path and report:

- average FPS;
- 1% low and 0.1% low;
- CPU frame time;
- GPU frame time;
- present/vblank wait time;
- number and duration of GPU readback waits;
- graphics/compute pipeline misses and compile milliseconds;
- shader translation misses and compile milliseconds;
- descriptor writes/updates per frame;
- Vulkan submissions per frame;
- barrier counts grouped by source/destination stage and access;
- `ALL_COMMANDS` barrier count;
- command-buffer flush/wait count;
- bytes uploaded/downloaded per frame;
- buffer-cache realloc/copy bytes;
- texture detile/retile bytes and dispatch time;
- host allocations on the render thread;
- process RAM and VRAM usage.

A 60-FPS build is accepted only if the game is correct and frame-time spikes remain controlled after shader warm-up.

---

# Phase 0 — establish the Demon's Souls truth baseline

Do this before merging experimental performance code.

1. Build current fork from upstream baseline `74a78f37...` in Release.
2. Run the exact same game version/settings each test.
3. Prefer the game's 60-FPS/performance rendering mode if selectable; do not begin by forcing 4K quality mode.
4. Capture:
   - first boot to gameplay;
   - second warm-cache boot;
   - one fixed gameplay route;
   - shader/pipeline cache sizes;
   - CPU/GPU utilization and frame times.
5. Record the exact driver version.
6. Keep debug/Vulkan validation disabled for performance runs; have a separate correctness build with validation available.
7. Keep logging minimal and counted, not firehose-style.

The supplied YouTube reference is "PS5 Emulation Improving FAST! Demon's Souls is Now Booting". That is a bring-up milestone, not a 60-FPS baseline. Our repository should preserve measured numbers rather than infer performance from videos.

---

# Phase 1 — port the highest-confidence Almo performance work

## 1A. Async shader/pipeline system

Source concept/branch: Almo7aya/KytyPS5 `609302b40f90ee96a623a0956de5bb064bf20b51`.

### Port goals

- Separate cache lookup from expensive translation/driver compile.
- Introduce explicit pipeline state:
  - Missing
  - Translating
  - Compiling
  - Ready
  - Failed
- Deduplicate concurrent requests for the same shader/pipeline.
- Use a bounded worker pool; start with `min(physical cores - 2, 6)` on the 7700X and benchmark rather than automatically consuming half/all logical threads.
- Keep Vulkan driver-cache synchronization valid.
- Reuse completed translation results across resource-specialization permutations.
- Add Graphics Pipeline Library fast-linking when supported.
- Cache render-state/prepared-binding work using version stamps.

### Important correction to the donor branch

Skipping a required cold draw while a pipeline is pending can improve apparent responsiveness but can produce missing geometry. For our 60-FPS target:

- allow async draw skipping only in an explicit experimental mode;
- provide a correctness mode that blocks only when the required pipeline is first encountered;
- ideally precompile from captured pipeline keys during loading/scene transitions so normal gameplay never needs to skip.

### Benchmark

Compare:

- cold startup;
- first traversal of benchmark scene;
- second traversal;
- warm restart;
- total compilation wall time;
- render-thread blocked time;
- pipeline count.

Expected primary benefit: traversal stutter and CPU stalls, not necessarily warm steady-state FPS.

---

## 1B. CPU-readback shadow path

Compare current upstream 512-KiB readback-window behavior with Almo `97a895b...`.

### Implement a unified adaptive policy

Track per buffer:

- CPU-read frequency;
- GPU-write frequency;
- sequentiality/locality;
- requested bytes;
- downloaded bytes;
- number of GPU drains avoided;
- wait duration.

Policy idea:

- rare/random tiny read: small exact/16–32 KiB window;
- clustered read: 128–512 KiB window;
- repeated CPU polling of GPU-owned counters/query buffers: host-visible shadow snapshot;
- clearly streaming buffer: larger owning-buffer window up to a measured cap.

Do **not** simply combine a fixed 512-KiB window with an 8-MiB owning-buffer read. That can magnify PCIe traffic on the RX 9070 XT.

### Success metric

Reduce `FlushAndWait`/timeline waits caused by CPU polls and reduce downloaded/requested-byte amplification without breaking guest visibility semantics.

---

## 1C. Synchronization cleanup

Start from Almo `b072439...`, then go deeper.

- Avoid redundant predication waits.
- Batch end-of-pipe fences.
- Rate-limit completion polling.
- Instrument every explicit CPU wait with a reason code.

Then build a proper synchronization2 resource-state layer:

- track last writer stage/access;
- track next reader/writer stage/access;
- emit the narrowest valid barrier;
- eliminate compatible read->read dependencies;
- batch barriers;
- stop defaulting to `ALL_COMMANDS` when precise stages are known.

**Never remove a conservative barrier because it looks expensive.** Tighten it only when the resource dependency is proven.

Expected steady-state benefit: potentially large if the current frame is GPU-pipeline-drain limited.

---

# Phase 2 — Demon's Souls correctness audit using Prosperity findings

This phase asks, one by one: "Does current Kyty implement the behavior that Prosperity found this game actually exercises?"

## 2A. AGC queues/rings/doorbells

Reference: Prosperity `12d4d83...`.

Audit Kyty for:

- queue creation versus submission semantics;
- write-pointer/doorbell updates that submit without a new ioctl;
- chained command buffers;
- queue ownership;
- end-of-frame signaling;
- dropped/ignored packet counters.

Add a Demon's Souls AGC census:

- packets seen;
- packets handled;
- packets intentionally ignored;
- packets unknown;
- draws/dispatches discovered;
- draws/dispatches actually issued;
- submission gaps by queue.

Target: **zero unexplained dropped packets in the benchmark scene.**

## 2B. `WRITE_DATA` semantics

Reference: `66414585...`.

Confirm Kyty distinguishes register-targeted versus memory-targeted WRITE_DATA forms and that register writes invalidate/update the correct cached state versions.

## 2C. NGG vertex input/index

References: `f93ca569...`, `8e61020...`.

Verify:

- merged NGG vertex index source used by Demon's Souls;
- fullscreen RECTLIST passes;
- inline V# resources indexed by the vertex index;
- embedded fetch detection does not misclassify per-vertex loads as uniform.

Kyty already has substantial embedded vertex-fetch analysis, so this is a targeted validation, not an assumption that the feature is missing.

## 2D. Shader opcode / lowering matrix

References: `baa3a9d...`, `ebe8546e...`.

Create a generated report from the real Demon's Souls shader corpus:

- every decoded opcode;
- count by shader stage;
- implementation status;
- fallback/dispatcher use;
- generated SPIR-V instruction count;
- compile time;
- shader GPU time where available.

Specifically audit:

- gfx10.3 formatted buffer loads;
- global/flat loads;
- saveexec forms;
- readlane/writelane;
- buffer atomics;
- MIMG sample/gather variants;
- 3D textures;
- branch-sensitive SRT descriptor tracking.

## 2E. gfx10.3 image/swizzle formats

Verify every tiling/swizzle mode used by the benchmark scene maps to a correct detile/retile implementation. Incorrect staging often looks like a shader bug.

## 2F. Resource/state address assumptions

Reference: `318442d...`.

A PS5 state block may be CPU-built/readable even if it is outside a narrow GPU-aperture heuristic. Audit any address-range rejection that can drop shader/context blocks solely because of where they live.

## 2G. POS1/POS2/POS3 and secondary exports

Do not reject an entire otherwise-valid draw solely because secondary position/export semantics are not fully modeled if a safe approximation is possible. Add per-export counters and screenshot/regression tests.

## 2H. DCC/CMASK/HTILE metadata

References: Prosperity `e7409a3...`, Almo `4b6ba30...`, SharpEmu `f8a826e...`.

Create one explicit metadata state machine rather than scattered heuristics:

- surface registration;
- clear metadata;
- dirty state;
- deferred clear arriving before surface creation;
- clear-word decoding;
- sampling a render target;
- transitions across frame boundaries.

Measure correctness first; then optimize away unnecessary copies/decompress-style emulation.

---

# Phase 3 — shader backend performance

This is where 60 FPS may ultimately be won on the RX 9070 XT.

## 3A. Audit aligned dword operations

Reference: SharpEmu `fe6521f...`.

For each Kyty IR/Spir-V load/store path, ensure naturally aligned 32-bit and x2/x3/x4 operations are not lowered into byte-by-byte reconstruction unless the guest opcode truly allows/requires unaligned behavior.

Add unit tests that count emitted SPIR-V instructions for representative operations.

## 3B. f16 lowering

Reference: SharpEmu `2b8ef7d...`.

Use native 16-bit arithmetic/storage only where Vulkan features and semantics are correct; avoid widening every operation to f32 if it measurably increases register pressure/instruction count.

## 3C. Dispatcher-fallback reduction

Kyty logs when structured CFG translation fails and falls back to a dispatcher. Build a Demon's Souls report:

- fallback shaders / total shaders;
- GPU time contribution;
- reason/failure class;
- instruction-count expansion.

Prioritize the hottest fallback shader first.

## 3D. Persistent emulator-side shader cache

Current Vulkan pipeline cache should remain, but add a second cache tier:

1. guest code -> decoded/optimized Kyty IR/resource plan;
2. specialized IR -> SPIR-V;
3. SPIR-V -> native driver pipeline remains the Vulkan pipeline cache.

Key must include at least:

- recompiler/schema revision;
- stage;
- guest code hash/size;
- relevant static shader state;
- resource specialization;
- wave/subgroup options;
- translation flags.

This reduces restart/traversal cost across both AMD and NVIDIA without sharing vendor-native blobs.

## 3E. AMD host-ISA feedback loop

For RX 9070 XT profiling, use Radeon GPU Profiler / Radeon GPU Analyzer where practical to identify:

- wave occupancy;
- VGPR/SGPR pressure;
- LDS pressure;
- divergent branches;
- cache misses;
- long-running compute shaders;
- barrier-induced bubbles.

Do not assume an RDNA2 guest shader automatically becomes efficient Radeon host code after SPIR-V translation.

---

# Phase 4 — hot cached-draw path

Once shader/pipeline misses are no longer dominating, make a warm draw boring and cheap.

Target properties:

- zero heap allocations on a cache hit;
- no global shader/pipeline mutex on a hit;
- no rebuilding descriptor arrays if bindings/state did not change;
- no redundant image transitions;
- no redundant dynamic state commands;
- no repeated object naming/log formatting in Release;
- no state-block memcmp when a version stamp proves unchanged.

Inspired by:

- Almo cached state/version stamps;
- SharpEmu packed allocation-free shader-cache keys;
- Kyty's recent pipeline-key cardinality reductions.

Add a per-frame allocator counter for the render thread.

---

# Phase 5 — descriptor and pipeline-layout reuse

## Layout caches

Cache independently:

- descriptor set layouts by normalized binding signature;
- pipeline layouts by descriptor-layout + push-constant signature.

Do not recreate equivalent layouts for every graphics pipeline.

## Descriptor fast path

Telemetry first:

- descriptor writes/frame;
- push descriptor calls/frame;
- `vkUpdateDescriptorSets` calls/frame;
- identical binding packets repeated;
- descriptor heap rotations.

Then add binding-packet deduplication. Consider `VK_EXT_descriptor_buffer` only as an optional benchmarked path, never as an assumed universal win.

---

# Phase 6 — reduce pipeline-key cardinality further

Upstream already moved several states to dynamic state. Build a cardinality report showing which remaining key fields multiply pipeline count most heavily.

Candidate states should only become dynamic if:

1. the extension is well supported on our target GPU;
2. the field causes substantial pipeline duplication;
3. per-draw dynamic-state overhead is lower than the compile/cache cost.

Potential extensions include further extended dynamic state and dynamic vertex input.

Do not make every field dynamic by default.

---

# Phase 7 — rendering-resolution strategy

Only after frame-time attribution:

## If GPU time > 16.67 ms and CPU time is comfortably below budget

- test reduced internal resolution;
- compare native scaling versus FSR1 EASU/RCAS inspired by KytyPlus;
- preserve UI/presentation correctness;
- measure GPU time, not just FPS.

## If CPU/emulation/synchronization time > 16.67 ms

FSR/upscaling is not the fix. Continue with:

- shader translation/cache;
- descriptor preparation;
- barriers/submissions;
- readback waits;
- packet processing;
- memory tracking.

---

# Phase 8 — optional async compute / transfer

This is intentionally late.

First record whether the graphics queue contains idle bubbles and whether tiling/detiling/copy work can overlap without violating guest ordering.

Prototype only when profiling shows a likely benefit:

- dedicated compute queue for suitable detile/metadata work;
- transfer queue for independent copies where available;
- timeline semaphore dependencies between queues.

Reject the experiment if cache contention, extra synchronization, or reduced occupancy makes frame time worse.

---

# Logging policy

Performance runs must never write massive synchronous logs.

Adopt the useful KytyPlus/Prosperity lesson:

- repeated identical warnings are counted/deduplicated;
- hot events are counters, not formatted strings;
- verbose shader/packet dumps require explicit debug flags;
- Release mode defaults to summary telemetry.

Every warning class should expose a final count at shutdown or on-demand.

---

# Integration order

## P0 — required before performance claims

1. Benchmark harness + telemetry.
2. Demon's Souls AGC packet/submission census.
3. Shader/opcode/resource correctness census.
4. Memory-growth/leak check.
5. Fixed reproducible gameplay capture.

## P1 — highest expected return

1. Port/rebase Almo async translation/pipeline system.
2. Port Almo synchronization reductions where still applicable.
3. Unify adaptive CPU-readback + shadow policy.
4. Audit hot shader lowering using SharpEmu's aligned-dword lesson.
5. Resolve any Prosperity-identified Demon's Souls correctness gaps that still exist in Kyty.

## P2

1. Persistent Kyty IR/SPIR-V cache.
2. Layout caches.
3. Barrier/resource-state optimizer.
4. Hot cached-draw allocation elimination.
5. Pipeline-key cardinality profiler + selected dynamic-state extensions.

## P3

1. FSR/internal-resolution experiments if GPU-bound.
2. Async compute/transfer only if traces justify it.

---

# Performance milestones

Do not jump directly from "boots" to "60 FPS". Track these gates:

- M0: boots reproducibly to gameplay.
- M1: correct benchmark scene with no unexplained dropped draw/dispatch work.
- M2: stable warm 30 FPS, frame time <= 33.3 ms.
- M3: stable warm 45 FPS, frame time <= 22.2 ms.
- M4: stable warm 60 FPS, frame time <= 16.67 ms.
- M5: traversal-quality 60 FPS with controlled shader/pipeline stutter and good 1% lows.

For each milestone, preserve the capture and telemetry so regressions can be bisected.

---

# First engineering branch recommendation

Create a branch from current upstream named something like:

`perf/demons-souls-pipeline-lab`

On it, port the Almo async-pipeline work in small commits rather than cherry-picking the large donor commit wholesale:

1. instrumentation/version stamps;
2. worker/job infrastructure;
3. async shader translation;
4. async graphics pipeline build;
5. GPL fast-link path;
6. cached prepared state/bindings;
7. correctness/blocking mode;
8. benchmark and regression tests.

This minimizes conflicts with upstream's newer pipeline-key and buffer-cache changes and makes every speedup independently measurable.