# PS5 Emulator Landscape — 2026-09-06

This document records the current PS5-emulation work that is materially useful to this fork. The goal is not to collect every repository named "PS5 emulator"; it is to identify implementation work that can help KytyPS5 reach correct, high-performance Demon's Souls emulation.

## Target

- Game: Demon's Souls Remake, PPSA01341/PPSA01342 family
- Immediate target hardware: AMD Ryzen 7 7700X, Radeon RX 9070 XT, 64 GB RAM, Windows
- Performance target: 60 FPS / 16.67 ms frame time after correctness is established
- Reference video supplied for this project: `https://youtu.be/QWuOUXaxavc`, titled **"PS5 Emulation Improving FAST! Demon's Souls is Now Booting"** by Video Game Esoterica. The title demonstrates the current milestone is boot/gameplay progress; it is not evidence of 60-FPS emulation.
- Upstream baseline at research start: KytyPS5/KytyPS5 `74a78f37d08fabae0a37e621ef209786796c37fe` (2026-09-05)

## Source-quality rule

Only repositories with inspectable source, meaningful commit history, and concrete emulator implementation are treated as engineering sources. Tiny repositories and marketing/download pages that claim PS5 games are already broadly playable at 60 FPS without inspectable implementation evidence are excluded.

All major source projects below are GPL-2.0-family projects as observed during this review. Any code port must preserve applicable license notices and authorship. Prefer documenting and independently porting concepts unless a direct code transplant is clearly compatible and traceable.

---

## 1. KytyPS5 upstream

Repository: https://github.com/KytyPS5/KytyPS5

### Current strengths

- Vulkan 1.3 renderer.
- Dynamic rendering and synchronization2.
- Timeline semaphore-based scheduling.
- Buffer device address support and a GPU page-table/fault system.
- VMA-backed host GPU allocation with memory-budget awareness.
- Push descriptors when the host supports enough descriptors, descriptor-pool fallback otherwise.
- Runtime shader translation to SPIR-V with Kyty IR passes.
- Persistent per-title Vulkan driver pipeline cache.
- Recent work reducing graphics-pipeline key cardinality and improving buffer/readback behavior.

### Recent upstream performance work

- `3628d2b4c15a99b48f042b6d84a24876d93e39e5` — remove dynamic draw state from pipeline keys.
- `8d3ebb5a55631a46ea770ffcf75aeedeefbe16fd` — widen buffer readback windows to amortize CPU faults.
- `74a78f37d08fabae0a37e621ef209786796c37fe` — grow repeatedly joined streaming buffer ranges to avoid repeated reallocation/copy churn.

### Demon's Souls bring-up

Upstream PR #477 is the critical milestone:
https://github.com/KytyPS5/KytyPS5/pull/477

It added/fixed:

- Vulkan graphics-pipeline behavior needed by Demon's Souls.
- 1-level indirect image descriptor-table materialization.
- Vertex-input assembly.
- Depth/stencil fallbacks.
- Color-target write masking.
- Texture tiler capacity/overlap handling.
- Foundational Ngs2 audio stubs.

Result: Demon's Souls progressed through intro/menu/loading into actual gameplay, but with very modest in-game FPS.

### Main remaining architectural concerns

- Guest shader translation / SPIR-V program cache is process-local; the Vulkan driver cache does not eliminate all emulator-side compile work after restart.
- Shader/program/pipeline cache paths still contain broad serialization points.
- Numerous conservative `ALL_COMMANDS`-style synchronization paths remain.
- Per-draw descriptor/resource preparation can be substantial.
- CPU/GPU ownership handoffs and readbacks can stall the entire graphics stream.
- One universal graphics+compute+present queue is the main execution model.

---

## 2. Almo7aya/KytyPS5 — highest-priority performance donor

Repository: https://github.com/Almo7aya/KytyPS5

This is currently the most relevant performance branch because it implements several changes that independently emerged from the Kyty performance review.

### `609302b40f90ee96a623a0956de5bb064bf20b51` — asynchronous graphics pipelines

Implements:

- `--async-shaders` option, enabled by default.
- Worker pool using roughly half of hardware concurrency.
- Asynchronous guest shader translation and graphics-pipeline construction.
- Shared translation jobs across resource-specialization variants.
- Pending/completed pipeline state instead of synchronously compiling every cold draw.
- GPU-thread adoption of completed shader/pipeline work.
- Skips a cold draw while its required pipeline is still being built, then retries on later frames.
- Cached prepared bindings/render state to avoid repeated cold-path work.
- Register/state version stamps to avoid repeatedly diffing large register blocks.
- Graphics Pipeline Library support using `VK_EXT_graphics_pipeline_library` + `VK_KHR_pipeline_library` when the device exposes fast linking.
- Driver/library compilation outside long-lived map locks, then race-deduplication on insertion.

