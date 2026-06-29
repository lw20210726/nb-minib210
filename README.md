# nb-minib210

一个 **B210 仿制板**（NB-miniB210）的配套工程。目标是为这块仿制板提供固件 / FPGA / 主机侧支持。

## 工程原则

- **结构对齐 UHD**：本工程的目录结构刻意模仿 Ettus 官方 [UHD](https://github.com/EttusResearch/uhd) 工程，但**只保留本板涉及的部分**
- **最小改动**：从 UHD 拷贝过来的代码尽量保持原样，仅在仿制板与官方 B210 有差异的地方做针对性修改，便于日后跟官方上游对比 / 合并。

> 注意：本工程**不是** UHD 的替代品。它是 UHD 的一个子集 + 针对仿制板的改动。

## 目录结构

### 项目内

```
nb-minib210/
├── firmware/
│   └── fx3/                  # Cypress FX3 USB3 PHY 固件（拷贝自 UHD firmware/fx3）
│       ├── README.md         # 官方 FX3 固件构建说明
│       ├── b200/
│       │   ├── firmware/      # 主固件源码（usrp_b200_fw.hex）
│       │   ├── bootloader/    # bootloader 源码（usrp_b200_bl.img）
│       │   ├── common/        # 固件与 bootloader 共用代码
│       │   └── fx3_mem_map.patch  # 对 Cypress SDK 链接脚本/内存布局的补丁
│       └── gpif2_designer/    # GPIF II Designer 工程（FX3↔FPGA 并行接口时序配置）
├── fpga/                     # FPGA 工程（LibreSDRB210 适配 miniB210，Vivado 2024.1）
│   └── README.md             # 适配改动说明（时钟/AD9361 CMOS/约束/验收）
└── testkit/                  # 板级验收测试套件（数字稳定性 + 射频数据完整性）
    └── README.md             # 测试前置条件、安全须知、执行与判读
```

### 辅助工具链，参考项目

官方uhd参考，fx3sdk之类工具链，外部依赖放置在与nb-minib210同级目录。

## 当前状态

- [x] `firmware/fx3`：已从 UHD 对应目录拷贝原始内容，作为后续修改的基线。
- [x] `fpga`：基于 LibreSDRB210 适配 miniB210（时钟引脚、AD9361 CMOS 接口、约束收尾），
  已通过 `uhd_usrp_probe` 与 benchmark/稳定性验收。详见 [`fpga/README.md`](fpga/README.md)。
- [x] `testkit`：板级验收测试套件，方便群友自测自己的板。详见 [`testkit/README.md`](testkit/README.md)。
- [ ] 针对仿制板的固件改动（进行中 / 待开始）。
