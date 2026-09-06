# Cross-Emulator Porting Matrix

Last updated: 2026-09-06

Legend:

- **PORT** — source is close enough to Kyty that code can be rebased/ported with attribution and tests.
- **REIMPLEMENT** — use the verified idea/behavior, but architecture differs enough that a fresh Kyty implementation is preferable.
- **AUDIT** — verify whether current Kyty already implements the behavior before changing code.
- **BENCHMARK** — plausible performance optimization, but must prove a gain on the target workload.
- **DEFER** — useful work, not currently on the Demon's Souls 60-FPS critical path.
- **REJECT** — not a credible/appropriate source for this project.

| Source | Commit / feature | Classification | Why it matters | Kyty target area | Priority |
|---|---|---|---|---|---|
| Almo7aya/KytyPS5 | `609302b...` async shader/pipeline workers | **PORT, with rebase** | Removes cold-draw translation/pipeline stalls; shares translation jobs; GPL fast-link path | `pipelineCache.*`, `shaders.cpp`, render state | P1 |
| Almo7aya/KytyPS5 | register/render-state version stamps from `609302b...` | **PORT** | Avoids repeated large state diffs/reconstruction | guest HW context + renderer | P1 |
| Almo7aya/KytyPS5 | Graphics Pipeline Library fast-linking | **BENCHMARK/PORT** | Could reduce PSO creation cost on drivers advertising fast linking | Vulkan device + pipeline cache | P1 |
| Almo7aya/KytyPS5 | `97a895b...` hot CPU-readback shadow buffers | **REIMPLEMENT/BENCHMARK** | Avoids repeated whole-GPU drains for polled GPU-written buffers | buffer cache / memory tracker | P1 |
| Almo7aya/KytyPS5 | `b072439...` redundant wait/fence cleanup | **PORT/AUDIT** | Cuts synchronization overhead | scheduler / command processor | P1 |
| Almo7aya/KytyPS5 | `0713aeb...` bounded CFG/SRT translation work | **PORT/AUDIT** | Reduces compiler-side repeated work | shader recompiler | P1 |
| Almo7aya/KytyPS5 | `4b6ba30...` deferred DCC clears | **AUDIT/PORT** | Demon's Souls relies heavily on render-target/metadata correctness | texture/color-target cache | P1 |
| Prosperity | `12d4d83...` AGC ring/doorbell submission | **AUDIT/REIMPLEMENT** | Missing doorbell-driven work can silently drop thousands of draws | guest GPU command processor | P0 |
| Prosperity | `66414585...` WRITE_DATA register destination | **AUDIT** | Incorrect destination semantics silently discard streamed state | PM4/AGC packet decode | P0 |
| Prosperity | `f93ca569...` NGG vertex index in `v5` | **AUDIT** | Fullscreen passes can collapse if wrong VGPR seeded | vertex/NGG translation | P0 |
| Prosperity | `8e61020...` inline V# + `v5` per-vertex fetch | **AUDIT** | Prevent uniform misclassification of vertex fetches | embedded fetch analysis | P0 |
| Prosperity | `baa3a9d...` gfx10.3 shader/swizzle coverage | **AUDIT** | Enumerates actual Demon's Souls RDNA2 gaps seen elsewhere | decoder/recompiler/tiler | P0 |
| Prosperity | `ebe8546...` FLAT/global, saveexec, MIMG, atomics | **AUDIT** | Actual game shader feature checklist | decoder/recompiler | P0 |
| Prosperity | `318442d...` state blocks outside narrow aperture | **AUDIT** | Over-strict address validation can drop real pipeline state | guest memory/resource materialization | P0 |
| Prosperity | `e7409a3...` DCC bits not descriptor invalidity | **AUDIT** | Prevents legitimate sampled RTs becoming fallback textures | texture descriptor validation | P0 |
| Prosperity | `34b25ba...` PS5 end-of-frame ioctl variant | **AUDIT** | A finished frame can exist but never be presented | kernel/AGC/videoout | P0 |
| Prosperity | `9ad850e...` reuse archive decoder state | **DEFER unless relevant to our dump path** | Reduced one Demon's Souls graphics-start path ~140s -> ~53s | filesystem/archive | P3 |
| Prosperity | `ee47862...` hot sysctl/log dedup | **REIMPLEMENT** | Avoids retry-loop log firehose | logging/HLE | P1 |
| Prosperity | AGC/opcode/draw/state census tools | **REIMPLEMENT** | Fastest path to discovering what Kyty silently drops | diagnostics | P0 |
| SharpEmu | `fe6521f...` direct aligned dword load/store lowering | **AUDIT/REIMPLEMENT** | ~5x measured dispatch improvement in one compute shader | SPIR-V backend | P1 |
| SharpEmu | `2b8ef7d...` compact f16 lowering | **AUDIT/BENCHMARK** | Can reduce instruction/register pressure | SPIR-V backend | P2 |
| SharpEmu | `62c3852...` AGC arena/fence progress recovery | **AUDIT** | Prevents lost GPU work/deadlocks | command processor/scheduler | P0/P1 |
| SharpEmu | `f8a826e...` CMASK/DCC state + stale-frame wait protection | **AUDIT/REIMPLEMENT** | Metadata and fence freshness correctness | texture/sync state | P1 |
| SharpEmu | `c086e32...` rejected-dispatch pool leak | **AUDIT** | Specifically showed bounded memory after Demon's Souls fix | resource pools | P0 |
| SharpEmu | allocation-free/lock-light shader cache hit path | **REIMPLEMENT** | Warm draw should allocate nothing | render hot path | P2 |
| SharpEmu | backend-neutral compiler/GPU seam | **DEFER** | Good architecture, but rewriting Kyty's API seam is not needed for 60 FPS | architecture | P3 |
| KytyPlus | FSR1 EASU/RCAS | **BENCHMARK later** | Useful only if GPU-bound after emulator overhead is reduced | presentation/upscaler | P3 |
| KytyPlus | `8ca8717...` duplicate log collapsing | **PORT/REIMPLEMENT** | Low-risk CPU/I/O cleanup | logging | P1 |
| KytyPlus | fence timeouts | **DEFER** | Debug/robustness; does not itself improve correct frame time | scheduler | P3 |
| KytyPlus | PKG/PFS/PFSC parser | **DEFER** | Usability, not gameplay frame-time critical | package/fs | P3 |
| Hyper5 | cross-thread `sceKernelRaiseException` / GC signals | **DEFER/AUDIT when needed** | Useful HLE semantics for Unity/Boehm titles | kernel/thread HLE | P3 |
| Hyper5 | real pthread stack-range reporting | **DEFER/AUDIT** | Prevents conservative GC scanning bad ranges | pthread HLE | P3 |
| Hyper5 | NID derivation for `sceKernelDlsym` | **AUDIT/REIMPLEMENT when required** | Can resolve game/engine-specific exports | dynamic loader | P3 |
| Sav-i/ps5-stuff | SharpEmu-derived video-loop branch | **DEFER** | No stronger unique implementation than SharpEmu main found | — | — |
| Fractal-Echo/PS5-Transformed | SharpEmu-derived branch | **DEFER** | Same reason | — | — |
| MagnusPS5 | iOS/iPad public release | **DEFER** | No meaningful current Windows/Radeon donor value | — | — |
| “PS5 emulator 2026” marketing/download repos | broad compatibility/60-FPS claims | **REJECT** | No credible source/history supporting claims | — | — |