This is the first code branch to evaluate for our fork, but it must be rebased/ported carefully because upstream changed pipeline keys and readback code after the branch point.

### `97a895b20ad9fbd9acb50330fba1b983dc4f1707` — avoid repeated GPU drains for CPU readbacks

Observed a title doing about 42 whole-GPU drains per frame while polling counters/query results. The branch:

- Widens a readback to the owning buffer, bounded to 8 MiB.
- Marks buffers that are repeatedly read by the CPU as hot.
- Captures host-visible shadow copies after GPU writes.
- Publishes completed shadows back into guest memory after the relevant timeline tick.
- Lets later CPU polls avoid faulting/draining the GPU.
- If a read arrives early, waits only for the shadow's tick where possible.

Upstream subsequently implemented a different 512-KiB readback-window optimization, so these approaches should be benchmarked/merged conceptually rather than blindly cherry-picked together.

### `b072439d0c48c10b73460ef79022eec4bb2a3e65` — synchronization overhead

- Avoid redundant predication waits.
- Rate-limit timeline-semaphore refreshes.
- Batch end-of-pipe fence submissions.

### `0713aeb7173575ab96c18a7ab7004401e0021a3a` — shader translation overhead

- Bounds speculative CFG repair.
- Reduces repeated SRT resource-materialization work during compilation.

### Correctness work also worth comparing

- `4b6ba30a6dc0991a51c47ed16a8666a7e0507e8d` — deferred DCC metadata clear handling.
- `ed36c3a61dc978088449dc79a7283c83600c3a53` — honor mapped resource extents.
- `6219275f298e6436e3fa8c06197b6202b437d08c` — sanitize malformed/unmapped descriptors.
- `10011328d9d24f9f476f8af306ba9dc63e6c0bf8` — safer synthetic occlusion results.
- `953b1ceccede502ec4b569e2702d7987393956ff` — only request storage-image usage when the host format supports it.

---

## 3. Force67/prosperity — highest-priority Demon's Souls correctness source

Repository: https://github.com/Force67/prosperity

Prosperity is an experimental PS4/PS5 emulator in C++ and has a unusually concentrated Demon's Souls investigation. Even when its architecture cannot be directly transplanted, its findings are extremely valuable because they identify actual PS5/AGC/RDNA2 behaviors hit by this game.

### Demon's Souls-specific discoveries

#### AGC submission / doorbells

`12d4d83e82d2bd3319135b3b4a18404b4deac6aa`

- `0xC0408121` was identified as queue creation rather than a normal submit.
- The game later submits by updating a ring write pointer / doorbell, without another ioctl.
- Polling the doorbells changed one observed draw into roughly 1,868 issued draws in that investigation.
- Also returned a real submit-state pointer used by libSceGnmDriver.

This is a major warning for Kyty: if a queue/ring path is only approximately modeled, work can be silently missing while the emulator appears to be "running."

#### RDNA2 recompiler gaps

`baa3a9d6892553b6627fe6d44a4261e18f9e26f0`

Added/handled behaviors Demon's Souls actually exercised, including:

- gfx10.3 buffer-load-format handling.
- additional scalar/vector operations.
- SRT-chain-produced compute descriptors.
- gfx10.3 swizzle/addressing modes including 64KB render-target families.

`ebe8546e682917b940e5d90c0b54481c75cd043d`

Further covered:

- FLAT/global-load forms.
- gfx10 saveexec SOP1 block.
- readlane/writelane forms.
- more MIMG sample/gather forms.
- buffer atomics.
- 3D image staging.
- descriptor replay across branches.

These are useful as a feature checklist against Kyty's decoder/recompiler, not as a direct assumption that Kyty lacks all of them.

#### NGG vertex-index semantics

`f93ca5694bd386652a5dd74f1488666fa1e9582c`

- Identified `v5` as the merged NGG vertex index for relevant Demon's Souls fullscreen passes.
- Leaving it at zero collapsed fullscreen geometry to a point in that implementation.

`8e61020dc97e2eeaf204793b4b5ab318e43073c1`

- Additional investigation of inline V# buffer loads indexed by `v5` and why treating them as uniform fetches is wrong.

#### PS5 packet/state semantics

`66414585c9f72506b74f56c7996ad4594a0efef4`

- `WRITE_DATA` with `DST_SEL=0` writes registers, not guest memory; treating it as memory silently discarded streamed state.

