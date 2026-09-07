# Local Testing (Windows, this PC)

Companion to `PHASE1_CORRECTNESS_PLAN.md`. This file records the minimal
Windows build/test baseline. Donor-repo results are not ours; only results
measured here count.

## Toolchain status (measured 2026-09-07)

| Component | Version / status |
|---|---|
| `clang-cl` | `clang version 22.1.3`, target `x86_64-pc-windows-msvc`, `InstalledDir: ...\VC\Tools\Llvm\x64\bin` |
| Bundled CMake | `cmake version 4.3.1-msvc1` |
| Bundled Ninja | `1.13.2` |
| `glslangValidator` (VulkanSDK 1.4.357.0) | Glslang `11:16.4.0`, SPIR-V `0x00010600 Rev 1` |
| Qt 6 (`C:/Qt/6.11.0/msvc2022_64`) | NOT found; `C:\Qt` absent. Launcher build blocked. Tests use `KYTY_BUILD_LAUNCHER=OFF`. |
| Submodules (`3rdparty/*`) | Pinned 2026-09-07: `git submodule sync --recursive` + `git submodule update --init --recursive --checkout` (no `--remote`). `git submodule status` shows no leading `+`/`-`; no gitlink changes in `git status`. |
| `_Build/` directory | `_Build/win-tests` configured 2026-09-07 (launcher OFF; see results log). `kyty_tests` baseline built and ctest-run; post-2db19f7 `shader_recompiler_compute_tests` rebuilt and tested where applicable. `kyty_emulator.exe` not built (not in `kyty_tests` target). |
| Checkout | `phase1/demons-souls-playable` at `38c5c3f` (local commit; donor Senaxx `2db19f7` preserved as author; ahead of `origin/main`) |

## Minimal configure/build/test (launcher OFF)

Run from an x64 Native Tools prompt (or equivalent env with `clang-cl`,
bundled CMake/Ninja on `PATH`):

```powershell
git submodule update --init --recursive
cmake -S . -B _Build/win-tests -G Ninja `
  -DCMAKE_BUILD_TYPE=Release `
  -DCMAKE_C_COMPILER=clang-cl -DCMAKE_CXX_COMPILER=clang-cl `
  -DKYTY_BUILD_LAUNCHER=OFF `
  "-DglslangValidator_EXECUTABLE=C:/VulkanSDK/1.4.357.0/Bin/glslangValidator.exe"
cmake --build _Build/win-tests --target kyty_tests
ctest --test-dir _Build/win-tests --output-on-failure
```

Record here: exact `clang-cl --version`, `cmake --version`,
`glslangValidator --version`, configure SHA, build target, and full
`ctest` output summary.

## Focused gate for Senaxx 2db19f7

```powershell
ctest --test-dir _Build/win-tests -R "shader_recompiler_compute|shader_recompiler_alignbyte|command_scheduler_timeline|stream_buffer_ring|gpu_command_lane|pm4_context_state" --output-on-failure
```

Plus new `ShaderGuestLaneTests` cases from the port (wave32/wave64,
multidimensional and multiple-wave workgroups, partial final wave, two
workgroups, masked prefix counts, disabled thread-ID inputs, MBCNT
control). Record pass/fail counts per test name.

## Full regression gate (as available)

`ctest --test-dir _Build/win-tests --output-on-failure` — record total
passed/failed. If a Vulkan-dependent test cannot run headless, record the
exact failure/skipped reason; do not claim it passed.

## Test-input policy

- `DS_DUMP_ROOT`, if set, is opaque local test input only. Never list,
  copy, or commit its contents. Never copy game data into Git.
- Game smoke benchmark uses only the owner's existing directly-launchable dump as opaque local input.
- Never search for or download keys, firmware, proprietary SDKs, licenses,
  secrets, or DRM/circumvention material. No game content in Git.

## Results log

