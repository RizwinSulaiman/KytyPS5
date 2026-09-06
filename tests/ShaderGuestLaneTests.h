// Synthetic ISA contracts for logical compute-wave identity. No guest code.
template <u32 WaveSize, u32 X, u32 Y, u32 Z, bool ThreadIds = true,
          u32 LowMask = UINT32_MAX, u32 HighMask = UINT32_MAX, u32 Seed = 0>
TestCase ComputeGuestLaneMbcnt() {
  using O = ShaderOpcode;
  static_assert(WaveSize == 32 || WaveSize == 64);
  std::vector<u32> code;
  AppendVMovLiteral(&code, 12, LowMask);
  AppendVop3(&code, 0x365, 10, Vgpr(12), InlineU32(Seed));
  AppendVMovLiteral(&code, 12, HighMask);
  AppendVop3(&code, 0x366, 10, Vgpr(12), Vgpr(10));
  if constexpr (ThreadIds) {
    AppendVMovU32(&code, 13, X);
    AppendVop3(&code, 0x143, 14, Vgpr(1), Vgpr(13), Vgpr(0));
    AppendVMovU32(&code, 13, X * Y);
    AppendVop3(&code, 0x143, 14, Vgpr(2), Vgpr(13), Vgpr(14));
  } else {
    static_assert(X * Y * Z == WaveSize && LowMask == UINT32_MAX &&
                  HighMask == UINT32_MAX && Seed == 0);
    code.push_back(EncodeVop1(0x01, 14, Vgpr(10)));
  }
  // Give each workgroup separate output; lane numbering must restart there.
  AppendVMovU32(&code, 13, X * Y * Z);
  AppendVop3(&code, 0x143, 14, 0, Vgpr(13), Vgpr(14));
  code.push_back(EncodeVop2(0x1a, 15, InlineU32(2), 14));
  AppendBufferStoreDword(&code, 10, 15);
  AppendEnd(&code);

  TestCase test;
  static const std::string name = "ComputeGuestLaneWave" + std::to_string(WaveSize) +
      "Group" + std::to_string(X) + "x" + std::to_string(Y) + "x" + std::to_string(Z) +
      (ThreadIds ? "" : "NoThreadIdInputs") + (Seed ? "MaskedPrefix" : "");
  test.name = name.c_str();
  test.code = std::move(code);
  test.initial.assign(2 * X * Y * Z, 0xcdf01234u);
  for (u32 i = 0; i < test.initial.size(); i++) {
    const auto lane = (i % (X * Y * Z)) % WaveSize;
    const auto lower = [](u32 bits) { return bits == 32 ? UINT32_MAX : (1u << bits) - 1u; };
    test.expected.push_back(Seed + std::popcount(LowMask & lower(std::min(lane, 32u))) +
        std::popcount(HighMask & lower(lane > 32 ? lane - 32 : 0)));
  }
  test.opcodes = {O::V_MOV_B32, O::V_MBCNT_LO_U32_B32, O::V_MBCNT_HI_U32_B32,
                  O::BUFFER_STORE_DWORD, O::S_ENDPGM};
  test.compute_info.threads_num[0] = X;
  test.compute_info.threads_num[1] = Y;
  test.compute_info.threads_num[2] = Z;
  test.compute_info.thread_ids_num = ThreadIds ? 3 : 0;
  test.compute_info.group_id[0] = true;
  test.compute_info.workgroup_register = 0;
  test.compute_info.wave_size = WaveSize;
  test.has_compute_info = true;
  test.dispatch_x = 2;
  test.required_spirv = {"BuiltIn LocalInvocationIndex"};
  test.forbidden_spirv = {"OpGroupNonUniformBallot"};
  return test;
}

std::vector<TestCase> MakeGuestLaneCases() {
  return {ComputeGuestLaneMbcnt<64, 16, 4, 2>(),
          ComputeGuestLaneMbcnt<64, 64, 1, 1>(),
          ComputeGuestLaneMbcnt<64, 8, 8, 1>(),
          ComputeGuestLaneMbcnt<64, 96, 1, 1>(),
          ComputeGuestLaneMbcnt<32, 8, 8, 1>(),
          ComputeGuestLaneMbcnt<64, 64, 1, 1, false>(),
          ComputeGuestLaneMbcnt<64, 16, 4, 2, true, 0x8100f00fu, 0xa0000011u, 3>()};
}