`318442d3788cc6ae68a935823859b34ac9c22410`

- State blocks can be CPU-readable data outside a narrowly assumed GPU aperture.
- Demon's Souls was dropping a significant fraction of context/SH blocks under the stricter assumption.
- POS1..POS3 exports may need approximation instead of rejecting the whole draw when their secondary semantics are not yet modeled.

`34b25ba3f957e620381bec3e42ade4e4beb05e3f`

- Corrected PS5 ioctl handling including an AGC end-of-frame signal form; in that implementation, an unhandled INOUT form meant finished frames were not presented.

#### Texture / metadata semantics

`e7409a3d6622b4fa2391d9ec2c5b8c5cc16e5f90`

- DCC metadata bits do not inherently make a texture descriptor invalid when the emulator resolves a sampled render target through its own backing/page-table model.
- Over-strict rejection produced fallback textures and incorrect output.

#### Boot-time I/O / decompression

`9ad850e05c8e18f31becd0d281c40a1ba48cdacd`

- Reusing RAR decoder state instead of rebuilding a large dictionary per file cut one observed Demon's Souls graphics-start time from about 140 s to 53 s.
- Not a frame-time optimization, but a strong example of profiling a title-specific hot path rather than assuming GPU work is always the bottleneck.

#### Logging and retry loops

`ee478624db026246aa597262411ed4acda3e9539`

- A repeatedly queried unknown sysctl was generating roughly 9,000 logs/s and tens of MB of logs during Demon's Souls startup.
- Deduplicating/answering the expected query removed a major avoidable boot cost.

### Other recent Prosperity work worth borrowing as methodology

- PM4/AGC opcode census tooling to identify silently dropped packets (`cbe5456...`).
- Mid-shader VGPR probes and draw/texture/state censuses.
- Boot-sweep/regression scripts that fingerprint behavior across titles.
- Pixel barycentric seeding for gfx10 PS5 shaders (`ef747551...`).
- Correct 3D/volume-image extent handling (`8fd0c9c...`).

Prosperity's biggest contribution to this project is a **Demon's Souls-specific correctness checklist and instrumentation philosophy**.

---

## 4. sharpemu/sharpemu — active alternate architecture and shader/HLE source

Repository: https://github.com/sharpemu/sharpemu

SharpEmu is an actively developed C# PS5 emulator with a backend-neutral guest-GPU/shader architecture and Vulkan backend.

### High-value performance discoveries

#### `fe6521f617234ce7ff3c4ae80450ba609c82b5df` — aligned dword loads/stores

A generic shader path reconstructed every dword byte-by-byte, causing repeated bounds checks, array accesses and bit assembly. Routing naturally dword-aligned GCN load/store opcodes through direct dword helpers reduced one measured compute shader from about **430–448 ms to 86–92 ms**, roughly a 5x dispatch-time improvement.

Action for Kyty: audit emitted SPIR-V for buffer/global dword operations and ensure aligned dword forms do not expand into byte-granular emulation. This is a concept port, not a direct code port.

#### `2b8ef7d8fa1be2a29c90f6ae1554d2c76f9b369b`

- Compact f16 arithmetic/compare lowering.

#### Allocation-free shader-cache hit path

SharpEmu's GPU refactor packed output-layout state into compact keys, moved caches to concurrent structures, and removed per-draw LINQ/temporary allocation on cache hits. The general lesson is applicable to Kyty: the hot cached-draw path should allocate zero heap memory and take no global mutex unless a resource hazard truly requires it.

### AGC / synchronization lessons

`62c3852556401883b31abf1623b3b48572b65e0b`

- Recovered missed fence writes around AGC arena transitions.
- Fixed submission accounting and chained command-range traversal.
- Recovered orphaned builder-ring work.
- Improved ring reuse/cursor regression handling.

`3a744c991efbbcb942aca7b1d49a52ee84afd0d8`

- Ensured WRITE_DATA-produced labels participate in WAIT_REG_MEM progress tracking.

`f8a826ec1b1ffba29ffcfd8ac0b7bf90a7430e22`

- CMASK/DCC metadata state tracking.
- Frame/fence freshness to prevent stale previous-frame labels satisfying new waits.
- Removed expensive diagnostic strings from hot paths after investigation.

### Demon's Souls-specific stability / memory lessons

`c086e32f3d72cbb0d0f3a113a63ef1b658216630`

- Fixed a GuestDataPool lease leak on rejected/dropped compute-dispatch paths.
- Verified on Demon's Souls: outstanding pooled leases that previously grew continually were bounded after the fix.

`7521295ee1d57e8e30f93a71e65f75e8482f918c`