---

## Immediate work queue

### P0: prove correctness

- [ ] Add Demon's Souls AGC packet/submission census.
- [ ] Add shader opcode/dispatcher-fallback census from the real shader corpus.
- [ ] Verify WRITE_DATA destination forms.
- [ ] Verify queue/ring/doorbell submission coverage.
- [ ] Verify NGG `v5` and inline vertex fetch behavior.
- [ ] Verify DCC/CMASK/HTILE state and descriptor handling.
- [ ] Add memory-growth telemetry and rejected-work resource-pool counters.
- [ ] Establish reproducible gameplay benchmark capture.

### P1: highest-confidence performance work

- [ ] Rebase/port Almo async pipeline infrastructure in small commits.
- [ ] Add blocking correctness mode for first-use pipelines; do not depend on silently skipped draws.
- [ ] Port synchronization/fence batching improvements that still apply after current upstream changes.
- [ ] Build adaptive readback + hot-buffer shadow policy.
- [ ] Audit aligned dword shader lowering inspired by SharpEmu.
- [ ] Implement log dedup/counters in Release.

### P2: steady-state architecture

- [ ] Persistent Kyty IR/SPIR-V cache.
- [ ] Descriptor-set-layout and pipeline-layout caches.
- [ ] Precise synchronization2 resource-state tracker.
- [ ] Allocation-free warm draw path.
- [ ] Pipeline-key cardinality report and selective extra dynamic state.

### P3: conditional optimizations

- [ ] FSR/internal-resolution scaling only if GPU-bound.
- [ ] Async compute/transfer only if GPU traces show useful overlap.
- [ ] Additional HLE/package work as required for compatibility.

---

## Rule for importing donor code

Every donor-derived code change should include in its commit message:

1. source repository URL;
2. source commit SHA;
3. whether code was cherry-picked, adapted, or independently reimplemented;
4. author attribution where required;
5. why it applies to current Kyty rather than an older architecture;
6. benchmark/correctness evidence.

Do not merge a donor commit solely because its message says `perf`. Performance changes remain experimental until the fixed Demon's Souls benchmark and the normal Kyty test suite pass.