# 当前上板状态（2026-10-24）

20:51 已下载融合版本 `build/fusion/fusion.bit`，DONE=1，默认增强双目画面，未写 Flash。
用户要求继续最初的代码开发并自我验证；实物距离标定明确暂缓。

- 14 项仿真全部通过，结果 `sim/test_summary.json`；包含全部 RGB565 颜色、完整 LCD 三帧、整幅视差双缓冲及距离数值运算。
- 布局布线时序：`WNS=0.994 WHS=0.031`，TNS=0；无时钟寄存器与未约束内部端点均为0。
- 板上三次采样与自动检查通过：两路 0x5640，LCD 0x4384，每路 192000 像素，LCD 输出 384000 像素；帧计数和图像校验值变化。
- 原始平均亮度约39～41，增强后约101～107；匹配候选每帧约1万～1.4万，但当前中心ROI距离无效。
- 追加连续观测：12 次采样、首末相隔 56.9 秒，自动检查 PASS，未观察到停帧；不替代长期测试。
- 尚未完成：真实物体视差/距离验收、0.5～3m误差实测、几何标定与最终颜色/边缘画质验收。不能称整项目已完成。

当前按键：KEY0 增强→视差→彩条→原始；KEY3 反向搜索；KEY1/2 调整距离尺度。
焦距346像素为估计值，基线约32mm，尺度256/256，未标定。无完整极线重映射或硬件曝光同步。

详细记录见 `SELF_VERIFICATION.md`；构建日志 `build/fusion_exposure_verified_build.log`，下载日志
`build/fusion_exposure_program_capture.log`；数据 `build/fusion/decoded.json`、`hardware_verification.json`。
前一次状态记录保存在 `baseline/STATUS_before_integrated_selfcheck_20261024.md`。
用户确认亮度改善、两路实时的原始显示回退版本在 `baseline/confirmed_brightness_20261024/`。