- Fixed TLS-patcher coverage by scanning the main image and lazily committed executable ranges.
- Earlier Demon's Souls runs had stalled around import #256.
- Also added real H.264 decode for `sceVideodec2` using FFmpeg, useful for broader PS5 compatibility.

### Current Demon's Souls status caution

A current public SharpEmu issue for PPSA01341 v1.007 on a Ryzen 9900X/RTX 5080 still documented a boot stall on an older August build. SharpEmu is useful as a source of fixes and ideas, not evidence that Demon's Souls is currently 60-FPS playable there.

---

## 5. Coder787-source/KytyPlus — Kyty-derived compatibility/QOL source

Repository: https://github.com/Coder787-source/KytyPlus

Useful items:

### FSR 1.0 path

KytyPlus includes an FSR1 EASU/RCAS upscaling path. This is relevant **only after profiling proves the host GPU is the frame-time limiter**. If emulation is CPU/synchronization bound, lowering render resolution will not create 60 FPS.

Recent fixes include alignment/storage-image handling and image-view caching around the FSR path (`c5ec325...`).

### Log deduplication

`8ca8717b5df408d071f109c1e99782a8f4841fdf`

- Collapses repeated consecutive log lines into a count summary.
- Directly relevant because other PS5-emulation investigations have demonstrated hot retry/sysctl paths producing enormous logs.

### Fence/command robustness

`366bab46e80a87091233915228022fbf01afd428`

- Fence/master-semaphore timeouts.
- Command-buffer reuse changes.
- Audio buffering adjustments.

These are robustness improvements, not automatically FPS improvements.

### Package/PFS/PFSC support

KytyPlus has substantial package/PFS/PFSC parsing/decompression work. Valuable for usability and booting packaged content, but not a priority for the 60-FPS renderer goal.

### Pipeline-cache caution

KytyPlus documentation/older commits present its disk pipeline cache as a differentiator, but current upstream KytyPS5 already has a persistent Vulkan pipeline cache. Compare behavior against the current upstream implementation rather than importing an older cache wholesale.

---

## 6. Union-Crax/Hyper5 — SharpEmu-derived HLE/threading experiments

Repository: https://github.com/Union-Crax/Hyper5

Hyper5 is a SharpEmu-derived branch rather than an independent GPU architecture, but some HLE discoveries are worth retaining.

### Signal / GC behavior

- `bea68da...` — register/trace `sceKernelRaiseException` for Unity/Boehm GC stop-the-world behavior.
- `164d1f1...` — synchronous self-raise delivery.
- `9b05322...` — queue cross-thread raises and deliver at target-thread safe points while preserving guest thread/TLS identity.
- `2586459...` — publish real guest stack ranges through pthread attributes so conservative GC scans valid ranges.
- `658a54a...` — follow-up GC signal delivery and SSE4a compatibility.

These are less directly relevant to Demon's Souls performance today, but they belong in the broader HLE regression checklist.

### `sceKernelDlsym`

`cac3217...` derives NIDs from requested symbol names so engine/game-specific exports can resolve even when only NID-keyed tables exist.

---

## 7. Lower-priority / derivative projects

### Sav-i/ps5-stuff and Fractal-Echo/PS5-Transformed

These currently expose a SharpEmu-style tree/README and describe Demon's Souls reaching a video loop with shaders awaiting SPIR-V/Vulkan conversion. They do not currently provide a stronger unique performance path than SharpEmu main, so SharpEmu is the preferred source of record.

### MagnusPS5

The current public repository is an iPhone/iPad-focused public release with very little meaningful follow-up commit history. It is not a useful source for our Windows/Radeon performance target at present.

### Marketing / download repositories and websites

Repositories/pages claiming broad PS5 compatibility, Demon's Souls "playable" or 60 FPS while providing no serious emulator source/history are intentionally excluded. Do not use these claims as benchmark evidence or download unsigned binaries from them as part of this project.

---

## Ranked donor list for this fork

1. **Almo7aya/KytyPS5** — immediate performance port/rebase candidates.
2. **Force67/prosperity** — Demon's Souls correctness discoveries + instrumentation.
3. **KytyPS5 upstream** — authoritative baseline; keep rebasing.
4. **sharpemu/sharpemu** — alternate shader/HLE implementations and measured optimization ideas.
5. **KytyPlus** — FSR/logging/packaging/robustness ideas.
6. **Hyper5** — selected HLE/thread/signal discoveries.

The next file, `DEMONS_SOULS_60FPS_ROADMAP.md`, turns these findings into an ordered implementation and benchmark plan.