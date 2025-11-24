# HARDVINO Documentation Index

Complete documentation for the HARDVINO Intel Acceleration Stack.

---

## Getting Started

| Document | Description |
|----------|-------------|
| [../README.md](../README.md) | Main project README with quick start |
| [DSMIL_INTEGRATION.md](DSMIL_INTEGRATION.md) | Integration guide for DSMIL framework |

---

## Architecture & Configuration

| Document | Description |
|----------|-------------|
| [MASTER_PROMPT.md](MASTER_PROMPT.md) | AI system prompt for Intel stack management |
| [KERNEL_CONFIG.md](KERNEL_CONFIG.md) | Kernel configuration requirements |
| [SUBMODULE_INTEGRATION.md](SUBMODULE_INTEGRATION.md) | Submodule organization and integration |
| [ANALYSIS_README.md](ANALYSIS_README.md) | Build system analysis |
| [INITIALIZATION_STATUS.md](INITIALIZATION_STATUS.md) | Initialization and status information |

---

## AVX2-First Optimization

HARDVINO uses an AVX2-first workflow optimized for Meteor Lake processors.

| Document | Description |
|----------|-------------|
| [avx2/FIRST_WORKFLOW.md](avx2/FIRST_WORKFLOW.md) | AVX2-first architecture guide |
| [avx2/OPTIMIZATION_QUICK_GUIDE.md](avx2/OPTIMIZATION_QUICK_GUIDE.md) | Quick optimization reference |
| [avx2/CODE_REFERENCE.md](avx2/CODE_REFERENCE.md) | AVX2 code reference |
| [avx2/CONFIGURATION_SUMMARY.md](avx2/CONFIGURATION_SUMMARY.md) | Configuration summary |
| [avx2/WORKFLOW_ANALYSIS.md](avx2/WORKFLOW_ANALYSIS.md) | Workflow analysis |

---

## External Resources

- [Intel OpenVINO Documentation](https://docs.openvino.ai/)
- [Intel NPU Acceleration Library](https://intel.github.io/intel-npu-acceleration-library/)
- [oneAPI Documentation](https://www.intel.com/content/www/us/en/developer/tools/oneapi/overview.html)
- [DSMIL System](https://github.com/SWORDIntel/DSMILSystem)
- [PLATFORM](https://github.com/SWORDIntel/PLATFORM)

---

## Component Reference

See [../intel_stack.manifest.yml](../intel_stack.manifest.yml) for the complete component manifest with 35 submodules.

### Build Stages

| Stage | Components | Documentation |
|-------|------------|---------------|
| 1 | Toolchains (xetla) | oneAPI templates |
| 2 | oneAPI (TBB, DNN, MKL, DAL, CCL, DPL) | Threading, math, ML |
| 3 | **HARDVINO Core** | OpenVINO replacement |
| 4 | Runtimes (GPU, NPU, Level Zero) | Hardware backends |
| 5 | Media (VAAPI drivers) | Video encode/decode |
| 6 | QAT (crypto, compression) | Hardware offload |
| 7 | ML Frameworks (PyTorch, TF, HF) | Framework extensions |
| 8 | Tools (Open3D, XeSS, ROS2) | Utilities |
| 9 | **PLATFORM** | AI platform |

---

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `../install.sh` | Single entrypoint for all builds |
| `../scripts/intel_env.sh` | Meteor Lake compiler flags |
| `../scripts/build_order.sh` | 9-stage dependency resolver |
| `../scripts/integrate.sh` | Integration helper |

---

## Hardware Reference

### Target Platform

- **CPU**: Intel Core Ultra 7 165H (Meteor Lake)
- **NPU**: VPU 3720 (Intel AI Boost)
- **iGPU**: Xe-LPG (integrated graphics)
- **ISA**: AVX2, AVX-VNNI (no AVX-512)

### MCM-1000 DSMIL NPU Abstraction

The MCM-1000 is a DSMIL driver abstraction layer for the Intel Meteor Lake NPU:

- **Virtual Devices**: 32 (IDs 31-62)
- **Tokens per Device**: 3
- **Total Registers**: 96
- **Driver**: `dsmil_mcm` / `intel_vpu`
- **Device**: `/dev/accel/accel0`
