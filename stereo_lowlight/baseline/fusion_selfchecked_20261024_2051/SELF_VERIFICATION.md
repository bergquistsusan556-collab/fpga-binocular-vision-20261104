# 融合版本自检记录（2026-10-24）

本轮已把用户确认改善亮度的摄像头配置合入双目增强与视差版本，并于 20:51 经 JTAG 下载。
当前默认增强双目画面；未写 Flash。代码和逻辑自检已完成，本轮板上运行观测通过。
**实物目标测距、几何标定、最终颜色与边缘画质验收尚未完成；用户明确安排实物标定稍后进行。**

## 实现与本轮修正

- 两路 OV5640 各采集 400×480 RGB565，经异步 FIFO/DDR3，以左右双目显示。
- 两路视频分别在 YCrCb 中处理亮度，因果 3×3 范围门限加权照明估计配合定点 gamma 增益，最大 4 倍。
  双目共享上一帧 64 桶亮度直方图 CDF，饱和重建颜色，保持色度；不是逐 RGB 通道独立均衡。
- 本轮限制 CDF 混合不降低局部增强亮度，补足相机复位等待，明确启用自动曝光/增益，提高曝光目标至 0x50～0x58。
- 原始亮度进入 Census 匹配，水平搜索 1～63 像素；纹理、边界、代价及唯一性筛选后生成视差。
- 整幅右目视场视差以 200×240 双缓冲存储，放大到 800×480 LCD；无效点为黑色。
  本轮压缩了缓存地址空间，清除无效点，彩条模式不再叠加距离横幅。
- 中心 41×41 ROI 主峰及相邻桶加权平均换算厘米，使用四舍五入；主深度不足有效匹配一半时拒绝读数。
- 基线约 32 mm 来自用户测量，焦距 346 像素仍是估计值，默认尺度 256/256，**未标定**。

## 自检结果

14 项仿真全部通过：`sim/test_summary.json`。完整日志在 `sim/tb_*_xsim.log`。

- `tb_sensor_brightness`：PASS；sensor: 251 init operations, reset delay, auto exposure target, repeated register readback
- `tb_lowlight`：PASS；lowlight bypass alignment, dark lift and highlight saturation
- `tb_lowlight_reference`：PASS；73728 independent enhanced RGB565 vectors, all colors, varied weights/history and blanking
- `tb_algorithms`：PASS；Census direction=0 independent cost/uniqueness reference, disparity 7: 468/528
- `tb_reverse`：PASS；Census direction=1 independent cost/uniqueness reference, disparity 7: 480/528
- `tb_features`：PASS；feature coordinates, blanking bubbles and binocular boundary isolation
- `tb_stereo_scene`：PASS；400x480 RGB stereo scene, disparities 4/12/22, accepted=131332/134232 correct=131332 center=92cm
- `tb_frames`：PASS；histogram normalization, ROI distance arithmetic, depth bank swap and invalid clearing
- `tb_depth_map`：PASS；whole 800x480 disparity display, two banks, every one of 768000 output cells, invalid overwrite and field boundaries
- `tb_roi_accuracy`：PASS；ROI arithmetic 0.5/0.75/1/1.5/2/3m, <=1cm numerical error, mixed-depth rejection and stale clearing
- `tb_fifo_pack`：PASS；FIFO partial-frame discard and 32-pixel packing
- `tb_frame_cdc`：PASS；asynchronous frame pulse synchronization and single-event generation
- `tb_pipeline`：PASS；integrated full-width video pipeline, every bypass RGB pixel/DE/coordinate aligned
- `tb_lcd_system`：PASS；complete LCD request + modeled FIFO latency + 3 full frames, raw RGB alignment, enhancement lift, color bars and frame metrics

合成纹理场景使用真实 RGB 输入，经窗口/Census/匹配处理后，考查区域接受 131332/134232 个候选，
所有接受项与该场景的预设视差一致。这是合成输入验证，不能当作真实物体的测距正确率。
0.5～3 米测试中的 ≤1 cm 只表示已知理想视差下的换算数值误差，不是实际测距精度。
LCD 测试中的 DDR 读口使用一拍延迟模型；没有仿真真实 DDR 芯片和摄像头电气行为。

布局布线后时序：`WNS=0.994 WHS=0.031`，TNS=0；无时钟寄存器端点=0，未约束内部端点=0。
资源：LUT 16976/20800（81.62%）；FF 16579/41600（39.85%）；BRAM 40.5/50（81.00%）；DSP 14/90（15.56%）。
DRC 无错误，仍有非专用摄像头时钟脚、RAM 异步控制、DSP 流水等告警；部分板级 I/O 无完整设备延迟模型，
因此不能声称所有外部电气时序、CDC 和长期可靠性均已认证。

## 上板观测

DONE=1；两路芯片 ID 都是 0x5640，LCD ID=0x4384，PCLK 各约 48 MHz，摄像头每帧各 192000 像素。
两路帧计数与图像校验值持续变化，输出每帧 384000 像素。
自动曝光/增益控制读回为 0，新曝光目标读回为 0x58。
亮度统计在增强输出、OSD 叠加之前计算，范围为 0～255：

| 采样 | 两路帧计数 | 输出像素 | 原始平均亮度 | 增强平均亮度 | 接受的匹配候选 | ROI 距离 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 90/89 | 384000 | 38.740 | 100.596 | 12874 | 无效 |
| 2 | 135/134 | 384000 | 40.332 | 106.465 | 10239 | 无效 |
| 3 | 179/178 | 384000 | 41.066 | 106.734 | 14267 | 无效 |

观测自动检查：PASS，见 `build/fusion/hardware_verification.json`。
这些候选数量说明匹配链路在产生结果，不证明真实视差正确；本轮当前场景中心 ROI 没有形成有效距离读数。
ILA 跨域诊断快照不是相机间同步帧交易；比较使用连续采样，不能据此推断严格同步曝光。

连续运行追加观测：12 次采样、首末相隔 56.9 秒，自动检查PASS。两路帧计数按约 26.67 帧/秒推进，每次采样 LCD 均输出 384000 像素，双目数据校验值与显示帧计数变化，未观察到停帧。这是间隔采样，不能排除采样间的短暂异常，也不是长期稳定性认证。记录在 `build/fusion/watch/decoded.json` 和 `hardware_verification.json`。

LCD 固定 25 MHz，1056×525 总时序约 45.09 Hz；摄像头约 26.67 帧/秒，显示重复最近帧，
不能把 LCD 刷新率称为摄像头采集帧率。

## 当前操作与后续验收

- KEY0：增强双目（默认）→整幅视差→彩条→原始双目→增强双目。
- KEY3：切换左右视差搜索方向。
- KEY1/KEY2：距离比例系数减/加 4/256。
- 未获得可靠 ROI 时显示横线，避免将散乱匹配显示为可信距离。

用户准备好后，需要固定镜头位置，验证双目共同视场与极线对齐，完成焦距/畸变/双目外参标定，
再用实际 0.5、1、1.5、2、3 米目标记录误差。当前没有实现完整镜头畸变校正、极线重映射、
相机硬件曝光同步或左右一致性校验，不能宣称已满足这些实物精度条件，运动物体尚未验证。
颜色修复及边缘观感仍需真实场景视觉验收，算术一致性不能替代图像质量评价。

当前文件：`build/fusion/fusion.bit`、`fusion.ltx`、`manifest.json`；构建日志
`build/fusion_exposure_verified_build.log`，下载日志 `build/fusion_exposure_program_capture.log`。
已确认双目原始画面和亮度改善的回退版本保存在 `baseline/confirmed_brightness_20261024/`。
