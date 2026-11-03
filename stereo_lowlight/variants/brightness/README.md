# 双目原始视频亮度排查版

此变体基于用户已确认双目实时正常的诊断显示路径，独立构建，不覆盖
`build/diagnostic/diagnostic.bit` 和融合候选版 `build/fusion/fusion.bit`。

2026-10-24 20:27 已下载，DONE=1。用户随后确认“亮度改善，两路都实时”。
时序 WNS=0.994 ns、WHS=0.049 ns；两路采集各 400×480 并持续更新。
这仅确认原始双目显示及本次亮度改善，不代表增强/测距功能完成。

- LCD 默认显示左右目原始 RGB565；KEY0 切换原始画面 / 独立彩条。
- 使用已确认 800×480 LCD 的固定 25 MHz BUFG 时钟。
- 摄像头上电等待 20 ms，软件复位后等待 2 ms。
- 明确写入 0x3503=0，启用自动曝光和自动增益。
- 自动曝光进入稳定区目标从 0x28～0x30 提高至 0x50～0x58；相应调整退出区和快速区。
- 不添加数字增亮，也不接入增强/视差流水线。先验证相机原始曝光。
- 每约 100 ms 读回 0x3503、0x3500～3502、0x350A/B、0x56A1、0x3A0F。
  ILA 高 128 位保存两路读回；低 256 位保持原诊断布局。调试数据跨域采样，
  多次稳定值才用于判断，不作为帧级同步数据。

依据：[OmniVision OV5640 数据手册](https://files.waveshare.com/upload/d/da/OV5640_DataSheet.pdf)，
4.5 节说明自动曝光阈值和 0x56A1 平均亮度；4.6 节说明自动/手动控制与曝光增益。
提高目标是针对用户当前偏暗现象的调参候选，不能替代实际图像验收。

在工程根目录执行 `tools/prepare_brightness.py` 生成变体源文件和构建脚本；
使用 `tools/build_brightness.tcl` 构建，时序通过才生成 bit。
`tools/capture_brightness.tcl` 加参数 `program` 可下载并采样；
`tools/decode_capture.py brightness` 解码两路曝光与亮度。默认不写 Flash。
