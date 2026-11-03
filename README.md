# FPGA 双目视觉与低照度增强工程

2026-11-04 工程归档，包含 Verilog RTL、Vivado 工程与 IP、仿真、构建和下载脚本，以及已有位流、标定数据和验证记录。

## 硬件与工具

- FPGA：达芬奇 A7，Xilinx Artix-7 `XC7A35TFGG484-2`。
- 摄像头：两路 OV5640。
- 显示：800×480 LCD；另保留历史 HDMI 工程。
- 当前主线使用 Vivado 2019.1；部分历史 `.xpr` 保存于其他 Vivado 版本，打开时需检查版本与路径。
- 分析与仿真调度脚本使用 Python，部分图像分析脚本需要额外安装其导入的库。

## 从哪里开始

当前主线位于 [`stereo_lowlight/`](stereo_lowlight/)。最新状态先看 [`STATUS.md`](stereo_lowlight/STATUS.md)，算法与早期融合版本说明见其 [`README.md`](stereo_lowlight/README.md)。

本归档最新记录为 **2026-11-03 的指定靶标跟随测距版本**：

- 源码覆盖：[`variants/target_follow_20261103/`](stereo_lowlight/variants/target_follow_20261103/)。
- 已有构建：[`build/target_follow_20261103/`](stereo_lowlight/build/target_follow_20261103/)。
- 使用与验证边界：[`TARGET_FOLLOW.md`](stereo_lowlight/TARGET_FOLLOW.md)。
- 靶标打印文件：[`stereo_tracking_target_A4.pdf`](stereo_lowlight/output/pdf/stereo_tracking_target_A4.pdf)。
- 源码与产物哈希、既有测试结果：[`verified_sources.json`](stereo_lowlight/build/target_follow_20261103/verified_sources.json)。

该版本在模式 7 识别 ID7 标记，使显示框和测距区域随靶标移动，并加入有限范围的自动行补偿。归档记录包含 10 项通过的仿真与布局布线结果；静止显示已有用户确认，**动态跟随和全量程测距精度尚未完成实物验收**。详细结果与限制以各版本的原始记录为准。

## 目录

| 目录 | 内容 |
| --- | --- |
| `stereo_lowlight/rtl/` | 基础处理链与生产 RTL |
| `stereo_lowlight/variants/` | 亮度、标定、正面测距和靶标跟随等独立版本 |
| `stereo_lowlight/ip/` | FIFO、时钟、DDR3 MIG 等 IP 依赖 |
| `stereo_lowlight/constraints/` | 管脚与时钟约束 |
| `stereo_lowlight/sim/` | 基础仿真；独立版本另有自己的仿真目录 |
| `stereo_lowlight/tools/` | 构建、仿真、下载、采集与分析脚本 |
| `stereo_lowlight/build/` | 原归档保留的位流、检查点、报告与采集证据 |
| `stereo_lowlight/baseline/`、`checkpoints/` | 历史恢复版本及记录 |
| `stereo_lowlight/calibration/` | 标定参考、原始采集与拟合记录 |
| `Verilog/` | 原始双目 LCD、LCD 算法移植及 HDMI Vivado 工程 |
| `camera_capture_off/` | 摄像头采集关闭测试工程 |
| `clock_seg/` | 数码管时钟工程 |
| `tools/` | 历史工程构建与下载脚本、FIFO 测试及参考资料 |

## 下载与构建

通过仓库页面 **Code → Download ZIP** 下载整个工程，或使用 Git 克隆。本归档保留原有 IP 文件和构建资料，无需 Git LFS。

推荐用当前主线的 Tcl 脚本重建。先进入 `stereo_lowlight`，在 PowerShell 中执行（按本机安装位置调整 Vivado 路径）：

```powershell
New-Item -ItemType Directory -Force build | Out-Null
& 'C:\Xilinx\Vivado\2019.1\bin\vivado.bat' -mode batch `
  -source tools/build_target_follow.tcl `
  -log build/target_follow_build.log `
  -journal build/target_follow_build.jou
```

该脚本从自身位置定位源码与 IP，产物写入 `build/target_follow_20261103/`。重建会更新该目录；需要保留归档证据时，请先复制整个工程到独立目录。

只在本轮构建最终输出 `BUILD_OK` 且时序、DRC 检查符合要求后使用新位流。原归档中的 `.bit` 对应各自记录的历史构建，不代表任意修改后源码的编译结果。

跟随版本的专项仿真入口：

```powershell
python tools/test_target_follow.py
```

脚本默认使用 `C:/Xilinx/Vivado/2019.1/bin`，其他安装位置需调整脚本中的工具路径。历史 `.xpr` 和部分辅助脚本可能保留原电脑绝对路径，移机后需按实际环境调整。

## 使用资料

- [视频融合功能](stereo_lowlight/VIDEO_FUSION.md)
- [匹配与测距验证](stereo_lowlight/ROBUST_MATCH_VERIFICATION.md)
- [行对齐验证](stereo_lowlight/ROW_ALIGNMENT_VERIFICATION.md)
- [正面测距采集记录](stereo_lowlight/calibration/frontal_20261103/PLAN.md)
- [靶标跟随操作与验证](stereo_lowlight/TARGET_FOLLOW.md)

本次发布保留原工程文件内容及已有版权声明，新增首页说明和 Git 配置。第三方 IP 与参考资料的使用遵循其原有条款。