| Date | Base SHA | Change | Tests | Result |
|---|---|---|---|---|
| 2026-09-07 | `8c083d49` | docs-only pass (no code) | n/a | n/a — superseded by configure below |
| 2026-09-07 | `8c083d49` | configure `_Build/win-tests` (launcher OFF, clang-cl 22.1.3, cmake 4.3.1, ninja 1.13.2, glslang 16.4.0) | configure | SUCCESS: `Configuring done (36.5s)`, build files written; FFMPEG prebuilts fetched 100%; nested `dependencies/zycore` checked out |
| 2026-09-07 | `8c083d49` (+docs worktree) | `cmake --build _Build/win-tests --target kyty_tests --parallel` | build | SUCCESS: all `kyty_tests` executables linked (e.g. `shader_recompiler_compute_tests.exe`). `kyty_emulator.exe` not built (not in `kyty_tests` target). |
| 2026-09-07 | `8c083d49` (+docs worktree) | `ctest --test-dir _Build/win-tests --output-on-failure` (36 tests) | full baseline | 25 passed / 11 failed (69%). Tests 1-4 Not Run (`kyty_emulator.exe` absent — build scope, not code). Tests 19, 28-30, 34-36 fail with identical host-GPU error: `image format does not support required usage: format=129 type=1 usage=0x23 ... in image.cpp:693`. Compute-focused gates all pass: alignbyte, virtual_memory, red_zone, scheduler_timeline, stream_buffer_ring, gpu_command_lane, pm4_context_state, gpu_tiler, depth_readback, meta_clear, buffer_gc. |
| 2026-09-07 | `38c5c3f` (commits `8c083d49` + donor senaxx `2db19f7`, 88+/2-, 5 files) | `cmake --build _Build/win-tests --target shader_recompiler_compute_tests` | build | SUCCESS: all `shader_recompiler_compute_tests.exe` linked (build truly succeeded; note: the `FORMAT_EXIT=0` capture on this row used a broken `%ERRORLEVEL%` pattern — parent's VS-LLVM dry-run later found real violations in the then-new image.cpp hunk, fixed via `clang-format -i`, re-verified FORMAT-CLEAN with `&&/||` capture). |
| 2026-09-07 | `38c5c3f` | `_Build/win-tests/shader_recompiler_compute_tests.exe --guest-lane-id-only` | focused guest-lane | 8/8 ok: `VectorMbcntUsesThreadMask`, `ComputeGuestLaneWave64Group16x4x2`, `Wave64Group64x1x1`, `Wave64Group8x8x1`, `Wave64Group96x1x1` (partial final wave), `Wave32Group8x8x1`, `Wave64Group64x1x1NoThreadIdInputs`, `Wave64Group16x4x2MaskedPrefix`. GUEST_EXIT=0. |
| 2026-09-07 | `38c5c3f` | `ctest --test-dir _Build/win-tests` (36 tests) | full regression | 25 passed / 11 failed (69%) — identical to baseline. Tests 1-4 Not Run (no `kyty_emulator.exe`). Tests 19, 28-30, 34-36 fail with same pre-existing `image.cpp:693 format=129` host-GPU error. No new failures. Focused ctest gate 5/6 pass (alignbyte, scheduler_timeline, stream_buffer_ring, gpu_command_lane, pm4_context_state); only `shader_recompiler_compute` fails at same pre-existing image-format abort after its host/gpu ok lines. |
| 2026-09-07 | `6ce809a` (`38c5c3f` + donor almo `953b1ce` port + format-only fixup; logic identical to donor) | `cmake --build _Build/win-tests --target kyty_tests` + `clang-format --dry-run --Werror` (6 files) | build+format | SUCCESS: BUILD-OK (proper &&/|| capture); FORMAT-CLEAN on image.cpp after `clang-format -i` (whitespace-only reflow, verified by diff). |
| 2026-09-07 | `6ce809a` | `shader_recompiler_compute_tests.exe --guest-lane-id-only` | focused guest-lane | 8/8 ok (same set as `38c5c3f`). GUEST_EXIT=0. |
| 2026-09-07 | `6ce809a` | `ctest --test-dir _Build/win-tests` (36 tests) | full regression | 29 passed / 7 failed (81%) — substantive set identical to baseline: the SAME 7 image failures (19, 28-30, 34-36, format=129 depth/MSAA signatures, now at image.cpp:702). Tests 1-4 pass purely on build scope (`kyty_emulator.exe` now built) — NOT attributed to the fix. No new failures; reconfirmed after the format-only fixup. |

## Authoritative clean baseline (parent run `20260907-020322`, single instance)

Post-`6ce809a`, 480x270 Immediate/Performance, validations/dumps off, playgo-hack,
30 s timeout. No overlapping emulator instances. This run SUPERSEDES the
contaminated utilization readings from `015819` (late) and `015849` (all) as
performance evidence; those runs are preserved below as history with caveats.

| Field | Value (measured) |
|---|---|
| lifetime / exit | 31.8 s, exit reason `timeout` — no crash |
| stdout / stderr | clean init + one wave64 compute warning; stderr empty |
| screenshots (t2/t5/t10/t15/t25) | LANGUAGE SELECT screen in all five, stable/static; warm run reaches menu by t2 (parent visually verified) |
| GPU 3D engines (clean) | 1.0, 2.1, 7.8, 3.8 early, then ~35.0, 35.9, 32.4, 35.5, 35.0, 35.2, 28.1, 35.2 → summarize as ~32-36% sustained after startup; NOT a frame-rate metric |
| working set MB (clean) | 1421.8, 3680.9, 3922.1, 4596.4, 4809.6, 4934.8, 5141.3, 5188.7, 5213.4, 5245.1, 5250.5, 5606.5 → rising RSS is a WATCH item; do NOT call it a leak from one 30 s menu run |
| frame rate | no FPS measurement yet |

## Authoritative visual milestone (parent run `20260907-015819`, source `7a0bb9e` + format-dirty worktree)

Parent-cropped/inspected screenshots (Kyty Demon's Souls window), same 480x270
Immediate/Performance config:

- t2/t5: Bluepoint logo rendered visibly/correctly.
- t10: intro/logo sequence still visible.
- t15: clearly rendered DEMON'S SOULS LANGUAGE SELECT screen — language
  list/highlight plus bottom-right confirm prompt.
- Lifetime ~63.2 s to harness timeout; old format-141 abort gone.

Milestone: FIRST INTERACTIVE MENU reached (not black output). No emulator process remains.
Contamination caveat: a second benchmark instance (our run-3 harness below, launched
~01:58:49) overlapped this run's tail. Screenshots through 15 s predate the overlap
→ clean/authoritative. Utilization samples after ~30 s are CONTAMINATED (two game
instances sharing CPU/GPU) and must NOT be used for performance conclusions.

## Beyond LANGUAGE SELECT (harness input schedule READY, not yet run)

Safe keystroke (verified in source, no --keymap needed): with no custom keymap the
emulator uses its built-in default where SDL **j → DualSense Cross**
(`hostInput.cpp` `DefaultKeyboardButton`; launcher default `Cross=J` matches).
So the exact confirm keystroke for the highlighted entry is lowercase **j**
(SendKeys `"j"` = plain press+release; modifiers are ignored by the switch).

Harness support (implemented, default OFF): `-InputSchedule 'sec:key,...'`
(e.g. `'25:j'`) focuses ONLY the spawned emulator window by PID
(`MainWindowHandle` + `SetForegroundWindow`; skips + records if none yet) and
sends each key once, recording fired/failed entries in `meta.json`. CPU%
(delta of `TotalProcessorTime` ÷ wall ÷ logical cores) and thread count now
sample alongside working set + GPU engines in `samples.csv`.

Run-4 recipe (parent to launch): single instance, same 480x270 config,
`-TimeoutSec 90 -InputSchedule '25:j'` (confirm after menu is stable; menu is up
by t2 warm), shots covering pre/post (default 2/5/10/15 + add 27/30). Checkpoints:
pre-shot template state, fired entry in meta, post-shots for the next screen,
stdout markers, stderr-empty check, lifetime/exit. No game-file writes, no
hardcoded paths/keys in tracked files.

## Third game benchmark (measured run 3, `20260907-015849` — OVERLAPPING second instance)

Same config as runs 1-2 (480x270 Immediate/Performance, validations/dumps off,
playgo-hack on) on commit `6ce809a` (port + format fixup, logic identical),
via `scripts/Run-DsBenchmark.ps1` (60 s timeout, shots 2/5/10/15). Owner's app0
opaque input; path used at runtime only, never in tracked files. THIS RUN OVERLAPPED
the authoritative run above (launched ~01:58:49 while `015819` was active until
~01:59:22), so: survival/stdout/stderr/per-process-RSS STAND (with contention
caveat); screenshots and system-wide GPU samples are NON-authoritative
(superseded by the authoritative set above; the pixel-static finding below
describes the contaminated desktop capture, not game state).

| Field | Value (measured) |
|---|---|
| lifetime / exit | 61.5 s, exit reason `timeout` (harness kill; exit code n/a) — old format-141 abort GONE |
| stdout | full init through Graphics, `version = 7`, ATRAC9 decoder, one `wave64 compute shader` warning; no EXIT/abort lines |
| stderr | empty |
| screenshots (2/5/10/15 s) | all 4 captured but NON-authoritative (overlap window; see caveat above — superseded by authoritative set) |
| RSS (own process) | 1.38 GB (1 s) → 5.67 GB (59.8 s), still climbing at kill — unbounded-growth WATCH item under contention, no conclusion |
| GPU 3D engines | NON-authoritative (system-wide counter shared with the overlapping instance) |
| fatal errors | NONE in 60 s — no format-141, no new abort |
| visual milestone | 60 s survival with no abort (valid); screen/GPU readings non-authoritative per overlap caveat |

Harness limitation (honest): `Get-Counter` latency made effective cadence ~3-12 s,
not ~1 Hz; no CPU/thread sampling yet. Fix before run 4.

## Second game benchmark (measured run 2, 2026-09-07 — OUR result, authoritative)

Same commit `38c5c3f` and settings as run 1 (480x270 Immediate/Performance,
validations/dumps off, playgo-hack on; owner's app0 opaque input). Warm run.

| Field | Value (measured) |
|---|---|
| lifetime | 6.67 s, exit code 321 (vs ~19 s cold run 1 to the same blocker) |
| shaders compiled | 93 before abort (same count as run 1) |
| screenshots (2 s, 5 s) | Kyty Demon's Souls window open but render area entirely black: no logo/UI/scene/partial visible frame |
| fatal error | exact repeat: `image format does not support required usage: format=141 type=1 usage=0xf flags=0x188 samples=1` at `src/graphics/host_gpu/renderer/image/image.cpp:693` (analysis + ranked fix proposal, NOT implemented: `IMAGE_FORMAT141_ANALYSIS.md`) |
| RSS | rose to ~3.93 GB by ~5.4 s |
| process CPU | ~1200-1350% psutil (≈12-13 logical CPUs) during bring-up; ~58-59 threads |
| visual milestone | window created / game recognized → black output → image-capability abort before first visible frame |

## First game benchmark (measured run 1, 2026-09-07 — OUR result)

Run by parent orchestrator on commit `38c5c3f` using the owner's existing
directly-launchable app0 dump as opaque local input. No keys/firmware/proprietary
SDK/circumvention material. No game content in Git. Screenshots were not captured
for this run; repeat via `scripts/Run-DsBenchmark.ps1` (screenshot pipeline READY).

| Field | Value (measured) |
|---|---|
| commit | `38c5c3f` |
| build/config | `kyty_emulator` @ `38c5c3f`; shader-optimization Performance; validations/debug dumps off; playgo-hack on |
| duration | ~19 s to blocker exit |
| screen resolution | 480x270 |
| present mode | Immediate |
| validation flags | validations off, debug dumps off |
| startup milestone | owner's app0 launched directly; 93 shaders compiled |
| max/last frame observed | none reported (exited on blocker; no frame evidence claimed) |
| frame-rate or frame-time evidence | none available (no invented FPS) |
| CPU/GPU utilization | not sampled this run (harness samples WorkingSet + GPU 3D engines at ~1 Hz going forward) |
| fatal/Vulkan validation/resource errors | OUR game-run blocker, distinct from format=129 ctest failures: `image.cpp:693`, `image format does not support required usage: format=141 type=1 usage=0xf flags=0x188 samples=1` |
| visual state | not captured (no screenshots this run) |
| exit reason | exited after ~19 s on the format=141 blocker; stderr empty |

## Benchmark harness (local infrastructure, not a perf optimization)

- `scripts/Run-DsBenchmark.ps1` — game root from `-GameRoot` / `$env:DS_GAME_ROOT` (never hardcoded); configurable width/height/present-mode/timeout; screenshots at configurable seconds (default 2,5,10,15) via System.Drawing (no OCR); ~1 Hz WorkingSet + GPU-engine samples; per-run `_Build/benchmarks/<stamp>/` folder with command, stdout/stderr, meta (timestamps, exit reason, lifetime), samples, screenshots. Terminates only the spawned emulator. All outputs under `_Build/` (ignored).
