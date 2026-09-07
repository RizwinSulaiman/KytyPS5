# Format-141 abort analysis (OUR runs 1-2 @ `38c5c3f`; FIXED and benchmark-validated)

Status 2026-09-07: recommendation #1 (almo `953b1ce`) ported + format fixup,
committed as `6ce809a`, test gate 29/36 reconfirmed. Clean single-instance baseline
(parent run `020322`): 31.8 s, no crash, LANGUAGE SELECT stable, GPU ~32-36%,
RSS watch. Overlap-contaminated readings kept as history with caveats. Next: run 4
confirms the highlighted entry with `j` (Cross under built-in defaults). No push.

## Crash signature (OUR measurement)

- `image format does not support required usage: format=141 type=1 usage=0xf flags=0x188 samples=1`
- at `src/graphics/host_gpu/renderer/image/image.cpp:693`, inside `Image::Image`.
- Run 1 (cold): ~19 s, 93 shaders, stderr empty. Run 2 (warm): 6.67 s, exit 321,
  93 shaders, 2 s/5 s screenshots black window, RSS ~3.93 GB, CPU ~1200-1350%.
- Distinct from the pre-existing ctest failures (`format=129 ... usage=0x23 ... samples=2`).

## Signature mapping (headers used by this build)

- `format=141` = `VK_FORMAT_BC5_UNORM_BLOCK` (`3rdparty/Vulkan-Headers/.../vulkan_core.h:1927`).
  (`format=129` in the ctest failures = `VK_FORMAT_D24_UNORM_S8_UINT`, a different path.)
- `type=1` = `vk::ImageType::e2D`.
- `usage=0xf` = TRANSFER_SRC | TRANSFER_DST | SAMPLED | STORAGE.
- `flags=0x188` = MUTABLE_FORMAT | BLOCK_TEXEL_VIEW_COMPATIBLE | EXTENDED_USAGE
  (set by `ImageCreateFlags()` for non-depth block-compressed formats).
- The abort is the `vkGetPhysicalDeviceImageFormatProperties` pre-check failing:
  the RX 9070 XT driver reports this exact combo unsupported.

## Root cause (inherited upstream, verified via local `git show`)

- Upstream `8022501` ("renderer: enable storage for color images", nmzik, Sep 1,
  present in our HEAD and in all donor ancestries) removed the `eStorageImage`
  format-feature gate (plus the `SrgbStorageViewFormat` fallback branch) and made
  `eStorage` unconditional for `samples == 1` in `ImageUsageFlags()`.
- BC5 on AMD exposes sampled/transfer but not storage, so usage `0xf` fails the
  driver query while TRANSFER/SAMPLED-only would pass (inference from the query
  semantics + the sampled/transfer feature pattern already in the same function;
  BC textures are sampled universally — the STORAGE bit is the offending bit).
- Driver note (inference, labelled): donor Senaxx validates on RTX 5090 where the
  same query evidently passes; our RX 9070 XT rejects it. Capability queries are
  driver-dependent, so gating on the queried result is the portable fix.
- Safety note (read from current source): `descriptors.cpp` already handles
  `storage=false` images (`BindingType::Texture` + pixel-format view fallback), and
  transfer bits are untouched by any re-gate, so dropping STORAGE from usage does
  not break the descriptor path. Our `image.cpp` == `8c083d4` (empty diff): Phase 1
  did not touch this path.

## Donor overlap for this exact path

| Donor commit | Touches `ImageUsageFlags`/image.cpp usage? | Verdict |
|---|---|---|
| senaxx chain `c6b4156`, `0ebfb0d`, `390792b`, `d42de24`, `7be1416`, `89f2f34`, mip/slice/layer + buffer-store commits | No (`image.cpp` log on `senaxx/main` still tops at `8022501`; `c6b4156` = IR passes, `89f2f34` = textureCache layout) | No overlap, but none of them fixes this abort either |
| lordix `7c21b71` | No (touches textureCache/descriptors/tiler/depth targets; 97 files, too broad to cherry-pick) | Adjacent only; not a candidate for this abort |
| fxpw `cf88512` | No (shader image-table materialization only) | Not relevant to host image creation |
| almo `953b1ce` | YES — direct fix on this hunk (see below); not contained in senaxx/lordix/fxpw | Recommendation #1 |

## Ranked recommendations (proposed, NOT applied)

1. **Port almo `953b1ceccede502ec4b569e2702d7987393956ff`** ("fix(renderer): gate
   storage image usage by format support", Sep 4). Probes the exact create
   parameters (format+type+tiling+candidate-usage+flags, incl. sampleCounts) via
   `GetImageFormatProperties` and only then keeps `eStorage`. Strictly stronger
   than the pre-`8022501` feature-bit check. One function + one call site, all in
   `image.cpp`; zero file overlap with the Senaxx chain, lordix, or fxpw in this
   region. Expected: BC5 image creates as sampled+transfer, run advances past 93
   shaders. Validate with focused ctest + benchmark rerun. (Almo gameplay claims
   remain donor-only; only this hunk's logic is being evaluated.)
2. **Contingency only: restore the pre-`8022501` sRGB storage-view branch** (revert
   that hunk). Needed only if some shader path provably requires a storage write
   to this image after #1 lands. `SrgbStorageViewFormat` still exists
   (`imageView.h:58`, used by `descriptors.cpp:749`), so it applies cleanly — but
   do not apply speculatively.
3. **Next layer after #1 (not this abort): senaxx `89f2f34`** (depth overlap/layout
   coherence, `textureCache.cpp`). Donor claim: run advanced 641 → 941 shaders
   before a separate compute failure. Our run dies at 93 shaders on creation, so
   this is strictly later. Conflict note: lordix `7c21b71` also touches
   `textureCache.cpp` (upload/overlap hunks) — diff the two before considering.

## Review gate (APPROVED by parent; #1 implemented this turn)

Parent approved #1 ONLY. Implemented as exact donor port + format-only fixup (logic identical, verified by diff),
test gate passed, source commit made locally; no push. No #2 contingency, no 89f2f34.
