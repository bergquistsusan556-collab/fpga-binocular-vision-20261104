from pathlib import Path
import json,re
root=Path(__file__).resolve().parents[1]
out=root/'build/fusion'
tests=json.loads((root/'sim/test_summary.json').read_text())
hardware=json.loads((out/'hardware_verification.json').read_text())
data=json.loads((out/'decoded.json').read_text())
watch=json.loads((out/'watch/decoded.json').read_text())
watch_check=json.loads((out/'watch/hardware_verification.json').read_text())
watch_seconds=sum(((b['ticks_hi']-a['ticks_hi'])%65536)*65536/50_000_000
                  for a,b in zip(watch,watch[1:]))
watch_text=(f"连续运行追加观测：{len(watch)} 次采样、首末相隔 {watch_seconds:.1f} 秒，自动检查"
            f"{'PASS' if watch_check['passed'] else 'FAIL'}。两路帧计数按约 26.67 帧/秒推进，"
            "每次采样 LCD 均输出 384000 像素，双目数据校验值与显示帧计数变化，未观察到停帧。"
            "这是间隔采样，不能排除采样间的短暂异常，也不是长期稳定性认证。"
            "记录在 `build/fusion/watch/decoded.json` 和 `hardware_verification.json`。")
timing=(out/'timing_pass.txt').read_text().strip()
util=(out/'utilization.rpt').read_text()
def usage(label):
    m=re.search(r'\| '+re.escape(label)+r'\s*\|\s*([\d.]+)\s*\|\s*[\d.]+\s*\|\s*([\d.]+)\s*\|\s*([\d.]+)',util)
    return f'{m[1]}/{m[2]}（{m[3]}%）' if m else '见 utilization.rpt'
rows='\n'.join(f"| {i+1} | {d['frame1']}/{d['frame2']} | {d['display_pixels']} | {d['raw_mean']:.3f} | {d['enhanced_mean']:.3f} | {d['valid_matches']} | {'有效' if d['distance_valid'] else '无效'} |" for i,d in enumerate(data))
test_rows='\n'.join(f"- `{t['name']}`：{'PASS' if t['passed'] else 'FAIL'}；{t['result'].removeprefix('PASS ')}" for t in tests['tests'])
report=f'''# 融合版本自检记录（2026-10-24）

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

{len(tests['tests'])} 项仿真全部通过：`sim/test_summary.json`。完整日志在 `sim/tb_*_xsim.log`。

{test_rows}

合成纹理场景使用真实 RGB 输入，经窗口/Census/匹配处理后，考查区域接受 131332/134232 个候选，
所有接受项与该场景的预设视差一致。这是合成输入验证，不能当作真实物体的测距正确率。
0.5～3 米测试中的 ≤1 cm 只表示已知理想视差下的换算数值误差，不是实际测距精度。
LCD 测试中的 DDR 读口使用一拍延迟模型；没有仿真真实 DDR 芯片和摄像头电气行为。

布局布线后时序：`{timing}`，TNS=0；无时钟寄存器端点=0，未约束内部端点=0。
资源：LUT {usage('Slice LUTs')}；FF {usage('Slice Registers')}；BRAM {usage('Block RAM Tile')}；DSP {usage('DSPs')}。
DRC 无错误，仍有非专用摄像头时钟脚、RAM 异步控制、DSP 流水等告警；部分板级 I/O 无完整设备延迟模型，
因此不能声称所有外部电气时序、CDC 和长期可靠性均已认证。

## 上板观测

DONE=1；两路芯片 ID 都是 0x5640，LCD ID=0x4384，PCLK 各约 48 MHz，摄像头每帧各 192000 像素。
两路帧计数与图像校验值持续变化，输出每帧 384000 像素。
自动曝光/增益控制读回为 0，新曝光目标读回为 0x58。
亮度统计在增强输出、OSD 叠加之前计算，范围为 0～255：

| 采样 | 两路帧计数 | 输出像素 | 原始平均亮度 | 增强平均亮度 | 接受的匹配候选 | ROI 距离 |
| --- | --- | --- | --- | --- | --- | --- |
{rows}

观测自动检查：{'PASS' if hardware['passed'] else 'FAIL'}，见 `build/fusion/hardware_verification.json`。
这些候选数量说明匹配链路在产生结果，不证明真实视差正确；本轮当前场景中心 ROI 没有形成有效距离读数。
ILA 跨域诊断快照不是相机间同步帧交易；比较使用连续采样，不能据此推断严格同步曝光。

{watch_text}

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
'''
(root/'SELF_VERIFICATION.md').write_text(report,encoding='utf-8')
status=f'''# 当前上板状态（2026-10-24）

20:51 已下载融合版本 `build/fusion/fusion.bit`，DONE=1，默认增强双目画面，未写 Flash。
用户要求继续最初的代码开发并自我验证；实物距离标定明确暂缓。

- 14 项仿真全部通过，结果 `sim/test_summary.json`；包含全部 RGB565 颜色、完整 LCD 三帧、整幅视差双缓冲及距离数值运算。
- 布局布线时序：`{timing}`，TNS=0；无时钟寄存器与未约束内部端点均为0。
- 板上三次采样与自动检查通过：两路 0x5640，LCD 0x4384，每路 192000 像素，LCD 输出 384000 像素；帧计数和图像校验值变化。
- 原始平均亮度约39～41，增强后约101～107；匹配候选每帧约1万～1.4万，但当前中心ROI距离无效。
- 追加连续观测：{len(watch)} 次采样、首末相隔 {watch_seconds:.1f} 秒，自动检查 {'PASS' if watch_check['passed'] else 'FAIL'}，未观察到停帧；不替代长期测试。
- 尚未完成：真实物体视差/距离验收、0.5～3m误差实测、几何标定与最终颜色/边缘画质验收。不能称整项目已完成。

当前按键：KEY0 增强→视差→彩条→原始；KEY3 反向搜索；KEY1/2 调整距离尺度。
焦距346像素为估计值，基线约32mm，尺度256/256，未标定。无完整极线重映射或硬件曝光同步。

详细记录见 `SELF_VERIFICATION.md`；构建日志 `build/fusion_exposure_verified_build.log`，下载日志
`build/fusion_exposure_program_capture.log`；数据 `build/fusion/decoded.json`、`hardware_verification.json`。
前一次状态记录保存在 `baseline/STATUS_before_integrated_selfcheck_20261024.md`。
用户确认亮度改善、两路实时的原始显示回退版本在 `baseline/confirmed_brightness_20261024/`。
'''
(root/'STATUS.md').write_text(status,encoding='utf-8')
print('Saved SELF_VERIFICATION.md')
