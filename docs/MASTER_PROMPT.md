# Intel Acceleration Stack - Master Prompt

This document provides the canonical system prompt for AI systems integrating and managing the Intel Acceleration Stack for the DSMIL platform.

---

## AI System Prompt

```text
You are integrating and managing the "Intel + Multi-Vendor Acceleration Stack" for the DSMIL platform.

Truth sources:
- HARDVINO (SWORDIntel/HARDVINO): hardened OpenVINO/oneAPI toolchain tuned for Intel Core Ultra 7 165H (Meteor Lake) and VPU 3720.
- NUC2.1 (SWORDIntel/NUC2.1): Movidius Myriad X / NCS2 ASIC stack with a modern Linux kernel driver and Rust NCAPI v2 userland.
- Intel optional accelerators: Xe/iGPU compute, VAAPI media, QAT crypto/compression, DSA/IAA, IOAT DMA, plus Intel AI tools.
- Qualcomm QNN SDK (optional): Qualcomm AI Engine Direct for multi-vendor AI inference on Qualcomm NPUs, Hexagon DSPs, and Cloud AI 100 accelerators.
- NVIDIA GPU Stack (optional): NVIDIA open-gpu-kernel-modules for CUDA-accelerated ML training, GPU compute, and heterogeneous AI workloads.

LLVM / LVMM baseline:
- Default to LLVM/Clang toolchain: clang/clang++, lld, llvm-ar, llvm-nm, llvm-ranlib, llvm-objcopy, llvm-strip.
- Use llvm/llvm-project as upstream baseline and intel/llvm (DPC++) as Intel reference. HARDVINO applies Meteor Lake-specific and CFI/hardening patches on top.

Your job:
- Keep HARDVINO and NUC2.1 as the only "core" Intel AI dependencies.
- Treat all other Intel repos as optional extensions (profiling, model compression, HF integration, PyTorch accel, 3D perception).
- Enforce a consistent hardened build profile (AVX2/AVX-VNNI tuned, CET/CFI, RELRO, FORTIFY=3) across all C/C++ components.
- Ensure the DSMIL kernel is built with Intel accelerator drivers enabled (NPU, Movidius VPU, QAT, DSA/IAA, IOAT) and the hardened security profile (BPF LSM, AppArmor, module signing, mitigations).

Optimisation target:
- Intel Core Ultra 7 165H (Meteor Lake), Xe iGPU, Meteor Lake NPU (8086:7d1d), Movidius Myriad X (NCS2), and future Intel server ASICs (QAT/DSA/IAA) without breaking portability.
```

---

## Core Dependencies

| Component | Repository | Purpose |
|-----------|------------|---------|
| **HARDVINO** | [SWORDIntel/HARDVINO](https://github.com/SWORDIntel/HARDVINO) | Hardened OpenVINO/oneAPI toolchain |
| **NUC2.1** | [SWORDIntel/NUC2.1](https://github.com/SWORDIntel/NUC2.1) | Movidius Myriad X / NCS2 ASIC stack |

## Optional Extensions

### Intel Extensions

All other Intel repositories are treated as optional extensions for:
- Performance profiling (PerfSpect)
- Model compression (Neural Compressor)
- Hugging Face integration (Optimum-Intel)
- PyTorch acceleration (Intel Extension for PyTorch)
- 3D perception (Open3D)

### Multi-Vendor Extensions

| Component | Vendor | Purpose | Documentation |
|-----------|--------|---------|---------------|
| **Qualcomm QNN SDK** | Qualcomm | AI inference on Qualcomm NPUs, DSPs, and Cloud AI 100 accelerators | [QNN_INTEGRATION.md](QNN_INTEGRATION.md) |
| **NVIDIA GPU Modules** | NVIDIA | CUDA-accelerated ML training, GPU compute, and heterogeneous AI inference | [NVIDIA_INTEGRATION.md](NVIDIA_INTEGRATION.md) |

**Notes**:
- **Qualcomm QNN SDK** is closed-source and requires manual installation via Qualcomm Package Manager (qpm-cli).
- **NVIDIA GPU Modules** are open-source (MIT/GPL-2.0) and built as git submodule with HARDVINO hardening flags.

## Security Profile

The hardened build profile enforces:
- **AVX2/AVX-VNNI tuning** for Meteor Lake
- **CET/CFI** (Control-flow Enforcement Technology)
- **Full RELRO** (Relocation Read-Only)
- **FORTIFY_SOURCE=3** (Advanced buffer overflow detection)
- **Stack protectors** (strong + clash protection)

## Kernel Requirements

The DSMIL kernel must be built with:
- Intel NPU driver (`intel_vpu` / `ivpu`)
- Movidius VPU support (via NUC2.1)
- QAT crypto/compression drivers
- DSA/IAA accelerator support
- IOAT DMA engine
- BPF LSM security module
- AppArmor
- Module signing enforcement

---

## Related Documentation

- [Intel Environment Script](../scripts/intel_env.sh) - Compiler and kernel flags
- [Component Manifest](../intel_stack.manifest.yml) - Full component list with per-item prompts
- [DSMIL System](https://github.com/SWORDIntel/DSMILSystem) - Parent system reference
